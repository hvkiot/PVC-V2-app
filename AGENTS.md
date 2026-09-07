# AGENTS.md

## Commands

- Analyze: `flutter analyze`. Pre-existing info-level `avoid_print` hints in `lib/screens/navigate_screens/inputs_screen.dart` — do not chase them.
- Codegen: after editing json_serializable models run `dart run build_runner build --delete-conflicting-outputs` (regenerates `lib/models/machine_data.g.dart`). Never edit `.g.dart` files by hand.
- Builds: `flutter build apk --release` and `flutter build appbundle` (Play Store artifact).
- Test hardware is a physical device ("JKM LX1", Android 9 / API 28) over USB — find it via `flutter devices`. No emulator is used.
- Unit tests: `flutter test` runs all tests. L/D/F parser tests in `test/models/machine_data_test.dart` (19 tests: 7 legacy + 12 L/D/F). Test command: `flutter test test/models/machine_data_test.dart`

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

## Physical pins — READ-ONLY for the app

These are wired hardware. The app can display their state but must never pretend to switch them.

| Physical item | What it is | App CAN | App CANNOT |
|---|---|---|---|
| **PIN 15** | General enable input, 24 V. Hardware master switch for the whole amplifier power stage. While ON, solenoid outputs may carry up to 2.6 A. | Read its state (`PIN15` key in `machine_data`) and show lock banners | Toggle it, or allow any EEPROM edit while it is ON |
| **PIN 6** | S1 / Enable-B input, 24 V. Secondary enable: gates Channel B in FUNCTION 196, or controls ramp execution. | Read its state (`PIN6` key) | Toggle it. Note: `ENABLE_B` is a software parameter that only REDEFINES this pin's role — the 24 V signal itself stays hardware |
| **Analog input type** | Software parameter `x` inside `AIN [a,b,c,x]` — `V` voltage or `C` current loop (internal 390 Ω shunt auto-engages in C mode) | Set via AIN write (wiring must match) | Treat it as a physical housing selector (it is not) |

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
- `BleState` holds accumulated `MachineData machineData` — the single authoritative source for all parsed telemetry. `machineDataProvider` returns `bleState.machineData` directly.
- `lib/models/machine_data.dart`: `MachineData` model with `mergeFromPacket()` for L/D/F accumulation, `fromPacket()` for legacy parsing, and `_parseKeyValue()` for dual key naming (abbreviated + long-form).

## BLE protocol (single new kit + L/D/F telemetry)

- GATT UUIDs are hardcoded in `ble_provider.dart`: service `12345678-1234-5678-1234-56789abcdef0`, write/notify char `...f1`, log service/char `...f2`/`...f3`.
- **Only the new kit is supported** (old/separate-command protocol was removed). Mode changes send one atomic string `"FUNC:UNIT[:CA:VAL][:CB:VAL][:CS:VAL]"` (e.g. `196:V:CA:1200:CB:1300` or `195:C:CS:1500`); CA/CB/CS are omitted when 1000 mA. Standalone AIN type uses bare `"Voltage"`/`"Current"` and standalone currents use `CUR`/`CURA`/`CURB`. The kit acknowledges by flipping `TRANSITION:True`, back to `False` when done.
- **Function-change D| packets are coalesced:** `handleChangeMode` synchronously re-reads CURRENT setpoints after the PAM reboot and stores them atomically with FUNC/MODE in one critical section. The app receives a single `D|FUNC:196,MODE:V,CURRENT_A:1000,CURRENT_B:1000` (196) or `D|FUNC:195,MODE:C,CURRENT_S:1000` (195) packet, followed by `D|TRANSITION:False` ~500ms later. Only the current fields relevant to the target mode appear (196 → A+B, 195 → S); inactive fields are excluded.
- **`PAM_CONNECTED:True/False`** is emitted in delta packets when the PAM USB connection state changes (connect/disconnect).
- Busy lock: `writeToCharacteristic()` silently drops writes while `isBusy` (cleared on `TRANSITION:False`, write error, or an 8 s guard timer). `writeRawToCharacteristic()` bypasses the busy gate and is reserved for the `SYNC` command, which is sent over the notify channel right after subscription so it is never dropped.
- Transition clear: firmware uses a non-blocking `transitionClearMillis` deadline (set to `millis() + 500` at handler exit). The loop() block emits `D|TRANSITION:False` when the deadline elapses — not inline in the handler. The app should treat any `TRANSITION:False` as the done signal.
- Save flow in `inputs_screen.dart` and `std_screen.dart` (new-protocol only): sends the combined/atomic command, waits up to 3 s for the TRANSITION ack, then waits up to 10 s for TRANSITION to clear (hardware done, 4 s for param-only). No old-protocol fallback.
- `requestSync()` asks the kit for a fresh `F|` full snapshot at the moment the notify channel is confirmed open.

