import '../data/decision_book_catalog.dart';
import '../models/decision_model.dart';
import 'gcp_backend_service.dart';

enum ProblemScope {
  all('Any context'),
  personal('Personal'),
  team('Team & Others'),
  quick('Quick (≤2m)');

  final String label;
  const ProblemScope(this.label);
}

class ModelRecommendation {
  final DecisionModelSpec model;
  final String fitReason;
  final String source; // 'tier1' | 'tier2' | 'gemini-2.5-flash-lite'

  const ModelRecommendation({
    required this.model,
    required this.fitReason,
    this.source = 'tier2',
  });
}

class RecommenderService {
  static const List<String> sampleDilemmas = [
    'I have two strong job offers—stay with my current team or join an early startup.',
    'I am overwhelmed by urgent daily tasks and neglecting strategic long-term work.',
    'Two teammates disagree on direction and our discussions keep stalling.',
    'We want to test whether our new product idea fills a real gap in the market.',
  ];

  /// Tier 1 (0ms explicit) + Tier 2 (<2ms deterministic facet scorer)
  static List<ModelRecommendation> suggestInstant(String rawInput, ProblemScope scope) {
    final q = rawInput.trim().toLowerCase();
    if (q.isEmpty) {
      return [
        ModelRecommendation(
          model: modelById(6),
          fitReason: 'Ideal starting lens when weighing two attractive options.',
          source: 'tier1',
        ),
        ModelRecommendation(
          model: modelById(1),
          fitReason: 'Separates urgent daily noise from important priorities.',
          source: 'tier1',
        ),
        ModelRecommendation(
          model: modelById(13),
          fitReason: 'Maps six distinct roads ahead at a life or career crossroads.',
          source: 'tier1',
        ),
      ];
    }

    final scored = <_Scored>[];
    for (final m in kDecisionBookModels) {
      double s = 0;
      final cleanTitle = m.title.toLowerCase().replaceFirst('the ', '');
      if (q.contains(cleanTitle)) {
        s += 35; // Tier 1 explicit shorthand match
      }
      for (final kw in m.keywords) {
        if (q.contains(kw)) s += 8;
      }

      if (RegExp(r'\b(two|offer|offers|versus|vs|stay or|quit|move|berlin|torn|dilemma|either)\b').hasMatch(q) &&
          const [6, 24, 13, 2].contains(m.id)) {
        s += 16;
      }
      // Binary "A vs B" / "stay or join" choices are the Rubber Band model's home turf
      final isBinaryChoice = RegExp(r'\b(vs|versus)\b').hasMatch(q) ||
          q.contains('torn between') ||
          (RegExp(r'\b(stay|keep|remain)\b').hasMatch(q) &&
              RegExp(r'\b(or|join|leave|move|switch)\b').hasMatch(q));
      if (isBinaryChoice && m.id == 6) {
        s += 14;
      }
      if (RegExp(r'\b(urgent|busy|overwhelm|overwhelmed|tasks|todo|time|focus|priorit)\w*').hasMatch(q) &&
          const [1, 38, 51, 4].contains(m.id)) {
        s += 17;
      }
      if (RegExp(r'\b(job|career|unhappy|resign|role|promotion)\b').hasMatch(q) &&
          const [24, 6, 13, 14].contains(m.id)) {
        s += 14;
      }
      if (RegExp(r'\b(team|teammate|teammates|employee|manage|delegate|group|hire|morale)\b').hasMatch(q) &&
          const [46, 49, 47, 50, 36].contains(m.id)) {
        s += 16;
      }
      if (RegExp(r'\b(conflict|argue|disagree|fight|angry|negotiate|trust|stalling)\b').hasMatch(q) &&
          const [12, 45, 36, 7].contains(m.id)) {
        s += 16;
      }
      if (RegExp(r'\b(idea|creative|brainstorm|launch|startup|product|market|niche|gap)\b').hasMatch(q) &&
          const [48, 9, 33, 42, 2].contains(m.id)) {
        s += 15;
      }
      if (RegExp(r'\b(mistake|bug|error|fail|repeat|incident)\b').hasMatch(q) &&
          const [31, 35, 51].contains(m.id)) {
        s += 17;
      }
      if (RegExp(r'\b(risk|uncertain|forecast|budget|estimate|odds|monte)\b').hasMatch(q) &&
          const [40, 41, 11].contains(m.id)) {
        s += 16;
      }
      if (RegExp(r'\b(gift|present|spend|anniversary|wedding)\b').hasMatch(q) && m.id == 10) {
        s += 38;
      }
      if (RegExp(r'\b(remember|forget|study|memory)\b').hasMatch(q) && m.id == 22) {
        s += 34;
      }

      if (scope == ProblemScope.personal &&
          m.section != BookSection.improveSelf &&
          m.section != BookSection.understandSelf) {
        s -= 10;
      } else if (scope == ProblemScope.team &&
          m.section != BookSection.understandOthers &&
          m.section != BookSection.improveOthers) {
        s -= 10;
      } else if (scope == ProblemScope.quick && m.minutes > 2) {
        s -= 8;
      }

      scored.add(_Scored(m, s));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(3).toList().asMap().entries.map((entry) {
      final m = entry.value.model;
      final isFirst = entry.key == 0;
      return ModelRecommendation(
        model: m,
        fitReason: isFirst
            ? 'Directly structures your situation (${m.subtitle.toLowerCase()}) in ~${m.minutes} min.'
            : 'Complementary angle: ${m.subtitle.toLowerCase()}.',
        source: entry.value.score >= 35 ? 'tier1' : 'tier2',
      );
    }).toList();
  }

  /// Tier 3 ($0.00 Cloud Run proxy to free-tier gemini-2.5-flash-lite for >=10 words, 2.8s timeout)
  static Future<List<ModelRecommendation>> suggestHybrid(
    String rawInput,
    ProblemScope scope,
    GcpBackendService backend,
  ) async {
    final local = suggestInstant(rawInput, scope);
    final wordCount = rawInput.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (wordCount < 10) return local;

    final cloud = await backend.aiSuggestModels(rawInput);
    if (cloud == null || cloud.modelIds.isEmpty) return local;

    final seen = <int>{};
    final merged = <ModelRecommendation>[];
    for (int i = 0; i < cloud.modelIds.length; i++) {
      final id = cloud.modelIds[i];
      if (id >= 1 && id <= 52 && seen.add(id)) {
        final spec = modelById(id);
        merged.add(
          ModelRecommendation(
            model: spec,
            fitReason: i == 0 && cloud.fitReason.isNotEmpty
                ? cloud.fitReason
                : 'Complementary angle: ${spec.subtitle.toLowerCase()}.',
            source: cloud.source,
          ),
        );
      }
    }
    for (final fallback in local) {
      if (merged.length >= 3) break;
      if (seen.add(fallback.model.id)) merged.add(fallback);
    }
    return merged.take(3).toList();
  }

  /// Pre-fills workspace data from user's natural-language problem (zero-retype handoff)
  static DecisionWorkspaceData seedWorkspaceFromProblem(DecisionModelSpec spec, String problemText) {
    final trimmed = problemText.trim();
    if (trimmed.isEmpty) {
      return DecisionWorkspaceData.fromSpec(spec, loadSample: true);
    }
    final shortTitle = trimmed.length > 72 ? '${trimmed.substring(0, 69)}...' : trimmed;
    final ws = DecisionWorkspaceData.fromSpec(spec, loadSample: true, initialTopic: shortTitle);

    final parts = trimmed
        .split(RegExp(r'\b(?:vs\.?|versus|or)\b|[—;,]', caseSensitive: false))
        .map((s) => s.trim())
        .where((s) => s.length >= 4)
        .toList();

    if (spec.engine == CanvasEngine.e2Force && parts.length >= 2) {
      ws.leftItems = [WeightedForce(text: parts[0], weight: 4)];
      ws.rightItems = [WeightedForce(text: parts[1], weight: 4)];
    } else if (spec.engine == CanvasEngine.e1Quadrant && parts.isNotEmpty) {
      ws.quadItems = [
        QuadrantEntry(text: parts.first, quadrant: 0),
        ...ws.quadItems.take(3),
      ];
    }
    return ws;
  }
}

class _Scored {
  final DecisionModelSpec model;
  final double score;
  const _Scored(this.model, this.score);
}
