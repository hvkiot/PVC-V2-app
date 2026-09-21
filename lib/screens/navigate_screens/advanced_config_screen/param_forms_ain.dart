part of '../advanced_config_screen.dart';

class _Param07AIN extends StatelessWidget {
  final AdvancedConfigDraft draft;
  final AdvancedConfigDraftNotifier draftNotifier;
  final bool isLocked;
  final String mode;
  const _Param07AIN({
    required this.draft,
    required this.draftNotifier,
    required this.isLocked,
    required this.mode,
  });

  Future<void> _openAinDialog(BuildContext context) async {
    final result = await AinEditDialog.show(
      context,
      initialA: draft.ainAa,
      initialB: draft.ainAb,
      initialC: draft.ainAc,
      // Parameter 07 edits the coefficient type, not the live/root AIN type.
      initialX: draft.ainACoefType,
      channelLabel: 'A',
    );
    if (result != null) {
      draftNotifier.setAinAa(result.a);
      draftNotifier.setAinAb(result.b);
      draftNotifier.setAinAc(result.c);
      draftNotifier.setAinACoefType(result.x);
    }
  }

  Future<void> _openAinBDialog(BuildContext context) async {
    final result = await AinEditDialog.show(
      context,
      initialA: draft.ainBa,
      initialB: draft.ainBb,
      initialC: draft.ainBc,
      // Parameter 07 edits the coefficient type, not the live/root AIN type.
      initialX: draft.ainBCoefType,
      channelLabel: 'B',
    );
    if (result != null) {
      draftNotifier.setAinBa(result.a);
      draftNotifier.setAinBb(result.b);
      draftNotifier.setAinBc(result.c);
      draftNotifier.setAinBCoefType(result.x);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dual = mode == '196';
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ParamHeader(
          id: '07',
          name: 'AIN',
          command: dual ? 'AIN:A \u00B7 AIN:B' : 'AIN:A',
          subtitle: 'Command input type and scaling',
        ),
        const SizedBox(height: 8),
        _buildAinChannelCard(
          context,
          theme,
          label: 'Channel A',
          command: 'AIN:A',
          type: draft.ainACoefType,
          a: draft.ainAa,
          b: draft.ainAb,
          c: draft.ainAc,
          onTap: isLocked ? null : () => _openAinDialog(context),
        ),
        if (dual) ...[
          const SizedBox(height: 8),
          _buildAinChannelCard(
            context,
            theme,
            label: 'Channel B',
            command: 'AIN:B',
            type: draft.ainBCoefType,
            a: draft.ainBa,
            b: draft.ainBb,
            c: draft.ainBc,
            onTap: isLocked ? null : () => _openAinBDialog(context),
          ),
        ],
      ],
    );
  }

  Widget _buildAinChannelCard(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required String command,
    required String type,
    required int a,
    required int b,
    required int c,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      command,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildPill(theme, 'Type', _ainCoefTypeLabel(type)),
                  const SizedBox(width: 8),
                  _buildPill(theme, 'A', a.toString()),
                  const SizedBox(width: 8),
                  _buildPill(theme, 'B', b.toString()),
                  const SizedBox(width: 8),
                  _buildPill(theme, 'C', c.toString()),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Explicit coefficient-type → display-label mapping. Confirmed hardware
  /// behavior: PAM readback does NOT echo the token the app writes — it
  /// reports "U" for voltage and "I" for current (write V -> readback U;
  /// write C -> readback I). "V"/"U" both mean Voltage; "C"/"I" both mean
  /// Current — this raw value (MachineData.expConfig.ainACoefType/
  /// ainBCoefType) is untouched, only the display label is mapped here.
  /// Deliberately NOT `type == 'V' ? 'Voltage' : 'Current'` — that would
  /// show "Current" for an uninitialized/unknown value (e.g. "None",
  /// empty) instead of "Unknown", which is what an unconfirmed coefficient
  /// type actually is.
  String _ainCoefTypeLabel(String type) {
    switch (type) {
      case 'V':
      case 'U':
        return 'Voltage';
      case 'C':
      case 'I':
        return 'Current';
      default:
        return 'Unknown';
    }
  }

  Widget _buildPill(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
