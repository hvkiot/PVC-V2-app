part of '../advanced_config_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
//  TOP-LEVEL WIDGETS
// ════════════════════════════════════════════════════════════════════════════

// Fixed ListTile row height for the parameter-select sheet below, used as
// ListView.builder's itemExtent so the initial scroll offset can be
// computed exactly (selectedIndex * itemExtent) rather than measured from
// a built row. Matches Material's standard two-line ListTile height
// (one-line title + one-line subtitle, default vertical padding) that
// these rows already use.
const double _kParamSheetItemExtent = 72.0;

/// Parameter-select bottom sheet content \u2014 a dedicated widget (not an
/// inline `builder:` closure) specifically so it can own and correctly
/// dispose a [ScrollController] scoped to this one sheet instance.
///
/// Replaces a previous `Scrollable.ensureVisible()` attempt that did not
/// reliably work: `ListView.builder` only builds/lays out the rows
/// currently within (or very near) its viewport, so a `GlobalKey` on a
/// row far from the top (e.g. parameter 13 or 15, while the sheet opens
/// scrolled to 0) has no `currentContext` yet on the very first post-frame
/// callback \u2014 `ensureVisible` had nothing to scroll to and silently did
/// nothing. Jumping to a directly-computed pixel offset has no such
/// dependency: with a fixed [_kParamSheetItemExtent], the target offset for
/// any index is known before any row is built.
class _ParamSelectSheet extends ConsumerStatefulWidget {
  const _ParamSelectSheet();

  @override
  ConsumerState<_ParamSelectSheet> createState() => _ParamSelectSheetState();
}

class _ParamSelectSheetState extends ConsumerState<_ParamSelectSheet> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Runs once, right after this sheet's first layout — not on every
    // rebuild (initState runs exactly once per sheet instance/open).
    WidgetsBinding.instance.addPostFrameCallback(_jumpToSelected);
  }

  void _jumpToSelected(Duration _) {
    if (!mounted || !_scrollController.hasClients) return;
    final currentParam = ref.read(selectedAdvancedConfigParamProvider);
    final selectedIndex = kParamDefs.indexWhere((p) => p.id == currentParam);
    if (selectedIndex < 0) return;

    final position = _scrollController.position;
    final availableListHeight = position.viewportDimension;
    // Center the selected row in the visible list when there's room;
    // clamp handles both ends — param 01 clamps to 0.0, param 15 clamps to
    // maxScrollExtent (bottom of the list) rather than overshooting.
    final targetOffset =
        (selectedIndex * _kParamSheetItemExtent -
                (availableListHeight - _kParamSheetItemExtent) / 2)
            .clamp(0.0, position.maxScrollExtent);
    _scrollController.jumpTo(targetOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Single source of truth, same provider the rest of Advanced Config
    // uses — no separate/competing selection state introduced here.
    final currentParam = ref.watch(selectedAdvancedConfigParamProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select Parameter',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              controller: _scrollController,
              itemExtent: _kParamSheetItemExtent,
              shrinkWrap: true,
              itemCount: kParamDefs.length,
              itemBuilder: (ctx, i) {
                final p = kParamDefs[i];
                final isSelected = p.id == currentParam;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primaryContainer,
                    child: Text(
                      p.id,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : Colors.white,
                      ),
                    ),
                  ),
                  title: Text(
                    p.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    p.command,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () {
                    ref
                            .read(selectedAdvancedConfigParamProvider.notifier)
                            .state =
                        p.id;
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MasterSelector extends StatelessWidget {
  final String currentId;
  final ParamDef paramDef;
  final VoidCallback onTap;
  const _MasterSelector({
    required this.currentId,
    required this.paramDef,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(
                'Parameter',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '$currentId \u00B7 ${paramDef.name}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
