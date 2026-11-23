import 'package:flutter/material.dart';
import '../../data/decision_book_catalog.dart';
import '../../models/decision_model.dart';
import '../../services/auth_service.dart';
import '../../services/gcp_backend_service.dart';
import '../../services/native_bridge_service.dart';
import '../../services/recommender_service.dart';
import '../../services/vault_storage.dart';
import '../untangle_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/technique_info_popover.dart';
import 'settings_sheet.dart';
import 'workspace_screen.dart';

class HomeShell extends StatefulWidget {
  final AuthService auth;
  final VaultStorage vault;
  final GcpBackendService backend;
  final DateTime Function()? clock;

  const HomeShell({
    super.key,
    required this.auth,
    required this.vault,
    required this.backend,
    this.clock,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _navIndex = 0; // 0: Decide, 1: Techniques, 2: Journal
  int? _activeModelId;

  // Mode 1 ("Decide") state
  final TextEditingController _problemCtrl = TextEditingController();
  ProblemScope _scope = ProblemScope.all;
  bool _showExamples = false;
  bool _showAlternatives = false;
  List<ModelRecommendation> _recommendations = [];

  // Mode 2 ("Techniques") state
  final TextEditingController _searchCtrl = TextEditingController();
  BookSection? _selectedSection;
  bool _showFilterRow = false;
  bool _onlyBookmarked = false;
  bool _onlyQuick = false;
  bool _compassMode = false;

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _recommendations = RecommenderService.suggestInstant('', _scope);
    widget.vault.addListener(_onStateChanged);
    widget.auth.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.vault.removeListener(_onStateChanged);
    widget.auth.removeListener(_onStateChanged);
    _problemCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  Color _sectionColor(BookSection s) => UntangleTheme.sectionColor(s, Theme.of(context).brightness);

  void _onProblemChanged(String val) {
    setState(() {
      _recommendations = RecommenderService.suggestInstant(val, _scope);
    });
    if (val.trim().split(RegExp(r'\s+')).length >= 10) {
      RecommenderService.suggestHybrid(val, _scope, widget.backend).then((upgraded) {
        if (mounted && _problemCtrl.text == val) {
          setState(() => _recommendations = upgraded);
        }
      });
    }
  }

  void _openTechnique(int modelId, {bool fromProblem = false, Map<String, dynamic>? savedMap}) {
    final spec = modelById(modelId);
    if (savedMap != null && savedMap.isNotEmpty) {
      widget.vault.setWorkspaceDraft(spec.id, DecisionWorkspaceData.fromMap(savedMap, spec));
    } else if (fromProblem && _problemCtrl.text.trim().isNotEmpty) {
      final seeded = RecommenderService.seedWorkspaceFromProblem(spec, _problemCtrl.text);
      widget.vault.setWorkspaceDraft(spec.id, seeded);
    }
    setState(() => _activeModelId = modelId);
  }

  String get _currentPageContext {
    if (_activeModelId != null) return 'Model #$_activeModelId';
    return const ['Decide', 'Techniques', 'Journal'][_navIndex];
  }

  String get _greeting {
    final h = _now.hour;
    if (h < 12) return 'GOOD MORNING';
    if (h < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isSplit = constraints.maxWidth >= 900;
        if (isSplit) {
          final splitSpec = modelById(_activeModelId ?? 6);
          final splitWs = widget.vault.getWorkspaceDraft(splitSpec);
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  SizedBox(
                    width: 384,
                    child: Column(
                      children: [
                        _buildTopHeader(context),
                        Expanded(child: _buildActiveTabBody(context, isSplit: true)),
                        _buildBottomBar(context, isSplit: true),
                      ],
                    ),
                  ),
                  VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outline),
                  Expanded(
                    child: WorkspacePane(
                      spec: splitSpec,
                      workspace: splitWs,
                      vault: widget.vault,
                      isSplitLayout: true,
                      onSavedToJournal: () => setState(() => _navIndex = 2),
                      onSwitchModel: (id) => _openTechnique(id),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (_activeModelId != null) {
          final spec = modelById(_activeModelId!);
          final ws = widget.vault.getWorkspaceDraft(spec);
          return Scaffold(
            body: SafeArea(
              child: WorkspacePane(
                spec: spec,
                workspace: ws,
                vault: widget.vault,
                isSplitLayout: false,
                onBack: () => setState(() => _activeModelId = null),
                onSavedToJournal: () => setState(() {
                  _activeModelId = null;
                  _navIndex = 2;
                }),
                onSwitchModel: (id) => _openTechnique(id),
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _buildTopHeader(context),
                Expanded(child: _buildActiveTabBody(context, isSplit: false)),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomBar(context, isSplit: false),
        );
      },
    );
  }

  // ===========================================================================
  // HEADER & FLOATING PILL NAVIGATION
  // ===========================================================================
  Widget _buildTopHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const titles = ['Untangle', 'Techniques', 'Journal'];
    final user = widget.auth.currentUser;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        children: [
          KnotMark(size: 16, color: cs.primary, strokeWidth: 2.4),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              titles[_navIndex],
              style: UntangleTheme.display(context, size: 22),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_navIndex == 2)
            TextButton.icon(
              key: const Key('journal_header_export_btn'),
              onPressed: () async {
                await NativeBridgeService.saveExportDocument(
                  filename: 'untangle_journal.md',
                  mimeType: 'text/markdown',
                  content: widget.vault.buildMarkdownBrief(),
                );
              },
              icon: const Icon(Icons.ios_share, size: 15),
              label: const Text('Export', style: TextStyle(fontSize: 12.5)),
            ),
          const SizedBox(width: 4),
          InkWell(
            key: const Key('open_settings_btn'),
            customBorder: const CircleBorder(),
            onTap: () => showSettingsAndVaultSheet(
              context: context,
              auth: widget.auth,
              vault: widget.vault,
              backend: widget.backend,
              pageContext: _currentPageContext,
            ),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: user.isGuest
                    ? null
                    : const LinearGradient(colors: [UntangleTheme.goldDark, UntangleTheme.brassLight]),
                color: user.isGuest ? cs.secondary : null,
                border: Border.all(color: user.isGuest ? cs.outline : Colors.transparent),
              ),
              child: user.isGuest
                  ? Icon(Icons.person_outline, size: 18, color: cs.onSurface)
                  : Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF18181B),
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, {required bool isSplit}) {
    final cs = Theme.of(context).colorScheme;
    const items = [
      ('nav_decide', 'Decide', Icons.auto_awesome_outlined, Icons.auto_awesome),
      ('nav_techniques', 'Techniques', Icons.menu_book_outlined, Icons.menu_book),
      ('nav_journal', 'Journal', Icons.fact_check_outlined, Icons.fact_check),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        child: Container(
          height: 68,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cs.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = _navIndex == i;
              final item = items[i];
              return Expanded(
                child: InkWell(
                  key: Key(item.$1),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() {
                    _navIndex = i;
                    if (!isSplit) _activeModelId = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: selected ? cs.primary.withOpacity(0.13) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? item.$4 : item.$3,
                          size: 20,
                          color: selected ? cs.primary : cs.onSurface.withOpacity(0.55),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? cs.onSurface : cs.onSurface.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabBody(BuildContext context, {required bool isSplit}) {
    if (_navIndex == 0) return _buildDecideTab(context);
    if (_navIndex == 1) return _buildTechniquesTab(context, isSplit: isSplit);
    return _buildJournalTab(context);
  }

  // ===========================================================================
  // TAB 1: MODE 1 — "TELL YOUR PROBLEM"
  // ===========================================================================
  Widget _buildDecideTab(BuildContext context) {
    final recs = _recommendations.isNotEmpty
        ? _recommendations
        : RecommenderService.suggestInstant(_problemCtrl.text, _scope);
    final best = recs.first;
    final alts = recs.skip(1).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroPrompt(context),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey('rec_${best.model.id}'),
              child: _buildBestMatchCard(context, best),
            ),
          ),
          if (alts.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildAlternativesCard(context, alts),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroPrompt(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final whiteBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
    );

    return Container(
      key: const Key('decide_hero_card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [UntangleTheme.heroStart, UntangleTheme.heroEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -30,
            top: -4,
            child: Opacity(
              opacity: 0.16,
              child: KnotMark(size: 96, color: UntangleTheme.goldDark, strokeWidth: 7),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting, style: UntangleTheme.eyebrow(UntangleTheme.goldDark)),
                const SizedBox(height: 6),
                Text(
                  'What are you trying\nto untangle?',
                  style: UntangleTheme.display(context, size: 25, color: UntangleTheme.paper),
                ),
                if (!widget.vault.hasUserCreatedItems) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Describe it in plain words — we\'ll pick the best of 52 models.',
                    key: const Key('onboarding_decide_hint'),
                    style: tt.bodySmall?.copyWith(color: Colors.white.withOpacity(0.62)),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  key: const Key('problem_input_field'),
                  controller: _problemCtrl,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: _onProblemChanged,
                  cursorColor: UntangleTheme.goldDark,
                  style: const TextStyle(color: UntangleTheme.paper, fontSize: 14, height: 1.4),
                  decoration: InputDecoration(
                    hintText: 'A dilemma, a crowded week, a team stuck in a loop…',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 13.5),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.07),
                    contentPadding: const EdgeInsets.all(13),
                    border: whiteBorder,
                    enabledBorder: whiteBorder,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: UntangleTheme.goldDark, width: 1.3),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PopupMenuButton<ProblemScope>(
                      key: const Key('scope_menu_btn'),
                      onSelected: (s) => setState(() {
                        _scope = s;
                        _recommendations = RecommenderService.suggestInstant(_problemCtrl.text, _scope);
                      }),
                      itemBuilder: (_) => ProblemScope.values
                          .map((s) => PopupMenuItem(
                                value: s,
                                child: Text(s.label, style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.filter_list, size: 14, color: Colors.white.withOpacity(0.8)),
                            const SizedBox(width: 5),
                            Text(
                              _scope.label,
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.88)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      key: const Key('toggle_examples_btn'),
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() => _showExamples = !_showExamples),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Text(
                          _showExamples ? 'Hide examples' : 'Try an example',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: UntangleTheme.goldDark,
                          ),
                        ),
                      ),
                    ),
                    if (_problemCtrl.text.isNotEmpty)
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          _problemCtrl.clear();
                          _onProblemChanged('');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text(
                            'Clear',
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                          ),
                        ),
                      ),
                  ],
                ),
                if (_showExamples) ...[
                  const SizedBox(height: 8),
                  for (final sample in RecommenderService.sampleDilemmas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          _problemCtrl.text = sample;
                          _showExamples = false;
                          _onProblemChanged(sample);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Text(
                            sample,
                            style: TextStyle(fontSize: 12.5, color: Colors.white.withOpacity(0.75), height: 1.35),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestMatchCard(BuildContext context, ModelRecommendation best) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final m = best.model;
    final sc = _sectionColor(m.section);

    return Card(
      key: const Key('primary_recommendation_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionMonogram(spec: m, size: 50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BEST MATCH', style: UntangleTheme.eyebrow(cs.primary)),
                      const SizedBox(height: 3),
                      Text(m.title, style: UntangleTheme.display(context, size: 18)),
                      const SizedBox(height: 2),
                      Text(m.subtitle, style: tt.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                QuestionMarkBadgeButton(
                  buttonKey: const Key('recommended_question_btn'),
                  onTap: () => showTechniqueInfoPopover(
                    context: context,
                    spec: m,
                    onSelectRelatedModel: (id) => _openTechnique(id, fromProblem: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.only(left: 11),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: sc, width: 2.5)),
              ),
              child: Text(
                best.fitReason,
                style: tt.bodyMedium?.copyWith(fontSize: 13, color: cs.onSurface.withOpacity(0.82)),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                MetaChip(icon: EngineMeta.icon(m.engine), label: EngineMeta.label(m.engine)),
                MetaChip(icon: Icons.schedule, label: '${m.minutes} min'),
                MetaChip(label: m.section.shortLabel, color: sc),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('use_recommended_btn'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _openTechnique(m.id, fromProblem: true),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Use this technique', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlternativesCard(BuildContext context, List<ModelRecommendation> alts) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Column(
        children: [
          InkWell(
            key: const Key('toggle_alternatives_btn'),
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _showAlternatives = !_showAlternatives),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              child: Row(
                children: [
                  Icon(Icons.alt_route, size: 16, color: cs.onSurface.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${alts.length} other angles on this problem',
                      style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.8)),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showAlternatives ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down, size: 18, color: cs.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ),
          if (_showAlternatives)
            for (final a in alts) ...[
              Divider(height: 1, color: cs.outline),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                child: Row(
                  children: [
                    SectionMonogram(spec: a.model, size: 36),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.model.title,
                            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(a.model.subtitle, style: tt.bodySmall, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    QuestionMarkBadgeButton(
                      onTap: () => showTechniqueInfoPopover(
                        context: context,
                        spec: a.model,
                        onSelectRelatedModel: (id) => _openTechnique(id, fromProblem: true),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Open',
                      onPressed: () => _openTechnique(a.model.id, fromProblem: true),
                      icon: Icon(Icons.arrow_forward, size: 18, color: cs.primary),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: MODE 2 — DIRECT 52-MODEL LIBRARY & PAGE-82 COMPASS
  // ===========================================================================
  Widget _buildTechniquesTab(BuildContext context, {required bool isSplit}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final q = _searchCtrl.text.trim().toLowerCase();

    final filtered = kDecisionBookModels.where((m) {
      if (_onlyBookmarked && !widget.vault.bookmarks.contains(m.id)) return false;
      if (_onlyQuick && m.minutes > 2) return false;
      if (_selectedSection != null && m.section != _selectedSection) return false;
      if (q.isEmpty) return true;
      return m.title.toLowerCase().contains(q) ||
          m.subtitle.toLowerCase().contains(q) ||
          m.keywords.any((k) => k.contains(q)) ||
          m.id.toString() == q;
    }).toList();

    final hasFilter = _onlyBookmarked || _onlyQuick;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('library_search_field'),
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search 52 techniques…',
                        fillColor: cs.surface,
                        prefixIcon: Icon(Icons.search, size: 18, color: cs.onSurface.withOpacity(0.55)),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => setState(() => _searchCtrl.clear()),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _squareToggle(
                    context,
                    key: const Key('library_filter_btn'),
                    icon: Icons.tune,
                    active: hasFilter || _showFilterRow,
                    onTap: () => setState(() => _showFilterRow = !_showFilterRow),
                  ),
                  const SizedBox(width: 6),
                  _squareToggle(
                    context,
                    key: const Key('library_compass_btn'),
                    icon: Icons.explore_outlined,
                    active: _compassMode,
                    onTap: () => setState(() => _compassMode = !_compassMode),
                  ),
                ],
              ),
              if (_showFilterRow) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilterChip(
                        label: Text('Bookmarked (${widget.vault.bookmarks.length})', style: const TextStyle(fontSize: 12)),
                        selected: _onlyBookmarked,
                        onSelected: (v) => setState(() => _onlyBookmarked = v),
                      ),
                      FilterChip(
                        label: const Text('Quick (≤2 min)', style: TextStyle(fontSize: 12)),
                        selected: _onlyQuick,
                        onSelected: (v) => setState(() => _onlyQuick = v),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  children: [
                    _sectionTab(context, null, 'All 52'),
                    for (final s in BookSection.values) _sectionTab(context, s, s.shortLabel),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: cs.outline),
        if (_selectedSection != null && !_compassMode)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: _sectionColor(_selectedSection!).withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${_selectedSection!.label}  ·  ${_selectedSection!.axisLabel}  ·  ${filtered.length} techniques',
              style: tt.bodySmall?.copyWith(color: _sectionColor(_selectedSection!), fontWeight: FontWeight.w600),
            ),
          ),
        Expanded(
          child: _compassMode
              ? _buildMetaCompass(context, filtered)
              : filtered.isEmpty
                  ? Center(child: Text('No techniques match your filter.', style: tt.bodySmall))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.only(left: 54),
                        child: Divider(height: 1, color: cs.outline),
                      ),
                      itemBuilder: (ctx, i) {
                        final m = filtered[i];
                        final isActive = isSplit && _activeModelId == m.id;
                        return InkWell(
                          key: Key('technique_row_${m.id}'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openTechnique(m.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                            decoration: BoxDecoration(
                              color: isActive ? cs.primary.withOpacity(0.07) : null,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                SectionMonogram(spec: m, size: 42),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.title,
                                        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      Row(
                                        children: [
                                          Icon(EngineMeta.icon(m.engine), size: 12, color: cs.onSurface.withOpacity(0.45)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              m.subtitle,
                                              style: tt.bodySmall,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                QuestionMarkBadgeButton(
                                  buttonKey: Key('row_info_btn_${m.id}'),
                                  onTap: () => showTechniqueInfoPopover(
                                    context: context,
                                    spec: m,
                                    onSelectRelatedModel: (id) => _openTechnique(id),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _squareToggle(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? cs.primary : cs.outline),
        ),
        child: Icon(icon, size: 18, color: active ? cs.onPrimary : cs.onSurface.withOpacity(0.75)),
      ),
    );
  }

  Widget _sectionTab(BuildContext context, BookSection? sec, String label) {
    final cs = Theme.of(context).colorScheme;
    final selected = _selectedSection == sec;
    final accent = sec == null ? cs.primary : _sectionColor(sec);
    return InkWell(
      onTap: () => setState(() => _selectedSection = sec),
      child: Container(
        margin: const EdgeInsets.only(right: 18),
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: selected ? accent : Colors.transparent, width: 2.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sec != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? cs.onSurface : cs.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaCompass(BuildContext context, List<DecisionModelSpec> list) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget quadrantLabel(BookSection s, Alignment a) => Align(
          alignment: a,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              s.label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _sectionColor(s).withOpacity(0.9)),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Card(
        key: const Key('page82_compass_card'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The Book Compass', style: UntangleTheme.display(context, size: 17)),
              const SizedBox(height: 2),
              Text('Me ↔ Others  ×  Doing ↔ Thinking — tap any number', style: tt.bodySmall),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, box) {
                    final hw = box.maxWidth / 2;
                    final hh = box.maxHeight / 2;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Positioned(left: 0, top: 0, width: hw, height: hh, child: Container(color: _sectionColor(BookSection.improveSelf).withOpacity(0.09))),
                          Positioned(left: hw, top: 0, width: hw, height: hh, child: Container(color: _sectionColor(BookSection.understandSelf).withOpacity(0.09))),
                          Positioned(left: 0, top: hh, width: hw, height: hh, child: Container(color: _sectionColor(BookSection.improveOthers).withOpacity(0.09))),
                          Positioned(left: hw, top: hh, width: hw, height: hh, child: Container(color: _sectionColor(BookSection.understandOthers).withOpacity(0.09))),
                          Positioned(left: hw, top: 0, bottom: 0, child: Container(width: 1, color: cs.outline)),
                          Positioned(top: hh, left: 0, right: 0, child: Container(height: 1, color: cs.outline)),
                          quadrantLabel(BookSection.improveSelf, Alignment.topLeft),
                          quadrantLabel(BookSection.understandSelf, Alignment.topRight),
                          quadrantLabel(BookSection.improveOthers, Alignment.bottomLeft),
                          quadrantLabel(BookSection.understandOthers, Alignment.bottomRight),
                          for (final m in list)
                            Positioned(
                              left: ((m.compassX / 100.0) * (box.maxWidth - 26)).clamp(4.0, box.maxWidth - 26),
                              top: ((m.compassY / 100.0) * (box.maxHeight - 26)).clamp(22.0, box.maxHeight - 26),
                              child: InkWell(
                                key: Key('compass_dot_${m.id}'),
                                customBorder: const CircleBorder(),
                                onTap: () => _openTechnique(m.id),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _sectionColor(m.section),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: cs.surface, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: Text(
                                    '${m.id}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: JOURNAL & REAL-CALENDAR SUPERMEMO CATCH-UP
  // ===========================================================================
  Widget _buildJournalTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final decisions = widget.vault.decisions;
    final due = widget.vault.dueReviews(_now);

    if (decisions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(opacity: 0.5, child: KnotMark(size: 40, color: cs.primary, strokeWidth: 3.2)),
              const SizedBox(height: 14),
              Text('Nothing tangled yet', style: UntangleTheme.display(context, size: 19)),
              const SizedBox(height: 6),
              Text(
                'Decisions you save land here, with gentle spaced reviews so the lessons stick.',
                style: tt.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
      children: [
        if (due.isNotEmpty) ...[
          Container(
            key: const Key('supermemo_catchup_banner'),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [UntangleTheme.heroStart, UntangleTheme.heroEnd],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology_alt_outlined, color: UntangleTheme.goldDark, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${due.length} review${due.length == 1 ? '' : 's'} due',
                        style: UntangleTheme.display(context, size: 16, color: UntangleTheme.paper),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Revisit past calls before the lesson fades.',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.65)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('catchup_all_reviews_btn'),
                  style: FilledButton.styleFrom(
                    backgroundColor: UntangleTheme.goldDark,
                    foregroundColor: const Color(0xFF18181B),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => widget.vault.catchUpAllOverdueReviews(realToday: _now),
                  child: const Text('Catch up', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        for (final d in decisions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildJournalCard(context, d),
          ),
      ],
    );
  }

  Widget _buildJournalCard(BuildContext context, SavedDecision d) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final spec = modelById(d.modelId);
    final sc = _sectionColor(spec.section);
    final isDue = d.isReviewDueOn(_now);

    return Card(
      key: Key('saved_decision_${d.id}'),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: sc),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                spec.title.toUpperCase(),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sc),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(d.title, style: UntangleTheme.display(context, size: 16)),
                            ],
                          ),
                        ),
                        InkWell(
                          key: Key('delete_decision_${d.id}'),
                          customBorder: const CircleBorder(),
                          onTap: () => widget.vault.deleteDecision(d.id),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.close, size: 16, color: cs.onSurface.withOpacity(0.45)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(d.verdict, style: tt.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.78))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ReviewStageDots(stage: d.reviewStage, color: sc),
                        const SizedBox(width: 6),
                        Expanded(
                          child: isDue
                              ? InkWell(
                                  key: Key('review_checkin_${d.id}'),
                                  onTap: () => widget.vault.completeReviewCatchUp(d.id, realToday: _now),
                                  child: Text(
                                    'Review now',
                                    style: tt.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
                                  ),
                                )
                              : Text('Next review ${d.nextReviewDateIso}', style: tt.bodySmall, overflow: TextOverflow.ellipsis),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () => _openTechnique(d.modelId, savedMap: d.workspaceMap),
                          child: const Text('Open', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