### L/D/F telemetry protocol (ESP32→Flutter)

- ESP32 sends three packet formats over the notification characteristic:
  - `L|key:value|key:value|...` — Live update (~75 bytes, ~200ms interval). Contains WA/WB/IA/IB/READY/PIN15/PIN6 and currently active fields.
  - `D|key:value|key:value|...` — Delta: only dirty fields since last L| or D| packet. Requires累积 state from previous packets. For function changes, FUNC/MODE and the relevant CURRENT fields (A+B for 196, S for 195) are coalesced into a single D| packet.
  - `F|key:value|key:value|...` — Full snapshot: all 17 fields. Sent on mode change or periodically to resync.
- `MachineData.mergeFromPacket(packet, currentState)` in `lib/models/machine_data.dart` handles all three formats. It accumulates state across packets: L| and D| merge into existing state, F| replaces state entirely.
- `_parseKeyValue()` supports dual key naming: abbreviated JSON keys (`CURRENT_A`, `ENABLE_B`, `TRANSITION`, `PAM_CONNECTED`) AND long-form ESP32 legacy keys (`CURRENT_A_STATUS`, `ENABLED_B`, `ADAPTER_VOLTAGE`, `FIRMWARE_VERSION`, `ADAPTER_CURRENT`).
- `BleState.machineData` holds the accumulated `MachineData` — the single authoritative source. `machineDataProvider` returns `bleState.machineData` directly (no re-parsing from raw string).
- The old `MachineData.fromPacket()` legacy parser is preserved for backwards compatibility; `mergeFromPacket()` delegates to it for packets without an L/D/F prefix.

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

## UI rebuild optimization (PamDataScreen)

- `PamDataScreen` uses extracted `ConsumerWidget` sub-widgets with granular `select()` calls to minimize unnecessary rebuilds.
- Each sub-widget watches only the specific `MachineData` fields it needs (e.g., `select((s) => s.machineData.pin15)`, `select((s) => s.machineData.ready)`).
- This prevents the entire screen from rebuilding when any single field changes.
- Sub-widgets: `PamHeader`, `PinStatusSection`, `PamDetailsCard`, `ReadyStatusRow`, `OutputStatusRow`, `ConnectionStatusRow`, `BusyStatusRow`, `ErrorStatusRow`, `PamDetailsSection`, `RawDataExpansion`, `PamDataActions`.

## STD Screen — unified 195/196 (lib/screens/navigate_screens/std_screen.dart)

