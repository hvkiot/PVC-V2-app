part of '../parameter_widgets.dart';

/// Tabbed panel with two tab children (e.g. AIN input type / advanced scaling).
class TabbedPanelCard extends StatelessWidget {
  final String title;
  final String command;
  final String? subtitle;
  final List<String> tabLabels;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final List<Widget> tabChildren;
  final bool enabled;

  const TabbedPanelCard({
    super.key,
    required this.title,
    required this.command,
    required this.tabLabels,
    required this.selectedTab,
    required this.onTabChanged,
    required this.tabChildren,
    this.subtitle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title  $command',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            // Tab bar
            Row(
              children: List.generate(tabLabels.length, (i) {
                final isSelected = i == selectedTab;
                return Expanded(
                  child: GestureDetector(
                    onTap: enabled ? () => onTabChanged(i) : null,
                    child: Container(
                      margin: EdgeInsets.only(
                        right: i < tabLabels.length - 1 ? 6 : 0,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withAlpha(60),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(11),
                        color: isSelected
                            ? theme.colorScheme.primary.withAlpha(15)
                            : Colors.transparent,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tabLabels[i],
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            // Tab content
            tabChildren[selectedTab],
          ],
        ),
      ),
    );
  }
}
