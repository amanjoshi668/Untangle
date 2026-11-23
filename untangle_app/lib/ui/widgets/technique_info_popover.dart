import 'package:flutter/material.dart';
import '../../data/decision_book_catalog.dart';
import '../../models/decision_model.dart';
import '../untangle_theme.dart';
import 'brand_widgets.dart';
import 'untangle_character.dart';

/// Compact floating '?' popover card — spring-animated and never full-screen.
Future<void> showTechniqueInfoPopover({
  required BuildContext context,
  required DecisionModelSpec spec,
  ValueChanged<int>? onSelectRelatedModel,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss technique guide',
    barrierColor: Colors.black.withOpacity(0.30),
    transitionDuration: const Duration(milliseconds: 240),
    transitionBuilder: (ctx, anim, _, child) {
      final scale = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween<double>(begin: 0.90, end: 1.0).animate(scale), child: child),
      );
    },
    pageBuilder: (ctx, _, __) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;
      return Dialog(
        key: Key('technique_info_popover_${spec.id}'),
        elevation: 8,
        backgroundColor: cs.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cs.outline),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 332, maxHeight: 430),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionMonogram(spec: spec, size: 42),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${spec.section.shortLabel.toUpperCase()} · ${spec.minutes} MIN',
                            style: UntangleTheme.eyebrow(
                              UntangleTheme.sectionColor(spec.section, Theme.of(ctx).brightness),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(spec.title, style: UntangleTheme.display(ctx, size: 17)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      key: const Key('close_info_popover_btn'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: cs.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, size: 15, color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(spec.writeup, style: tt.bodyMedium?.copyWith(fontSize: 13)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: cs.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const UntangleCharacter(
                        mood: CharacterMood.aha,
                        size: 34,
                        interactive: false,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: tt.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.85)),
                            children: [
                              TextSpan(
                                text: 'How to use: ',
                                style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                              ),
                              TextSpan(text: spec.howTo),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: cs.primary, width: 2.5)),
                  ),
                  child: Text(
                    '"${spec.quote}"',
                    style: tt.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
                if (spec.seeAlso.isNotEmpty && onSelectRelatedModel != null) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: cs.outline),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Related:', style: tt.bodySmall),
                      for (final relId in spec.seeAlso)
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            onSelectRelatedModel(relId);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.secondary,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cs.outline),
                            ),
                            child: Text(
                              '#${relId.toString().padLeft(2, '0')} ${modelById(relId).title.replaceFirst('The ', '')}',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class QuestionMarkBadgeButton extends StatelessWidget {
  final Key? buttonKey;
  final VoidCallback onTap;

  const QuestionMarkBadgeButton({
    super.key,
    this.buttonKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      key: buttonKey,
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Tooltip(
        message: 'About this technique',
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.secondary,
            shape: BoxShape.circle,
            border: Border.all(color: cs.outline),
          ),
          child: Text(
            '?',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }
}
