# AGENTS.md

## Commands

- Analyze: `flutter analyze`. Pre-existing info-level `avoid_print` in `lib/screens/navigate_screens/config_screen.dart` (debug print, now `expConfig.ainACoefType`) — do not chase it.
- Codegen: after editing json_serializable models run `dart run build_runner build --delete-conflicting-outputs` (regenerates `lib/models/machine_data.g.dart`). Never edit `.g.dart` by hand. Dart 3.12.2 / Flutter 3.44.9 / `json_annotation ^4.10.0`, `build_runner ^2.11.1`, `json_serializable ^6.12.0`. **One-time exception (2026-09, `ExpConfig.ainAType`/`ainBType` removal):** the removal was done in an environment with no `dart`/`build_runner` access, so the corresponding generated lines in `machine_data.g.dart` (`_$ExpConfigFromJson`/`_$ExpConfigToJson`) were deleted by hand instead of regenerated. Verify `.g.dart` is still consistent with `machine_data.dart` (or just regenerate it) next time `build_runner` is available on this project.
- Builds: `flutter build apk --release` and `flutter build appbundle` (Play Store artifact).
- Test hardware is a physical device ("JKM LX1", Android 9 / API 28) over USB — find it via `flutter devices`. No emulator is used.
- Unit tests: `flutter test` runs all tests. Parser tests in `test/models/machine_data_test.dart` — 27 tests (5 legacy `fromPacket` + 14 `mergeFromPacket` L/D/F + 8 `configView/stdConfig/expConfig` routing). Single-file: `flutter test test/models/machine_data_test.dart`. Full suite currently only that file.

## Android build quirks (do not "clean up")

- `android/gradle.properties` pins `org.gradle.java.home` to Microsoft JDK 17 (`C:/Program Files/Microsoft/jdk-17.0.20.8-hotspot`). Android Studio's bundled JBR lacks `awt.dll` and Gradle fails with "no awt in system library path" — never point the build at it.
- `kotlin.incremental=false` and `kotlin.compiler.execution.strategy=in-process` work around a cross-drive cache bug (pub cache on `C:`, project on `D:` → "different roots"). Removing them breaks builds.
- Release lint is disabled in `android/app/build.gradle` (`checkReleaseBuilds = false`, `abortOnError = false`). `checkDebugBuilds` is not valid in this AGP version.
- `android/key.properties` + keystore hold release signing creds and are intentionally untracked — never commit them.

## Product & signal chain (read this first)

