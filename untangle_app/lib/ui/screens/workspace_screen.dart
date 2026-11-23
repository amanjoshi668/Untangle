import 'package:flutter/material.dart';
import '../../models/decision_model.dart';
import '../../services/native_bridge_service.dart';
import '../../services/vault_storage.dart';
import '../untangle_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/canvas_engines.dart';
import '../widgets/technique_info_popover.dart';
import '../widgets/untangle_character.dart';

class WorkspacePane extends StatefulWidget {
  final DecisionModelSpec spec;
  final DecisionWorkspaceData workspace;
  final VaultStorage vault;
  final bool isSplitLayout;
  final VoidCallback? onBack;
  final VoidCallback onSavedToJournal;
  final ValueChanged<int> onSwitchModel;

  const WorkspacePane({
    super.key,
    required this.spec,
    required this.workspace,
    required this.vault,
    required this.isSplitLayout,
    this.onBack,
    required this.onSavedToJournal,
    required this.onSwitchModel,
  });

  @override
  State<WorkspacePane> createState() => _WorkspacePaneState();
}

class _WorkspacePaneState extends State<WorkspacePane> {
  late DecisionWorkspaceData _ws;
  late TextEditingController _topicCtrl;

  @override
  void initState() {
    super.initState();
    _ws = widget.workspace;
    _topicCtrl = TextEditingController(text: _ws.topic);
  }

  @override
  void didUpdateWidget(covariant WorkspacePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec.id != widget.spec.id || oldWidget.workspace != widget.workspace) {
      _ws = widget.workspace;
      _topicCtrl.text = _ws.topic;
    }
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  void _openCompactInfo() {
    showTechniqueInfoPopover(
      context: context,
      spec: widget.spec,
      onSelectRelatedModel: widget.onSwitchModel,
    );
  }