- Single screen for both FUNCTION 195 (single coil) and 196 (dual coil); mode selector + AINA + current(s) + Save.
- Save builds atomic command `MODE:UNIT[:CA:VAL][:CB:VAL][:CS:VAL]` on mode change (one PAM transition) — CA/CB/CS omitted when 1000 mA default. Standalone edits use `CUR`/`CURA`/`CURB` and bare `V`/`C` for AIN type.
- Busy guard: `writeToCharacteristic(busyTimeout: doneTimeoutFunctionChange=10s)` for mode changes, 4s for param changes; wait loop polls `TRANSITION` at 10ms (3s ack + 10s/4s done).
- Draft reset: `inputsTabProvider.selectedMode` and `machineData.func` listeners reset currents to 1000 defaults on mode switch.
- UI layout: `GridView.count` (1 col <600px, 2 cols >=600px) of cards — Mode banner (primary bg) + AINA card(s) + Coil current card(s); pill Save button with spinner; `ResponsiveWrapper(maxWidth:600)`; Dividers `onSurface.withAlpha(48)`.

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
|---|---|---|---|---|---|---|
| 01 | Function | — | `FUNCTION` | 195 / 196 | — | Segmented. Interlock: PIN 15 & 6 must be OFF (physical). Confirm dialog: wipes ALL tuning to defaults. After change: ID → SAVE. |
| 02 | SENS | STD | `SENS` | `ON`/`OFF`/`AUTO` | `AUTO` | AUTO self-resets + rechecks error status every second. ON/AUTO: wire break → output current cut immediately + READY (PIN 5) OFF. Errors acked by cycling PIN 15 OFF→ON. |
| 03 | CC Mode | EXP | `CCMODE` | `ON`/`OFF` | `OFF` | ON = 10-point linearization curves (PAM DATA), OFF = direct linear mapping. |
| 04 | Enable-B | EXP | `ENABLE_B` | `ON`/`OFF` | `OFF` | ON: PIN 15 enables Ch A, PIN 6 enables Ch B · OFF: PIN 15 globally enables both. Redefines PHYSICAL Pin 6 role only. Visible only @196; grey info box otherwise. |
| 05 | LIMIT | EXP | `LIM` / `LIM:A`,`LIM:B` | raw int 0–2000 step 50 | `0` (off) | Wire-break/short-circuit detection threshold for command signals. User enters the raw matrix integer directly. Numeric field + steppers @195 global / @196 A+B. |
| 06 | POL | STD | `POL` / `POL:A`,`POL:B` | `+`/`-` | `+` | Output direction per coil; single @195, two @196. |
| 07 | AIN | EXP | `AIN:A` @195 · `AIN:A`,`AIN:B` @196 | a,b,c each −10000…10000; x=`V`/`C` | `a=1000 b=1000 c=0 x=V` | Format `[a,b,c,x]`, Output = a/b × (Input − c), resolution 0.01 %. x=C engages internal 390 Ω shunt. Input Type tab + Advanced Scaling tab. AIN:B hidden @195. |
| 08 | Ramp | STD | 195: `AA:1..4` · 196: `AA:UP/DOWN`,`AB:UP/DOWN` | 1–120000 ms | `100 ms` | Transition time over 100 % full-scale step. Numeric fields + ±10 ms steppers + quick +50/+500/+1000 ms chips. Labels relabel per function. |
| 09 | MIN | STD | `MIN:A`,`MIN:B` | raw int 0–6000 step 50 | `0` | Spool overlap compensation; yellow warning if raw &gt; 3000 (&asymp; 30 %). |
| 10 | MAX | STD | `MAX:A`,`MAX:B` | raw int 5000–10000 step 50 | `10000` | Solenoid output scaling; clamped low end. |
| 11 | Trigger | STD | `TRIGGER` | raw int 0–3000 step 50 | `200` | Threshold point where the MIN jump activates. |
| 12 | Dither Amplitude | STD | `DAMPL` / `DAMPL:A`,`:B` | raw int 0–3000 step 50 | `500` | Tied to CURRENT — auto-rescaled proportionally. Output mA = raw &divide; 100 &times; nominal. Flashing warning if PWM &lt; 500 Hz. |
| 13 | Dither Frequency | STD | `DFREQ` / `DFREQ:A`,`:B` | 60–400 Hz step 1 | `121 Hz` | Anti-stiction carrier; numeric field + ±1 Hz steppers. |
| 14 | PWM Frequency | EXP | `PWM` @195 · `PWM:A`,`PWM:B` @196 | Discrete list: 61,72,85,100,120,150,200,269,372,488,624,781,976,1201,1420,1562,1736,1953,2232,2604 Hz | `2604 Hz` | Numeric field whose steppers walk the strict discrete list; typed values snap to nearest step (off-list rejected by firmware). ACC toggle ON hides manual PI gains block. |
| 15 | Current | STD | `CURRENT` @195 · `CURRENT:A`,`:B` @196 | 500–2600 mA step 50 | `1000 mA` | Stages regulate up to 2.6 A. Changing CURRENT auto-rescales MIN/MAX/DAMPL. (Coil calculator card removed per manager feedback.) |

**Global numeric-input UI rule (v2 design, all Configure params):** no sliders anywhere — every quantity uses a text input flanked by −/+ stepper buttons with a permanently visible unit (% / ms / Hz / mA). User types the raw matrix integer directly — no percentage math in the UI. The five percent-scale parameters (LIM 0–2000, MIN 0–6000, MAX 5000–10000, TRIGGER 0–3000, DAMPL 0–3000) show a permanent helper note referencing the % equivalence but the input itself is always the raw value. Ramp/DFREQ/CURRENT accept ms/Hz/mA directly. Inputs validate on commit: parse (comma or dot), clamp to parameter min/max, format to the parameter's decimal count; PWM snaps to the nearest allowed discrete frequency.

Design mockups: `pvc-config-redesign-v2.html` (current interactive master-layout prototype: dropdown-driven 15 forms, function-context preview, PIN simulator, skeleton fetch, factory-reset dialog — approved design source) · legacy static `pam_configure_screen.html` (+ v1 backup). Pending manager approval before Flutter implementation.