- **PVC = Proportional Valve Checker** — HVK's own kit product. Goal: replace the WPC-300 laptop workflow with phone-based configuration of the kit on the bench / at the machine.
- Signal chain: `Flutter app --BLE ASCII commands--> ESP32-S3 (inside the kit, our firmware, THE GATT server) --serial UART--> PAM 199-P (W.E.St. power amplifier) --> proportional valve solenoids (up to 2.6 A)`.
- The app NEVER talks to the PAM directly — every command is relayed by the ESP32-S3, which also streams PAM serial replies/logs back over the log characteristic (`...f2`/`...f3`) and telemetry over the notify characteristic (`...f1`) in L/D/F format.
- The dev-time Python GATT server emulates the ESP32-S3 bridge.
- Hardware facts from the W.E.St. manual (authoritative Quick Parameter Matrix) that the UI must respect:
  - **PIN 15** (general enable) and **PIN 6** (S1 / Enable-B) are PHYSICAL 24 V inputs — the app can only READ their state, never write them.
  - The analog input TYPE (`x` in the `AIN [a,b,c,x]` parameter) IS software-writable: `V` (voltage ±10 V differential) or `C` (current loop 4–20 mA, which engages the module's internal 390 Ω measurement shunt automatically). Defaults `a=1000 b=1000 c=0 x=V`. Wiring must match the selected type. (Supersedes the earlier "housing-selector read-only" assumption.)
  - Changing `FUNCTION` wipes ALL parameters to factory defaults and is only accepted under "protected conditions" (both enables OFF): live-output risk, parameter wipe, and the CPU must be idle to rebuild the parameter table + EEPROM save. Required order: enables OFF → change FUNCTION → ID (rebuild table) → SAVE.
- **AIN live mode vs coefficient type (critical distinction, audit 2026-09):** PAM has two independent input-type concepts. `AINA`/`AINB` (`V`/`C`) is the *live hardware input mode* — what the PAM is currently configured to drive, polled every `readCycle()` and displayed on Home/`PamDataScreen` as `V`→`V` / `C`→`mA` via `MachineData.mode`. `AIN:A/B A B C X` (`V`/`C` on write, `U`/`I` on readback) is the *coefficient scaling* — the `a/b/c/x` curve `output = a/b × (input − c)`, stored as `ExpConfig.ainACoefType`/`ainBCoefType` (`AIN_A_COEF_TYPE`/`AIN_B_COEF_TYPE` on wire) and edited only in Advanced Parameter 07. They are intentionally independent PAM registers; `AIN:A ... X` does **not** auto-change `AINA`, and Basic `AINA V/C` does **not** touch `AIN:A` coefficients. A valid but inconsistent state is `AIN_A_COEF_TYPE:C` + `AINA:V` — PAM accepts it, Home will still show `V`, DWIN scales with `V`. See `## Parameter 07` below and ESP `AGENTS.md` “AIN live vs coefficient” section.

## Physical pins — READ-ONLY for the app

These are wired hardware. The app can display their state but must never pretend to switch them.

| Physical item | What it is | App CAN | App CANNOT |
| --- | --- | --- | --- |
| **PIN 15** | General enable input, 24 V. Hardware master switch for the whole amplifier power stage. While ON, solenoid outputs may carry up to 2.6 A. | Read its state (`PIN15` key in `machine_data`) and show lock banners | Toggle it, or allow any EEPROM edit while it is ON |
| **PIN 6** | S1 / Enable-B input, 24 V. Secondary enable: gates Channel B in FUNCTION 196, or controls ramp execution. | Read its state (`PIN6` key) | Toggle it. Note: `ENABLE_B` is a software parameter that only REDEFINES this pin's role — the 24 V signal itself stays hardware |
| **Analog input type** | Live mode `AINA/AINB` (`MachineData.mode`) — `V` voltage or `C` current loop. Coefficient `x` inside `AIN [a,b,c,x]` (`ainACoefType`) is a *separate* scaling selector. | Set live mode via Basic `AINA` (must match wiring); set coefficient `x` via Advanced 07 | Treat coefficient `x` as live mode (it is not) or as physical selector (it is not) |

UI rules that follow from this:

- Anywhere PIN 15 / PIN 6 appear as controls, render them as **status chips with a PHYSICAL tag**, never as switches.
- The Inputs/Configure screens must derive their enabled/disabled state ONLY from `machineData.pin15` / `pin6` reads (already done via `isPin15Active`).
- Mockups/designs must visually separate "APP" (editable over BLE) vs "PHYSICAL" (read-only) — e.g. green APP tag vs red PHYSICAL tag.

## Theme & UI/UX reference (lib/theme/, lib/widgets/, lib/utils/responsive_helper.dart)

Brand colors (`AppColors`): Navy `#0E3C6E` · Red `#F23A56` · Cyan `#00CFFF`; feedback green `#4CAF50`, dark-error muted red `#CF6679`.
Light theme (primary=Red): bg `#F8F9FA`, surface white, text `#1A1A1A`/`#757575`. Dark theme (primary=Cyan): bg `#0D1117`, surface `#161B22`, text `#EDEDED`/`#AAAAAA`. Material 3 on both.
Conventions: buttons full-width h=54 r=12 bold+letterSpacing 1.1 (shared `inherit:true` style); cards r=16 hairline border; ListTiles r=12; snackbars floating r=10 with 1px primary border; AppBar flat left-aligned title 20 bold in primary; ALL input borders removed (`InputBorder.none`) — fields are custom containers; `ResponsiveWrapper(maxWidth:600)` phone-first column; `AppSelectorCard` = tinted icon container + UPPERCASE bold title + bordered dropdown, disabled = `IgnorePointer` + `disabledColor`; heavy `Semantics` labels; drawer shows HVK/WEST brand cards, debug-only Serial Monitor entry, destructive Disconnect with confirm dialog, firmware version footer.

## Architecture

- Flutter + Riverpod v2 (`Notifier`/`NotifierProvider`, not StateNotifier) + go_router. Entry: `lib/main.dart`; routes in `lib/routes/static_routes.dart` (`/`, `/details`, `/ota`, `/serial-monitor`).
- All BLE state/logic is centralized in `lib/providers/ble_provider.dart` (`BleNotifier`): connect, service discovery, read/write, serial-log ring buffer (capped at 500 entries), telemetry subscription management. Screens talk to the notifier; `scan_devices_screen.dart` is the only place using flutter_blue_plus directly (scanning lifecycle).
- `BleState` holds accumulated `MachineData machineData` — the single authoritative source for all parsed telemetry. `machineDataProvider` returns `bleState.machineData` directly. Merge path: `BleNotifier` calls `MachineData.mergeFromPacket(decoded, state.machineData)` on every notify.
- `lib/models/machine_data.dart`: `MachineData` + nested `StdConfig`/`ExpConfig` (both `@JsonSerializable`). `StdConfig` holds Basic `func/mode/coilCurrent/coilACurrent/coilBCurrent` snapshot; `ExpConfig` holds all Advanced fields (~40: `sens/ccMode/lim*/pol*/ainAa..Ac/ainBa..Bc/ainACoefType/ainBCoefType/ramp*/min*/max*/trigger/dither*/pwm*`). Root `MachineData` keeps live/shared `func/mode/currents/pins/enableB/transition/...` + `configView` (`@JsonKey(name:'CONFIG_VIEW')`) + `stdConfig` + `expConfig`. Legacy `_withPamMode`/`_parseKeyValue`/`_mapKey` removed; parser is content-aware with helpers `_strOf/_dblOf/_boolOf/_onOf/_intOf/_hasAny`. `copyWith` on all three classes.
- **Routing (content-based D|/L|, configView-based F| — audit 2026-09):** `mergeFromPacket` strips `L|/D|/F|` prefix (unknown `X|` → legacy, no prefix → legacy). `raw` map built, `CONFIG_VIEW` removed first. `isFull` → `configView = packet CONFIG_VIEW ?? 'STD'` (F| always carries it, fallback `STD`); `expActive/stdActive` decided by `CONFIG_VIEW`. Non-full (`D|/L|`) → `configView = packet CONFIG_VIEW ?? base.configView`; `stdDelta/expDelta` decided by **content** (`_hasAny(raw, _stdGroupKeys)` vs `_hasAny(raw, _expGroupKeys)`). `F|` rebuilds the active section from `const` defaults via `fromWire`, carries the inactive section from `current`; `D|/L|` overlay only present keys. `FUNC/MODE/CURRENT_*` stay shared on root and are snapshotted into `stdConfig`. Never-clobber rule: `F| STD` carries `expConfig`, `F| EXP` carries `stdConfig`. Dead helper `modifyField` kept compiling via `toJson/fromJson` round-trip.
- **Wire keys:** `_cfgStringKeys` now contains `AIN_A_COEF_TYPE`/`AIN_B_COEF_TYPE` (not `AIN_A_TYPE/B_TYPE` — the ESP no longer sends those keys at all, in either `D|` or `F|`). `_stdGroupKeys = {FUNC,MODE,CURRENT_*}`; `_expGroupKeys = {..._cfgStringKeys, ..._cfgIntKeys, ..._cfgBoolKeys}`. `ExpConfig.ainAType`/`ainBType` and `AdvancedConfigDraft.ainAType`/`ainBType` (the "dead, always default" fields from an earlier pass) have since been **removed entirely** (2026-09) — not just left unwired. See `## Parameter 07` below.
- **Shared command controller** (`lib/services/ble_command_controller.dart`): `BleCommandController` with `execute()`, `executeAndSave()`, `saveToEeprom()`, plus `writeAIN()` grouped path. `writeAIN` diffs normalized coefficient type against `expConfig.ainACoefType/B` (not `ainAType`), supports `AIN196:A:...:B:...` grouped transaction. Both basic and advanced screens use `bleCommandProvider`.
- **Basic screen save**: Builds atomic `MODE:UNIT[:CA:VAL][:CB:VAL][:CS:VAL]` — one PAM transition for mode+current. Uses `cmd.execute(commands)`. Only touches `mode`/`func`/`currents`.
- **Advanced screen save** (`advanced_config_screen.dart`): 15 `ParamDef` master/detail; per-param grouped writes (e.g. `LIM:A/B`, `POL:A/B`, `RAMP:AUP/...`, `AIN:A/B`, `MIN:A/B`, `MAX:A/B`, `CUR196:A/B`). Dirty tracking via `AdvancedConfigDraft` + `hasChangesForSelectedParam(selectedParam, mode, draft, md)` — only the selected param's draft vs `md` baseline is checked. `writeAIN` is typed `type: draft.ainACoefType`. Uses `cmd.executeAndSave` + `setConfigView('EXP')` unawaited.
- **No ESP changes for this app-layer routing** — `machine_state.h:110 configView="STD"` default + `"None"` sentinels for `sens/ccMode/lim*` are the source wire values.

## BLE protocol (single new kit + L/D/F telemetry)

- GATT UUIDs are hardcoded in `ble_provider.dart`: service `12345678-1234-5678-1234-56789abcdef0`, write/notify char `...f1`, log service/char `...f2`/`...f3`.
- **Only the new kit is supported** (old/separate-command protocol was removed). Mode changes send one atomic string `"FUNC:UNIT[:CA:VAL][:CB:VAL][:CS:VAL]"` (e.g. `196:V:CA:1200:CB:1300` or `195:C:CS:1500`); CA/CB/CS are omitted when 1000 mA. Standalone AIN type uses bare `"Voltage"`/`"Current"` and standalone currents use `CUR`/`CURA`/`CURB`. The kit acknowledges by flipping `TRANSITION:True`, back to `False` when done.
- **Function-change D| packets are coalesced:** `handleChangeMode` synchronously re-reads CURRENT setpoints after the PAM reboot and stores them atomically with FUNC/MODE in one critical section. The app receives a single `D|FUNC:196,MODE:V,CURRENT_A:1000,CURRENT_B:1000` (196) or `D|FUNC:195,MODE:C,CURRENT_S:1000` (195) packet, followed by `D|TRANSITION:False` ~500ms later. Only the current fields relevant to the target mode appear (196 → A+B, 195 → S); inactive fields are excluded.
- **`PAM_CONNECTED:True/False`** is emitted in delta packets when the PAM USB connection state changes (connect/disconnect).
- Busy lock: `writeToCharacteristic()` silently drops writes while `isBusy` (cleared on `TRANSITION:False`, write error, or an 8 s guard timer). `writeRawToCharacteristic()` bypasses the busy gate and is reserved for the `SYNC` command, which is sent over the notify channel right after subscription so it is never dropped.
- Transition clear: firmware uses a non-blocking `transitionClearMillis` deadline (set to `millis() + 500` at handler exit). The loop() block emits `D|TRANSITION:False` when the deadline elapses — not inline in the handler. The app should treat any `TRANSITION:False` as the done signal.
- `requestSync()` asks the kit for a fresh `F|` full snapshot at the moment the notify channel is confirmed open.
- **Parameter 07 wire:** ESP `D|/F|` expose `AIN_AA/AB/AC` + `AIN_A_COEF_TYPE` (+ `AIN_BA/BB/BC` + `AIN_B_COEF_TYPE` for 196) — *not* `AIN_A_TYPE/B_TYPE`. `AIN_A_COEF_TYPE` is the coefficient `X` last written via `AIN:A` (PAM readback token `U` for `V`, `I` for `C`); `AINA` live mode (`V`/`C`) is reported only as `MODE`.

### Shared command controller (`lib/services/ble_command_controller.dart`)

- `BleCommandController` handles transition polling (`_waitForTransition`, `_waitForDone`), overlay state, and BLE write loops.
- `execute(commands)`: sends commands sequentially, waits for transition after each. Used by basic screen.
- `executeAndSave(commands)`: sends commands + SAVE to EEPROM. Used by advanced screen.
- `writeAIN({a,b,c,type,bA,bB,bC,bType})`: dual-channel diff against `expConfig.ainACoefType/B` (type/baseline normalized `U→V, I→C`), emits `AIN196:A:...:B:...` when both changed, `AIN:A`/`AIN:B` when one, or no-op. Single-channel branch compares `type` vs normalized `ainACoefType/B`. Transmitted 5th token is always `V`/`C` (never `U`/`I`/`None`).
- Timing constants: 3s ack, 10s mode change, 4s param change — all in one place.
- Both screens use `ref.read(bleCommandProvider)` to get the same controller instance.

### Basic screen save flow (`basic_config_screen.dart`)

- Builds atomic `MODE:UNIT[:CA:VAL][:CB:VAL][:CS:VAL]` on mode change (one PAM transition) — CA/CB/CS omitted when 1000 mA default. Standalone edits use `CUR`/`CURA`/`CURB` and bare `V`/`C` for AIN type.
- Uses `cmd.execute(commands)` — shared controller handles transition polling and overlay.
- Busy guard: `writeToCharacteristic(busyTimeout: doneTimeoutFunctionChange=10s)` for mode changes, 4s for param changes; wait loop polls `TRANSITION` at 10ms (3s ack + 10s/4s done).

### Advanced screen save flow (`advanced_config_screen.dart`)

- 15 `ParamDef` (SENS, CCMODE, ENABLE_B, LIMIT, POL, **AIN (coefficient)**, RAMP, MIN, MAX, TRIGGER, DITHER-A, DITHER-F, PWM, PPWM/IPWM, Current, ACC). Mode-dependent: 196 sends `A/B` variants, 195 sends global.
- **AIN (07) is EXP coefficient editor:** `AinEditDialog` shows `A/B/C` + `X` dropdown (`V`/`C` only); `_Param07AIN` cards and dialog now bind `type` to `draft.ainACoefType/B` (seeded from `expConfig.ainACoefType/B`, not `ainAType`). `onSave` calls `cmd.writeAIN(a,b,c,type, bA,bB,bC,bType)`.
- Type baseline normalization: `AinEditDialog.initState` normalizes `widget.initialX` `V/U→V`, `C/I→C`, else `V`; `AdvancedConfigDraft.fromMachineData` normalizes `md.expConfig.ainACoefType/B` the same way so `V` vs `U` (and `C` vs `I`) do not cause false dirty. `hasChangesForSelectedParam` case `07` compares `ainAa/Ab/Ac/ainACoefType` (+ B when `196`).
- No `AIN_A_TYPE/B_TYPE` traffic — the wire keys are gone (ESP side) and the corresponding `ExpConfig`/`AdvancedConfigDraft` fields have been removed entirely (app side, 2026-09).
- Each param write is independent except grouped `RAMP`/`LIM`/`POL`/`AIN` families; grouped writes emit one `SAVE` + one `D|` per family.

### L/D/F telemetry protocol (ESP32→Flutter)

- ESP32 sends three packet formats:
  - `L|key:value,...` — Live: `WA/WB/IA/IB/READY/PIN15/PIN6` only.
  - `D|key:value,...` — Delta: only `dirtyDelta` fields. For `MODE`/`CURRENT` coalesced as above. `AIN_A_COEF_TYPE`/`B` emitted via `DF_AIN_A/B` only when coefficient quad changed; `CONFIG_VIEW:STD/EXP` emitted on `DF_CONFIG_VIEW` only after save.
  - `F|key:value,...` — Full snapshot: all fields incl. `MODE,CONFIG_VIEW,SENS,CCMODE,LIM_*,POL_*,RAMP_*,MIN/MAX,TRIGGER,DAMPL*,DFREQ*,PWM*,AIN_AA/AB/AC/A_COEF_TYPE (+ B* when 196)`. Chunked `F|<id>|<i>/<n>|payload` (160 char max, MTU 247). `F|` carries `CONFIG_VIEW`; `D|/L|` carry it only when present.
- `MachineData.mergeFromPacket(packet, current)` accumulates: `F|` → rebuild active section from defaults + carry inactive; `D|/L|` → overlay present keys via content groups. Root fallback is `const MachineData()` for `F|`, `current ?? const MachineData()` otherwise. Malformed → `Logger().e` + return base. Unknown prefix → legacy; empty `raw` + non-full → return base unchanged.
- `BleState.machineData` holds the accumulated `MachineData` — the single authoritative source.
- Legacy `MachineData.fromPacket()` delegates to `mergeFromPacket` for prefix-less packets (dual key naming via `wireKey` aliases still supported for `CURRENT_A_STATUS` etc., but not for removed `AIN_A_TYPE`).

### Notification subscription setup (critical ordering)

- `_discoverServices()` attaches the `onValueReceived` listener BEFORE calling `setNotifyValue(true)`. This prevents a race condition where the ESP32 sends the first L| packet before the Dart listener is attached, causing the packet to be silently dropped.
- After `setNotifyValue(true)`, a 50ms delay (`Future.delayed`) allows the Android GATT stack to fully propagate notification enable to the ESP32 before it starts sending telemetry.
- The `_telemetrySub` subscription has an `onError` handler to prevent silent subscription cancellation on BLE stream errors.
- `_cmdCharacteristic` is cached after service discovery for efficient write/read operations without re-scanning services each time.

## Known BLE gotchas

- After an app restart the native Android scan can survive while the plugin's fresh Dart session thinks nothing is running: the public `FlutterBluePlus.stopScan()` is gated by `isScanningNow`, becomes a no-op, and the next scan fails with `SCAN_FAILED_ALREADY_STARTED`. `scan_devices_screen.dart` fixes this with `_forceStopNativeScan()` (direct platform-interface `stopScan`); keep that path intact when refactoring scan logic.
- **Notification race condition**: ESP32 sends L| packets immediately after connection. If `setNotifyValue(true)` is called BEFORE the Dart `onValueReceived` listener is attached, the first packet(s) are silently dropped. Fix: attach listener first, then enable notifications.
- **GATT propagation delay**: After `setNotifyValue(true)`, Android needs ~50ms to fully propagate notification enable to the ESP32. Without this delay, the ESP32 may send its first L| packet before the notification channel is active on the remote side.
- **Subscription error handling**: `onValueReceived` streams can error on BLE disconnect. Without `onError` handler, the subscription is silently cancelled and no more events are received. All telemetry subscriptions must include `onError`.
- **First-save `D|` lag:** First Advanced save emits `D|SENS...` before the later unawaited `setConfigView('EXP')` `D|CONFIG_VIEW:EXP`; content-based D| routing (not carry-forward `configView`) ensures the first delta is not mis-routed.

## UI rebuild optimization (PamDataScreen)

- `PamDataScreen` uses extracted `ConsumerWidget` sub-widgets with granular `select()` calls to minimize unnecessary rebuilds.
- Each sub-widget watches only the specific `MachineData` fields it needs (e.g., `select((s) => s.machineData.pin15)`, `select((s) => s.machineData.ready)`). Home `INPUT A/B` cards watch `(inputA, mode)` / `(inputB, mode)` and render `mode=='C'?'mA':'V'` via `UnitConverter.format`.
- This prevents the entire screen from rebuilding when any single field changes.
- Sub-widgets: `PamHeader`, `PinStatusSection`, `PamDetailsCard`, `ReadyStatusRow`, `OutputStatusRow`, `ConnectionStatusRow`, `BusyStatusRow`, `ErrorStatusRow`, `PamDetailsSection`, `RawDataExpansion`, `PamDataActions`.

## Home / PamDataScreen — live vs coefficient display

- Home `INPUT A/B` unit comes from **live `MachineData.mode`** (`AINA`, `V`→`V`, `C`→`mA`), **not** from Advanced 07's `ainACoefType`. `ExpConfig.ainAType`/`ainBType` (the old `AIN_A_TYPE` field) have been **removed** (2026-09) — there is no longer a separate dead field for this; the live type lives solely in `MachineData.mode`.
- `MachineData.mode == 'V' ? 'Voltage' : 'Current'` is the Basic input type; Advanced 07's `X` (`V`/`C` norm from `U`/`I` readback) is scaling only — `8.0 V` on Home while `AIN_A_COEF_TYPE:C` is *valid but inconsistent* (current coefficients on voltage input). Technician must change **both** Basic Input *and* Advanced 07 to get consistent `mA` display + current scaling.

## Parameter 07 AIN — editable coefficient type (audit 2026-09)

- **PAM stores `U`/`I`, Flutter edits `V`/`C`:** Hardware readback (`readAinQuad("AIN:A")` → last token) is `U` (voltage) / `I` (current); the editable dropdown/pill intentionally offers only `V`/`C` (`V`+390 Ω shunt). `AinEditDialog` normalizes at the UI boundary: `V/U→V`, `C/I→C`, else `V`. `AdvancedConfigDraft.fromMachineData` normalizes identically at seed (`U→V, I→C`), so `U`↔`V` is not false-dirty.
- **Displayed Type must come from coefficient fields:** `_Param07AIN` cards + dialogs bind `type` to `draft.ainACoefType/B` (via `expConfig.ainACoefType/B` `AIN_A_COEF_TYPE/B`). The old `draft.ainAType/B` (`AIN_A_TYPE` hardware mode) fields that used to be carried-but-never-displayed have been **removed entirely** (2026-09) — there is nothing left in `AdvancedConfigDraft`/`ExpConfig` for the live hardware mode; that lives only in `MachineData.mode`.
- **Presets:** `0-10V` (`1000,1000,0,V`) and `4-20mA` (`1250,1000,2000,C`) — `X` in dialog maps directly to coefficient `x`.
- **Write path:** `writeAIN` diffs normalized `type` vs normalized `expConfig.ainACoefType` baseline; mismatch → `AIN:A a b c x` / `AIN196:A:...:B:...` (5th token `V`/`C` only, never `U`/`I`). PAM echoes `U`/`I` on next read, Flutter re-normalizes to `V`/`C`.
- **Draft vs live:** `AinEditDialog` `U`/`I` guard prevents `DropdownButton` assert (`value: I` has no item). Without it the dialog throws when PAM reports `I`.

## Advanced Config — draft & dirty tracking (audit 2026-09)

- `AdvancedConfigDraft` ( `lib/providers/advanced_config_draft_provider.dart` ) holds editable copy of the 15 params, seeded via `fromMachineData(md)` (live `func/mode/currents` from root, advanced from `expConfig` with coef-type normalization). Setters `setAinACoefType` etc. mutate only draft.
- `hasChangesForSelectedParam('07', mode, draft, md)` checks `ainAa/Ab/Ac/ainACoefType` (+ `Ba/Bb/Bc/BCoefType` when `196`) against normalized `md.expConfig` baselines; `05/06/12-14` branch on `mode=='195'` global vs `A/B`. `writeAIN` uses the same normalized `ainACoefType/B` baselines for both dual (`AIN196`) and single-channel paths — fixes false-dirty `V` vs `U` / `C` vs `I`.
- `AdvancedConfigDraft.ainAType/B` (previously dead, kept to avoid `.g.dart` churn) have been **removed** (2026-09), along with `ExpConfig.ainAType/B` and their generated `machine_data.g.dart` entries (hand-edited, see the Codegen note above — no `.g.dart` churn was actually avoidable once these went away for good). `ainACoefType/B` remain as the sole editable fields for Parameter 07.
- **`_saveConfig()` lifecycle guard (2026-09):** `_saveConfig()`'s only `await` (`await writeOp()`, the shared `BleCommandController.execute()` transaction) can outlive `_AdvancedConfigScreenState` — specifically, a FUNCTION 195/196 write makes PAM reboot back to `PAM_MODE:STD` mid-transaction, which `ConfigScreen` (watching `machineDataProvider.pamMode`) reacts to by swapping `AdvancedConfigScreen` out for `BasicConfigScreen`, disposing this State while `writeOp()` is still awaiting `TRANSITION:False`. The write itself (`BleCommandController.execute()`) is unaffected — it polls `machineDataProvider` independently of the calling widget and always runs to completion — but the post-await continuation (`setState(() => _isSynchronizing = false)`, the draft re-sync, and the success/error message) must not touch the disposed State. Fixed with a single `if (!mounted) return;` immediately after `await writeOp();`, before that continuation. When FUNCTION is changed while already in STD (Basic Config active), `pamMode` never flips, this screen is never disposed, and behavior is unchanged. Do not add `mounted` guards to the two other (fully synchronous, no-`await`) `setState` calls in this file — they're never at risk.

## STD Screen — unified 195/196

- Single screen for both FUNCTION 195 (single coil) and 196 (dual coil); mode selector + AINA + current(s) + Save.
- Save builds atomic `MODE:UNIT[:CA:VAL][:CB:VAL][:CS:VAL]` on mode change (one PAM transition) — CA/CB/CS omitted when 1000 mA default. Standalone edits use `CUR`/`CURA`/`CURB` and bare `V`/`C` for AIN type.
- Uses shared `BleCommandController` via `ref.read(bleCommandProvider)` — no duplicate transition polling or overlay management.
- Draft reset: `inputsTabProvider.selectedMode` and `machineData.func` listeners reset currents to 1000 defaults on mode switch.
- UI layout: `ResponsiveWrapper(maxWidth:600)`; Dividers `onSurface.withAlpha(48)`.
- Reads live `MachineData.mode` for `Voltage/Current` display; writes via atomic command, not via `AIN:A`.

## Advanced Config Screen

- 15 `ParamDef` master/detail (`SENS` STD, rest mixed EXP/STD), bottom-sheet selector (`_openParamSheet()` → `showModalBottomSheet` + `ListView.builder`, **not** a `DropdownButton`) + form for selected param + bottom Save.
- Save builds per-param commands; grouped families (`LIMIT`, `POL`, `RAMP`, `MIN/MAX`, `DAMPL/DFREQ/PWM`, `CURRENT`, `AIN`) use single grouped write (`GROUP_LIM` etc.) with one `SAVE` + one `D|`. See `ble_command_controller.dart:writeAIN`/`writeRamp` etc.
- Uses `bleCommandProvider` → `executeAndSave()` + unawaited `setConfigView('EXP')`.
- Each param command independent except grouped families.
- Parameter 13 (Dither Frequency) renders as a `DropdownValueCard` (`lib/widgets/parameter_widgets.dart` — since Phase 2 (2026-09) the implementation lives in `lib/widgets/parameter_widgets/dropdown_value.dart`, a `part of` file; the import path callers use is unchanged, see "Phase 2 — parameter_widgets structural split" below), not `NumericStepperCard` — see the Configure-spec table above and `param_supported_values.dart` (`kDitherFrequencySupportedValues`, 57 values, referenced via `ParamDef.supportedValues` rather than hard-coded in the screen file).

### Selected-parameter persistence & selector scroll position (audit 2026-09)

- Which parameter card is shown (`'01'`..`'15'`) lives in `selectedAdvancedConfigParamProvider` (`StateProvider<String>`, `advanced_config_draft_provider.dart`), **not** local `State` on `_AdvancedConfigScreenState`. Reason: `HomeScreen` swaps its bottom-nav body directly (`body: pamIsConnected ? _children[_currentIndex] : ...`, not an `IndexedStack`), so `AdvancedConfigScreen`'s `State` (and any plain field on it) is disposed/recreated every Home ↔ Configure switch. A provider held in the app's `ProviderScope` survives that; a `State<>` field does not. Deliberately kept separate from `AdvancedConfigDraft` (which is PAM value data diffed for dirty-tracking/Save) so this pure UI/navigation state can never affect dirty tracking, Save, or PAM writes. Session-only (in-memory), defaults to `'01'`.
- The selector's own bottom sheet (`_ParamSelectSheet`, a `ConsumerStatefulWidget` in `advanced_config_screen.dart`) opens scrolled to the currently-selected row (centered when there's room, clamped at the list ends for `01`/`15`), via a dedicated `ScrollController` + fixed `itemExtent` (`_kParamSheetItemExtent = 72.0`) and a computed `jumpTo(selectedIndex * itemExtent - (viewportHeight - itemExtent) / 2)` clamped to `[0, maxScrollExtent]`, run once from `initState()`'s first `addPostFrameCallback`. **Do not go back to `Scrollable.ensureVisible()` on a `GlobalKey`** for this — `ListView.builder` only lazily builds rows near the initial (top) scroll position, so a key for a row further down (parameter 07+) has no `currentContext` yet on the first frame and `ensureVisible` silently does nothing; the fixed-extent/`jumpTo` approach has no such dependency.
- List order is always `kParamDefs[0..14]` = `'01'..'15'` — the selector never reorders to put the selected item first.

