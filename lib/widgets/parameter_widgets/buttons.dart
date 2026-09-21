part of '../parameter_widgets.dart';

// Small private button primitives shared across the numeric-stepper,
// ramp-row, and current-loop-gain widget families. Centralized here (Phase 2
// structural split) because each is used by more than one widget family;
// they stay `part of` the parameter_widgets library rather than becoming
// public, since they were never part of this file's external API.

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepperButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: enabled
            ? theme.colorScheme.primaryContainer
            : theme.disabledColor.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? theme.colorScheme.primary : theme.disabledColor,
          ),
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _QuickButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;

    return Material(
      color: enabled
          ? theme.colorScheme.primaryContainer
          : theme.disabledColor.withAlpha(30),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: enabled ? theme.colorScheme.primary : theme.disabledColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