  Future<void> _exportCurrentMarkdown() async {
    final md = '# ${_ws.topic}\n\n'
        '- **Technique:** #${widget.spec.id.toString().padLeft(2, '0')} ${widget.spec.title}\n'
        '- **Takeaway:** ${_ws.computeTakeaway(widget.spec)}\n';
    await NativeBridgeService.saveExportDocument(
      filename: 'untangle_${widget.spec.id}.md',
      mimeType: 'text/markdown',
      content: md,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Markdown brief exported.'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isBookmarked = widget.vault.bookmarks.contains(widget.spec.id);
    final takeaway = _ws.computeTakeaway(widget.spec);

    return Container(
      color: cs.surface,
      child: Column(
        children: [
          // Minimal Workspace Header (Details under '?' button & '⋯' menu)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(bottom: BorderSide(color: cs.outline)),
            ),
            child: Row(
              children: [
                if (!widget.isSplitLayout && widget.onBack != null) ...[
                  InkWell(
                    key: const Key('workspace_back_btn'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: widget.onBack,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back_ios_new, size: 16, color: cs.onSurface),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: UntangleTheme.sectionColor(widget.spec.section, Theme.of(context).brightness),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          widget.spec.section.label,
                          style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                QuestionMarkBadgeButton(
                  buttonKey: const Key('workspace_question_btn'),
                  onTap: _openCompactInfo,
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: const Key('workspace_bookmark_btn'),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Bookmark technique',
                  onPressed: () async {
                    await widget.vault.toggleBookmark(widget.spec.id);
                    if (mounted) setState(() {});
                  },
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 19,
                    color: isBookmarked ? cs.primary : cs.onSurface.withOpacity(0.75),
                  ),
                ),
                PopupMenuButton<String>(
                  key: const Key('workspace_more_menu'),
                  tooltip: 'More options',
                  icon: Icon(Icons.more_horiz, size: 20, color: cs.onSurface.withOpacity(0.75)),
                  onSelected: (action) {
                    if (action == 'sample') {
                      setState(() {
                        _ws = DecisionWorkspaceData.fromSpec(widget.spec, loadSample: true);
                        _topicCtrl.text = _ws.topic;
                        widget.vault.setWorkspaceDraft(widget.spec.id, _ws);
                      });
                    } else if (action == 'clear') {
                      setState(() {
                        _ws = DecisionWorkspaceData.fromSpec(widget.spec, loadSample: false, initialTopic: _ws.topic);
                        widget.vault.setWorkspaceDraft(widget.spec.id, _ws);
                      });
                    } else if (action == 'info') {
                      _openCompactInfo();
                    } else if (action == 'export') {
                      _exportCurrentMarkdown();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'sample', child: Text('Load sample example', style: TextStyle(fontSize: 13))),
                    PopupMenuItem(value: 'clear', child: Text('Clear workspace inputs', style: TextStyle(fontSize: 13))),
                    PopupMenuItem(value: 'info', child: Text('About this technique (?)', style: TextStyle(fontSize: 13))),
                    PopupMenuItem(value: 'export', child: Text('Export as Markdown', style: TextStyle(fontSize: 13))),
                  ],
                ),
                const SizedBox(width: 2),
                FilledButton(
                  key: const Key('workspace_save_btn'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await widget.vault.saveDecisionFromWorkspace(widget.spec, _ws);
                    if (!mounted) return;
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: UntangleTheme.heroStart,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        content: const Row(
                          children: [
                            UntangleCharacter(
                              mood: CharacterMood.celebrating,
                              size: 34,
                              inkColor: UntangleTheme.paper,
                              accentColor: UntangleTheme.goldDark,
                              interactive: false,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Decision untangled & saved to Journal!',
                                style: TextStyle(color: UntangleTheme.paper, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    widget.onSavedToJournal();
                  },
                  child: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Scrollable Uncluttered Workspace Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroBand(context),
                  const SizedBox(height: 18),

                  Text('Your decision or topic', style: tt.bodySmall),
                  const SizedBox(height: 5),
                  TextField(
                    key: const Key('workspace_topic_field'),
                    controller: _topicCtrl,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(hintText: 'Enter your decision topic...'),
                    onChanged: (v) {
                      _ws.topic = v;
                      widget.vault.setWorkspaceDraft(widget.spec.id, _ws);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 18),

                  CanvasEngineWidget(
                    spec: widget.spec,
                    data: _ws,
                    onChanged: () {
                      widget.vault.setWorkspaceDraft(widget.spec.id, _ws);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 18),

                  // Dark editorial Takeaway card
                  Container(
                    key: const Key('workspace_takeaway_card'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [UntangleTheme.heroStart, UntangleTheme.heroEnd],
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const UntangleCharacter(
                          mood: CharacterMood.aha,
                          size: 46,
                          inkColor: UntangleTheme.paper,
                          accentColor: UntangleTheme.goldDark,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TAKEAWAY', style: UntangleTheme.eyebrow(UntangleTheme.goldDark)),
                              const SizedBox(height: 6),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: Text(
                                  takeaway,
                                  key: ValueKey(takeaway),
                                  style: const TextStyle(
                                    fontFamily: UntangleTheme.displayFamily,
                                    fontSize: 14.5,
                                    height: 1.45,
                                    color: UntangleTheme.paper,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBand(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final sc = UntangleTheme.sectionColor(widget.spec.section, Theme.of(context).brightness);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [sc.withOpacity(0.16), sc.withOpacity(0.03)],
        ),
        border: Border.all(color: sc.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionMonogram(spec: widget.spec, size: 48),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.spec.title, style: UntangleTheme.display(context, size: 20)),
                const SizedBox(height: 3),
                Text(widget.spec.subtitle, style: tt.bodySmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    MetaChip(icon: EngineMeta.icon(widget.spec.engine), label: EngineMeta.label(widget.spec.engine)),
                    MetaChip(icon: Icons.schedule, label: '${widget.spec.minutes} min'),
                    MetaChip(label: widget.spec.section.axisLabel, color: sc),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