## App usage model

Technician workflow: **connect → verify safe → configure inputs → tune parameters → ID → SAVE.**

1. **Scan** screen: connect to the kit (ESP32-S3 advertises, not the PAM).
2. **PAM Data** tab: pre-check dashboard — PIN 15 / PIN 6 enable states, ready/LED logic, busy flag.
3. **Inputs** tab: Voltage/Current signal mode per solenoid channel (must match physical wiring), then Save.
4. **Configure** tab: master dropdown of 15 numbered parameters; form for the selected parameter renders below; SAVE TO MEMORY writes values; REBUILD TABLE (ID) after function changes.
5. **Serial Monitor**: raw phone→ESP32→PAM traffic for bench debugging.
6. **OTA**: firmware update over BLE.

UI safety rules to preserve in any redesign:

- All EEPROM editing blocked with a red banner while PIN 15 or PIN 6 reads ON.
- Function change requires an explicit confirm dialog warning about factory-reset of all tuning; only tappable when both enables are OFF.
- ID and SAVE are persistent footer actions on the Configure page.

## Configure page — 15-parameter spec (design source of truth, from PAM-199-P manual matrix)

Groups: **STD** = Standard parameters · **EXP** = Expert parameters. "Default" = factory value.

| # | Parameter | Group | W.E.St. command(s) | Range & unit | Default | Widget / notes |
| --- | --- | --- | --- | --- | --- | --- |
| 01 | Function | — | `FUNCTION` | 195 / 196 | — | Segmented. Interlock: PIN 15 & 6 must be OFF (physical). Confirm dialog: wipes ALL tuning to defaults. After change: ID → SAVE. |
| 02 | SENS | STD | `SENS` | `ON`/`OFF`/`AUTO` | `AUTO` | AUTO self-resets + rechecks error status every second. ON/AUTO: wire break → output current cut immediately + READY (PIN 5) OFF. Errors acked by cycling PIN 15 OFF→ON. |
| 03 | CC Mode | EXP | `CCMODE` | `ON`/`OFF` | `OFF` | ON = 10-point linearization curves (PAM DATA), OFF = direct linear mapping. |
| 04 | Enable-B | EXP | `ENABLE_B` | `ON`/`OFF` | `OFF` | ON: PIN 15 enables Ch A, PIN 6 enables Ch B · OFF: PIN 15 globally enables both. Redefines PHYSICAL Pin 6 role only. Visible only @196; grey info box otherwise. |
| 05 | LIMIT | EXP | `LIM` / `LIM:A`,`LIM:B` | raw int 0–2000 step 50 | `0` (off) | Wire-break/short-circuit detection threshold for command signals. User enters the raw matrix integer directly. Numeric field + steppers @195 global / @196 A+B. |
| 06 | POL | STD | `POL` / `POL:A`,`POL:B` | `+`/`-` | `+` | Output direction per coil; single @195, two @196. |
| 07 | AIN | EXP | `AIN:A` @195 · `AIN:A`,`AIN:B` @196 — **live `AINA/B` (`MODE`) is separate** | a,b,c each −10000…10000; x=`V`/`C` (PAM readback `U`/`I`) | `a=1000 b=1000 c=0 x=V` | Format `[a,b,c,x]`, `output = a/b × (input − c)`, resolution 0.01 %. `x` is the *coefficient* scaling selector (editable `V`/`C`, stored `AIN_A_COEF_TYPE`, normalized `U→V, I→C`); **not** the live `AINA V/C` (`MachineData.mode`) shown on Home. `x=C` engages internal 390 Ω shunt *only when live `AINA` is also `C`*. AIN:B hidden @195. |
| 08 | Ramp | STD | 195: `AA:1..4` · 196: `AA:UP/DOWN`,`AB:UP/DOWN` | 1–120000 ms | `100 ms` | Transition time over 100 % full-scale step. Numeric fields + ±10 ms steppers + quick +50/+500/+1000 ms chips. Labels relabel per function. |
| 09 | MIN | STD | `MIN:A`,`MIN:B` | raw int 0–6000 step 50 | `0` | Spool overlap compensation; yellow warning if raw > 3000 (≈ 30 %). |
| 10 | MAX | STD | `MAX:A`,`MAX:B` | raw int 5000–10000 step 50 | `10000` | Solenoid output scaling; clamped low end. |
| 11 | Trigger | STD | `TRIGGER` | raw int 0–3000 step 50 | `200` | Threshold point where the MIN jump activates. |
| 12 | Dither Amplitude | STD | `DAMPL` / `DAMPL:A`,`:B` | raw int 0–3000 step 50 | `500` | Tied to CURRENT — auto-rescaled proportionally. Output mA = raw ÷ 100 × nominal. Flashing warning if PWM < 500 Hz. |
| 13 | Dither Frequency | STD | `DFREQ` / `DFREQ:A`,`:B` | Discrete list (57 values): 60,61,62,63,64,65,66,67,68,70,71,72,74,75,76,78,80,81,83,85,86,88,90,93,95,97,100,102,105,108,111,114,117,121,125,129,133,137,142,148,153,160,166,173,181,190,200,210,222,235,250,266,285,307,333,363,400 Hz | `121 Hz` | Anti-stiction carrier. **Not a free 60–400 Hz range** — hardware-characterized 2026-09 (full sweep): PAM only accepts/returns these 57 exact values, snapping any other requested value on readback (e.g. `124`→`125`). Dropdown picker (like PWM below), not a numeric stepper — see `param_supported_values.dart` / `DropdownValueCard`. |
| 14 | PWM Frequency | EXP | `PWM` @195 · `PWM:A`,`PWM:B` @196 | Discrete list: 61,72,85,100,120,150,200,269,372,488,624,781,976,1201,1420,1562,1736,1953,2232,2604 Hz | `2604 Hz` | Dropdown picker from 20 discrete firmware values. ACC toggle ON hides manual PI gains block. |
| 15 | Current | STD | `CURRENT` @195 · `CURRENT:A`,`:B` @196 | 500–2600 mA step 50 | `1000 mA` | Stages regulate up to 2.6 A. Changing CURRENT auto-rescales MIN/MAX/DAMPL. (Coil calculator card removed per manager feedback.) |

