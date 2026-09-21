import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Reusable parameter form widgets — match AppTextCard / AppSelectorCard theme
// ---------------------------------------------------------------------------
//
// STRUCTURAL SPLIT (Phase 2, 2026-09): this file is now only the library
// root for the parameter-widgets library — a plain manifest of imports and
// `part` directives. The actual widget implementations live in the
// `parameter_widgets/` part files below. This is a pure code-motion / file
// re-organization: no widget, API, state, or behavior changed.
//
// Why `part`/`part of` instead of ordinary per-file `import`s: Dart privacy
// is per-library, not per-class. Several small private helper widgets here
// (the shared stepper/quick buttons) are used by more than one widget family
// that now live in different files — e.g. `_StepperButton` is used by both
// `NumericStepperCard` and `RampRow`. `part`/`part of` keeps every part file
// in this single library, so those helpers stay exactly as private as they
// were before, with zero renames and zero import changes required anywhere
// else in the app (in particular, `advanced_config_screen.dart`'s existing
// `import '.../parameter_widgets.dart';` is unaffected — it still resolves
// every symbol from this one library, same as before the split).
//
// Public symbols (unchanged since before the split): ParamHeader,
// SegmentedCard, NumericStepperCard, DropdownValueCard, PolarityCard,
// TabbedPanelCard, RampRow, SafetyBanner, HelpCard, CurrentLoopGainRow.
//
// See AGENTS.md "Phase 2 — parameter_widgets structural split (2026-09)" for
// the full audit and file-grouping rationale.

part 'parameter_widgets/info_widgets.dart';
part 'parameter_widgets/segmented_controls.dart';
part 'parameter_widgets/buttons.dart';
part 'parameter_widgets/numeric_stepper.dart';
part 'parameter_widgets/dropdown_value.dart';
part 'parameter_widgets/tabbed_panel.dart';
part 'parameter_widgets/ramp_row.dart';
part 'parameter_widgets/current_loop_gain.dart';