**Global numeric-input UI rule (v2 design, all Configure params):** no sliders anywhere — every quantity uses a text input flanked by −/+ stepper buttons with a permanently visible unit (% / ms / Hz / mA). User types the raw matrix integer directly — no percentage math in the UI. The five percent-scale parameters (LIM 0–2000, MIN 0–6000, MAX 5000–10000, TRIGGER 0–3000, DAMPL 0–3000) show a permanent helper note referencing the % equivalence but the input itself is always the raw value. Ramp/CURRENT accept ms/mA directly via stepper. Inputs validate on commit: parse (comma or dot), clamp to parameter min/max, format to the parameter's decimal count. **PWM and DFREQ are both discrete-value dropdowns, not free-entry steppers** (2026-09: DFREQ converted from a 60–400 Hz stepper to a 57-value dropdown once hardware characterization showed the field isn't actually continuous — see Parameter 13 above and `DropdownValueCard` in `Advanced Config Screen` below) — the app only ever sends one of the firmware-supported exact values for either.

Design mockups: `pvc-config-redesign-v2.html` (current interactive master-layout prototype: dropdown-driven 15 forms, function-context preview, PIN simulator, skeleton fetch, factory-reset dialog — approved design source) · legacy static `pam_configure_screen.html` (+ v1 backup). Pending manager approval before Flutter implementation.

## Phase 2 — parameter_widgets structural split (2026-09)

`lib/widgets/parameter_widgets.dart` was a single ~1,360-line file holding every reusable parameter-form widget (`ParamHeader`, `SegmentedCard`, `NumericStepperCard`, `DropdownValueCard`, `PolarityCard`, `TabbedPanelCard`, `RampRow`, `SafetyBanner`, `HelpCard`, `CurrentLoopGainRow`, plus their private helpers). This was a pure structural refactor — **zero functional, UI, BLE, state, protocol, timing, or hardware behavior change** — splitting it into:

```
lib/widgets/
├── parameter_widgets.dart              (library root: imports + `part` directives only)
└── parameter_widgets/
    ├── info_widgets.dart               ParamHeader, HelpCard, SafetyBanner
    ├── segmented_controls.dart         SegmentedCard, PolarityCard, _SegmentedControl
    ├── buttons.dart                    _StepperButton, _QuickButton (shared across families)
    ├── numeric_stepper.dart            NumericStepperCard, _NumericStepperCardState
    ├── dropdown_value.dart             DropdownValueCard
    ├── tabbed_panel.dart                TabbedPanelCard
    ├── ramp_row.dart                   RampRow, _RampRowState
    └── current_loop_gain.dart          CurrentLoopGainRow, _CurrentLoopGainRowState, _SmallButton
```

**Why `part`/`part of` instead of ordinary per-file imports:** Dart privacy is per-*library*, not per-class. Several private (`_`-prefixed) helper widgets are shared across widget families that now live in different files — e.g. `_StepperButton` is used by both `NumericStepperCard` (numeric_stepper.dart) and `RampRow` (ramp_row.dart); `_QuickButton` is used by both `RampRow` and `CurrentLoopGainRow`. `part`/`part of` keeps every part file inside one Dart library, so those helpers stay exactly as private as before the split with **zero renames**. `parameter_widgets.dart` remains the library root; every part file's first line is `part of '../parameter_widgets.dart';`.

**External API impact: none.** `advanced_config_screen.dart` — the only file in the repo that imports `parameter_widgets.dart` — needed no changes at all, not even its import path. All ten public widget classes kept their exact names, constructors, and fields.

**Verification performed before committing:** repo-wide grep confirmed `advanced_config_screen.dart` is the sole external consumer of every symbol; every one of the 17 classes (10 public + 7 private) in the original file was extracted and diffed byte-for-byte against its new location — all identical (one transcription slip, an escaped `'−'` accidentally pasted as the literal glyph, was caught by this diff and corrected); brace/paren/bracket balance verified per new file; confirmed no part file carries its own `import` statement (imports live only in the root); confirmed the root's 8 `part` directives match the 8 files on disk exactly, one each.

**Do not** reintroduce a flat single-file `parameter_widgets.dart`, and do not add a 9th part file per-parameter (explicitly rejected — groups are by widget family, not by the 15 Configure parameters). If a new reusable parameter-form widget is added, put it in the most fitting existing part file, or add a new `part` file + directive only if it doesn't belong in any existing group.

## Phase 3 — BleCommandController structural split (2026-09)

`lib/services/ble_command_controller.dart` was a single ~611-line file holding one class, `BleCommandController`, with ~20 instance methods (core execute/save/queue logic plus all 18 per-parameter write helpers). Pure structural refactor — **zero command-string, parameter-ID, timing, retry/timeout, busy-guard, protocol, or provider behavior change** — split into:

```
lib/services/
├── ble_command_controller.dart                     (library root: imports, class core, `with` clause, `part` directives, bleCommandProvider)
└── ble_command_controller/
    ├── simple_parameter_writes.dart                writeFunction, writeSens, writeCcMode, writeEnableB, writeTrigger
    ├── diffed_parameter_writes.dart                writeLimit, writePolarity, writeMin, writeMax, writeDitherAmplitude, writeDitherFrequency, writePwm
    ├── ain_coefficient_writes.dart                 writeAIN (the only write helper using the shared normalizeCoefType())
    └── current_ramp_writes.dart                    writeRamp, writePpwm, writeIpwm, writeCurrent, writeAcceleration
```

The core (constructor, `_ref`, the three timing constants, the private `_ble`/`_overlay`/`_msg`/`_md` getters, `isBusy`, `execute`, `saveToEeprom`, `_sendSaveOnly`, `executeAndSave`, `_waitForTransition`, `_waitForDone`, `setConfigView`, `setPamMode`) stayed in the class body in the root file — these are the foundational members every write helper (and each other) depends on.

**Why mixins, not just `part`/`part of` on their own:** unlike the Phase 2 split above, this file is ONE class, not many independent top-level classes. Dart has no partial-class feature — a class's members must all be declared in one contiguous class body, even across part files in the same library. The only mechanical way to move a subset of one class's methods into their own file is a mixin applied via `with`.

**Correction (caught by `flutter analyze` immediately after the first commit):** the first version of this split used `mixin _XxxWrites on BleCommandController`, expecting the `on` constraint to give each mixin implicit access to `BleCommandController`'s members (`_md`, `execute()`). That does not compile: `class BleCommandController with _XxxWrites` while `_XxxWrites` itself constrains `on BleCommandController` is a circular supertype declaration — the analyzer rejects it as `recursive_interface_inheritance`, and every method contributed by every mixin then reports as undefined on `BleCommandController` (114 `flutter analyze` errors, all from this one mistake). Fixed by dropping the `on` clause entirely: each mixin instead declares two minimal **abstract** members it needs — `Future<bool> execute(...)` (exact original signature, including default values) and `MachineData get _md;` — which `BleCommandController`'s own class body satisfies concretely, same as before. This is still zero new *public* interface: the abstract redeclarations are private, exist purely to satisfy Dart's mixin-composition mechanics, and no member was made public or renamed. `simple_parameter_writes.dart` only needs `execute` (it never reads `_md`); the other three mixins declare both.

**External API impact: none.** `advanced_config_screen.dart`, `basic_config_screen.dart`, and `custom_drawer.dart` — the only three files that reference `BleCommandController`/`bleCommandProvider` — needed zero changes, not even import paths. Every public method kept its exact name, argument order, and return type; mixin-contributed methods are genuine instance methods, dispatched and called (`cmd.writeFunction(...)`, etc.) identically to before the split.

**Verification performed before committing:** repo-wide grep (against freshly re-staged device copies, not older local ones) confirmed the full external-usage surface — `writeFunction`, `writeSens`, `writeCcMode`, `writeEnableB`, `writeLimit`, `writePolarity`, `writeAIN`, `writeRamp`, `writeMin`, `writeMax`, `writeTrigger`, `writeDitherAmplitude`, `writeDitherFrequency`, `writePwm`, `writeCurrent`, `setConfigView` from Advanced/Basic Config, `execute` from Basic Config, and `setPamMode` from `custom_drawer.dart`; `saveToEeprom`, `executeAndSave`, `isBusy`, `writePpwm`, `writeIpwm`, `writeAcceleration`, and the three timing constants confirmed to have no current external callers (unchanged from Phase 1 — kept for parity, not removed). All 26 methods, all 5 getters, all 3 constants, the constructor, and the `_ref` field were extracted and diffed byte-for-byte between the original and the new split — all identical, no mismatches, **including after** the `on`-clause fix (only the mixin header/abstract-requirement lines changed; no write-method body was touched by the fix). Brace/paren/bracket balance verified per file. Confirmed `normalizeCoefType()` (from `utils/coef_normalizer.dart`, Phase 1) is reused as-is in `ain_coefficient_writes.dart` with no `_normalizeCoefType()` duplicate recreated anywhere.

**Caveat:** this session has no local `dart`/`flutter` toolchain, so the fix above was verified by hand (structural brace/paren balance, byte-for-byte method-body diffing, and manually re-checking each `flutter analyze` error against the corrected source) rather than by re-running `flutter analyze` here. Please re-run `flutter analyze` after pulling this commit and report back if anything still doesn't compile.

**Do not** reintroduce a flat single-file `ble_command_controller.dart`, and do not split further into one file per parameter (18 files) — the four groups above are by actual code shape (simple single-value writes vs. diffed per-channel writes vs. the one AIN/coefficient method vs. current/ramp-family writes), not by the 15 Configure parameter numbers. If a new write helper is added, put it in the most fitting existing mixin file by its actual pattern (simple vs. diffed vs. current/ramp), not a new file, unless it genuinely doesn't fit any existing group.

## Phase 4 — AdvancedConfigScreen structural split (2026-09)

`lib/screens/navigate_screens/advanced_config_screen.dart` was a single ~1,954-line file (64,030 bytes) holding `kParamDefs`/`ParamGroup`/`ParamDef` (parameter metadata), the `AdvancedConfigScreen` widget, its single `_AdvancedConfigScreenState` (PAM_MODE draft-seeding listener, CONFIG_VIEW one-time-EXP guard, `_saveConfig()`, `_openParamSheet()`, `build()`, the 15-parameter `_buildParamForm()` router), the parameter-select bottom sheet (`_ParamSelectSheet`/`_ParamSelectSheetState`), `_MasterSelector`, and all 15 independent per-parameter renderer widgets (`_Param01Function` … `_Param15Current`, plus `_PWMField`, a private helper used only by `_Param14PWM`). Pure structural refactor — **zero functional, BLE-protocol, timing, parsing, draft-state, PAM_MODE, CONFIG_VIEW, save/readback, validation, or UI-text/styling change** — split into:

```
lib/screens/navigate_screens/
├── advanced_config_screen.dart                       (library root: imports, rationale banner, `part` directives, kParamDefs, ParamGroup, ParamDef, AdvancedConfigScreen, and the FULL unsplit _AdvancedConfigScreenState)
└── advanced_config_screen/
    ├── param_selector.dart                            _kParamSheetItemExtent, _ParamSelectSheet, _ParamSelectSheetState, _MasterSelector
    ├── param_forms_simple.dart                         _Param01Function, _Param02Sens, _Param03CCMode, _Param04EnableB, _Param11Trigger
    ├── param_forms_diffed.dart                         _Param05Limit, _Param06Pol, _Param09Min, _Param10Max, _Param12DitherAmp, _Param13DitherFreq, _Param14PWM, _PWMField
    ├── param_forms_ain.dart                            _Param07AIN (self-contained: its own _openAinDialog/_openAinBDialog/_buildAinChannelCard/_ainCoefTypeLabel/_buildPill helpers)
    └── param_forms_current_ramp.dart                   _Param08Ramp, _Param15Current
```

**Why `_AdvancedConfigScreenState` was deliberately left unsplit (not mixin-ed):** Phase 3's mistake (see above) was caused by mixin composition on a single stateful class. `_AdvancedConfigScreenState` extends `ConsumerState<AdvancedConfigScreen>` and every one of its methods reaches for `context`, `mounted`, `setState`, or `widget` — Flutter/Riverpod framework members, not members this app defines — so a Phase-3-style mixin would need `on ConsumerState<AdvancedConfigScreen>` or a long list of abstract redeclarations for framework-owned members, reintroducing the exact risk class Phase 3 already got burned by. The task's own hard rules also explicitly warned against new abstractions "merely to make the file smaller." So the split here extracts only what was already structurally independent — 15 self-contained `StatelessWidget` parameter renderers, the bottom-sheet widget, and `_MasterSelector` — via plain `part`/`part of`, with **zero mixins** and **zero renames**. `_AdvancedConfigScreenState`'s body is 100% byte-identical to the original, just relocated verbatim into the root file alongside the metadata it was already colocated with.

**Why `part`/`part of` (same mechanism as Phase 2, not Phase 3):** all 15 parameter widgets, `_ParamSelectSheet`/`_ParamSelectSheetState`, and `_MasterSelector` are already independent top-level classes (like Phase 2's widget family), not members of one class needing mixin composition (like Phase 3). `part`/`part of` keeps every part file inside the one `advanced_config_screen` library, so `_PWMField` stays exactly as private as before despite moving to a different file, with no symbol made public.

**External API impact: none.** `config_screen.dart` — the only file in the repo that references `AdvancedConfigScreen` (`pamMode == '...' ? AdvancedConfigScreen() : BasicConfigScreen()`) — needed zero changes, not even its import path. `kParamDefs`, `ParamDef`, and `ParamGroup` have no external references anywhere in the repo. `hasChangesForSelectedParam` (used by the PAM_MODE stale-draft guard inside `_AdvancedConfigScreenState`) is imported from `providers/advanced_config_draft_provider.dart` as before — it is not, and was never, a local symbol of this file, so it was correctly left untouched rather than moved.

**Verification performed before committing:** repo-wide grep confirmed the external-reference surface described above. Brace/paren/bracket balance verified per file (all 6: root + 5 part files) with a comment/string-literal-aware Python scanner. All 23 top-level symbols (`ParamGroup`, `ParamDef`, `AdvancedConfigScreen`, `_AdvancedConfigScreenState`, `_ParamSelectSheet`, `_ParamSelectSheetState`, `_MasterSelector`, all 15 `_ParamXX*` widgets, `_PWMField`) plus `kParamDefs` were extracted and diffed byte-for-byte against the pristine pre-split original — all identical, confirmed present exactly once each with no duplicates anywhere in the split. One transcription slip was caught and fixed by this diff pass (same class of mistake documented in Phase 2's AGENTS.md entry): several Unicode punctuation characters in string/comment literals that the original source spelled as literal `\uXXXX` escapes (`·` middle dot, `–`/`—` en/em dash, `→` arrow, `≈` approx, `×`/`÷` multiply/divide) were written back by the file-write step as the literal glyphs instead of the escape text; corrected via a raw byte-level Python replace (not the Edit tool, per the established lesson) and re-verified byte-for-byte identical to the original afterward. The banner comment and doc-comments newly authored for this split (not moved code) were left using literal glyphs, since they are original prose, not a verbatim-moved region.

**Caveat:** this session has no local `dart`/`flutter` toolchain, so — as with Phase 3 — this was verified structurally (brace/paren balance, byte-for-byte symbol diffing, repo-wide reference grep) rather than by an actual compile. Please run `flutter analyze` after pulling this commit and report back if anything doesn't compile.

**Do not** reintroduce a flat single-file `advanced_config_screen.dart`, and do not mixin-split `_AdvancedConfigScreenState` — see the rationale above; that risk class is exactly what Phase 3's mistake came from, and this file's tight coupling to `ConsumerState`'s own framework members makes it worse here, not better. If a new per-parameter widget is ever added (16th parameter), put it in the part file matching its actual data-shape pattern (simple/diffed/AIN/current-ramp), not a new one-off file, unless it genuinely doesn't fit any existing group — mirroring the Phase 3 guardrail.
