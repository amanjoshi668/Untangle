import 'dart:math' as math;

enum BookSection {
  improveSelf('Improve Yourself', 'Improve Self', 'Me · Doing'),
  understandSelf('Understand Yourself', 'Know Self', 'Me · Thinking'),
  understandOthers('Understand Others', 'Know Others', 'Others · Thinking'),
  improveOthers('Improve Others', 'Lead Others', 'Others · Doing');

  final String label;
  final String shortLabel;
  final String axisLabel;
  const BookSection(this.label, this.shortLabel, this.axisLabel);
}

enum CanvasEngine {
  e1Quadrant,
  e2Force,
  e3SlidersSvg,
  e4Diagnostic,
  e5Combinator,
  e6TimelineCurve,
  e7Network,
  e8SimCustom,
}

class QuadrantEntry {
  String text;
  int quadrant; // 0..3

  QuadrantEntry({required this.text, required this.quadrant});

  Map<String, dynamic> toMap() => {'text': text, 'quadrant': quadrant};

  factory QuadrantEntry.fromMap(Map<String, dynamic> m) => QuadrantEntry(
        text: (m['text'] ?? m['t'] ?? '').toString(),
        quadrant: ((m['quadrant'] ?? m['q'] ?? 0) as num).toInt().clamp(0, 3),
      );
}

class WeightedForce {
  String text;
  int weight; // 1..5

  WeightedForce({required this.text, this.weight = 3});

  Map<String, dynamic> toMap() => {'text': text, 'weight': weight};

  factory WeightedForce.fromMap(Map<String, dynamic> m) => WeightedForce(
        text: (m['text'] ?? m['t'] ?? '').toString(),
        weight: ((m['weight'] ?? m['w'] ?? 3) as num).toInt().clamp(1, 5),
      );
}

class MorphRowSpec {
  final String parameter;
  final List<String> options;
  final int defaultSelected;

  const MorphRowSpec({
    required this.parameter,
    required this.options,
    this.defaultSelected = 0,
  });
}

class NetworkNodeEntry {
  String name;
  String relation;
  String badge;

  NetworkNodeEntry({
    required this.name,
    this.relation = 'Direct',
    this.badge = 'Weekly',
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'relation': relation,
        'badge': badge,
      };

  factory NetworkNodeEntry.fromMap(Map<String, dynamic> m) => NetworkNodeEntry(
        name: (m['name'] ?? '').toString(),
        relation: (m['relation'] ?? 'Direct').toString(),
        badge: (m['badge'] ?? 'Weekly').toString(),
      );
}

class DecisionModelSpec {
  final int id;
  final String title;
  final String subtitle;
  final BookSection section;
  final CanvasEngine engine;
  final String subtype;
  final int minutes;
  final double compassX; // 0..100
  final double compassY; // 0..100
  final List<String> keywords;
  final String writeup;
  final String howTo;
  final String quote;
  final List<int> seeAlso;

  // Engine defaults
  final List<String> quadrants;
  final List<String> quadrantHints;
  final List<QuadrantEntry> sampleQuadrants;
  final String leftLabel;
  final String rightLabel;
  final List<WeightedForce> sampleLeft;
  final List<WeightedForce> sampleRight;
  final List<String> checklistItems;
  final bool singleStageMode;
  final List<MorphRowSpec> morphRows;
  final List<NetworkNodeEntry> sampleNodes;
  final List<String> sampleChain;

  const DecisionModelSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.section,
    required this.engine,
    this.subtype = '',
    required this.minutes,
    required this.compassX,
    required this.compassY,
    required this.keywords,
    required this.writeup,
    required this.howTo,
    required this.quote,
    this.seeAlso = const [],
    this.quadrants = const ['Quadrant 1', 'Quadrant 2', 'Quadrant 3', 'Quadrant 4'],
    this.quadrantHints = const ['', '', '', ''],
    this.sampleQuadrants = const [],
    this.leftLabel = 'Anchors',
    this.rightLabel = 'Pull Factors',
    this.sampleLeft = const [],
    this.sampleRight = const [],
    this.checklistItems = const [],
    this.singleStageMode = false,
    this.morphRows = const [],
    this.sampleNodes = const [],
    this.sampleChain = const ['You', 'Trusted Contact', 'Connector', 'Target Person'],
  });
}

class MonteCarloSummary {
  final int p10;
  final int p50;
  final int p90;
  final List<double> bins; // normalized 0..1 histogram

  const MonteCarloSummary({
    required this.p10,
    required this.p50,
    required this.p90,
    required this.bins,
  });

  static MonteCarloSummary simulate(double minVal, double likelyVal, double maxVal, {int seed = 42}) {
    final lo = math.min(minVal, math.min(likelyVal, maxVal));
    final hi = math.max(minVal, math.max(likelyVal, maxVal));
    final span = math.max(hi - lo, 1.0);
    final mid = likelyVal.clamp(lo, hi);
    final f = (mid - lo) / span;
    final rng = math.Random(seed);
    final samples = <double>[];
    for (int i = 0; i < 1000; i++) {
      final u = rng.nextDouble();
      final v = u < f
          ? lo + math.sqrt(u * span * math.max(mid - lo, 0.001))
          : hi - math.sqrt((1 - u) * span * math.max(hi - mid, 0.001));
      samples.add(v);
    }
    samples.sort();
    final rawBins = List<int>.filled(14, 0);
    final sMin = samples.first;
    final sMax = math.max(samples.last, sMin + 1.0);
    for (final s in samples) {
      final idx = (((s - sMin) / (sMax - sMin)) * 14).floor().clamp(0, 13);
      rawBins[idx]++;
    }
    final peak = math.max(rawBins.reduce(math.max), 1);
    return MonteCarloSummary(
      p10: samples[100].round(),
      p50: samples[500].round(),
      p90: samples[900].round(),
      bins: rawBins.map((c) => c / peak).toList(),
    );
  }
}

class DecisionWorkspaceData {
  String topic;
  List<QuadrantEntry> quadItems;
  int targetQuadrant;
  List<WeightedForce> leftItems;
  List<WeightedForce> rightItems;
  double s1;
  double s2;
  double s3;
  double pastPct;
  double futurePct;
  List<bool> checks;
  int stageIndex;
  List<int> morphSelection;
  int hatIndex;
  List<String> hatNotes;
  bool puzzleSolved;
  String brokenRule;
  String giftRelation;
  double giftYears;
  bool giftMilestone;
  double knowPct;
  double impactPct;
  List<double> roadScores;
  String memoText;
  double hoursTotal;
  String guidingPrinciple;
  List<NetworkNodeEntry> nodes;
  List<String> chainSteps;
  String swanAssumption;
  String swanBuffer;
  double mcMin;
  double mcLikely;
  double mcMax;
  int mcSeed;
  String customTitle;
  List<String> customQuadrants;

  DecisionWorkspaceData({
    required this.topic,
    required this.quadItems,
    this.targetQuadrant = 0,
    required this.leftItems,
    required this.rightItems,
    this.s1 = 7,
    this.s2 = 7,
    this.s3 = 5,
    this.pastPct = 20,
    this.futurePct = 30,
    required this.checks,
    this.stageIndex = 1,
    required this.morphSelection,
    this.hatIndex = 0,
    required this.hatNotes,
    this.puzzleSolved = false,
    this.brokenRule = 'Assuming everything must happen on Day 1 instead of a small pilot.',
    this.giftRelation = 'Partner',
    this.giftYears = 5,
    this.giftMilestone = true,
    this.knowPct = 35,
    this.impactPct = 80,
    required this.roadScores,
    this.memoText = 'Protect uninterrupted morning blocks for important, non-urgent work.',
    this.hoursTotal = 12,
    this.guidingPrinciple = 'Question the deeper rule driving repeated friction.',
    required this.nodes,
    required this.chainSteps,
    this.swanAssumption = 'Assuming a single channel will remain stable indefinitely.',
    this.swanBuffer = 'Offline-capable foundation + diversified organic channels.',
    this.mcMin = 45,
    this.mcLikely = 80,
    this.mcMax = 140,
    this.mcSeed = 42,
    this.customTitle = 'Energy vs. Reversibility Matrix',
    required this.customQuadrants,
  });

  factory DecisionWorkspaceData.fromSpec(DecisionModelSpec spec, {bool loadSample = true, String? initialTopic}) {
    return DecisionWorkspaceData(
      topic: (initialTopic != null && initialTopic.trim().isNotEmpty)
          ? initialTopic.trim()
          : spec.title,
      quadItems: loadSample
          ? spec.sampleQuadrants.map((e) => QuadrantEntry(text: e.text, quadrant: e.quadrant)).toList()
          : <QuadrantEntry>[],
      leftItems: loadSample
          ? (spec.sampleLeft.isNotEmpty
              ? spec.sampleLeft.map((e) => WeightedForce(text: e.text, weight: e.weight)).toList()
              : [WeightedForce(text: 'Current stability & familiarity', weight: 3)])
          : <WeightedForce>[],
      rightItems: loadSample
          ? (spec.sampleRight.isNotEmpty
              ? spec.sampleRight.map((e) => WeightedForce(text: e.text, weight: e.weight)).toList()
              : [WeightedForce(text: 'Long-term growth & autonomy', weight: 4)])
          : <WeightedForce>[],
      checks: List<bool>.generate(
        spec.checklistItems.length,
        (i) => loadSample && i < (spec.checklistItems.length / 2).ceil(),
      ),
      morphSelection: spec.morphRows.map((r) => r.defaultSelected).toList(),
      hatNotes: loadSample
          ? [
              '18 months cash runway and validated early customer demand.',
              'Energized and curious, with natural transition nerves.',
              'Transition overhead and early execution uncertainty.',
              'Opportunity to shape direction and compound learning.',
              'Run a focused 2-week trial sprint before full commitment.',
              'Complete due diligence by Friday and commit cleanly.',
            ]
          : List<String>.filled(6, ''),
      roadScores: [8, 9, 6, 7, 5, 3],
      nodes: loadSample
          ? spec.sampleNodes
              .map((n) => NetworkNodeEntry(name: n.name, relation: n.relation, badge: n.badge))
              .toList()
          : <NetworkNodeEntry>[],
      chainSteps: List<String>.from(spec.sampleChain),
      customQuadrants: [
        'Reversible & Energizing',
        'Irreversible & Energizing',
        'Reversible & Draining',
        'Irreversible & Draining',
      ],
    );
  }

  String computeTakeaway(DecisionModelSpec spec) {
    switch (spec.engine) {
      case CanvasEngine.e1Quadrant:
        final counts = List<int>.generate(4, (q) => quadItems.where((x) => x.quadrant == q).length);
        if (spec.id == 1) {
          final urgent = quadItems.where((x) => x.quadrant == 1).toList();
          if (urgent.isNotEmpty) {
            return 'Start immediately with "${urgent.first.text}", then block focused time for your ${counts[0]} scheduled strategic item(s).';
          }
          return 'Zero urgent crises—protect deep focus for your ${counts[0]} important, non-urgent priority item(s).';
        }
        int bestIdx = 0;
        for (int i = 1; i < 4; i++) {
          if (counts[i] > counts[bestIdx]) bestIdx = i;
        }
        return 'Most entries cluster in "${spec.quadrants[bestIdx]}" (${counts[bestIdx]}). Check quieter quadrants for overlooked blind spots.';

      case CanvasEngine.e2Force:
        final lSum = leftItems.fold<int>(0, (s, x) => s + x.weight);
        final rSum = rightItems.fold<int>(0, (s, x) => s + x.weight);
        if ((rSum - lSum).abs() <= 1) {
          return 'Forces are closely balanced ($lSum vs. $rSum). Run a small, reversible test before locking an irreversible move.';
        }
        return rSum > lSum
            ? '${spec.rightLabel} leads ($rSum vs. $lSum). Mitigate your top left-side concern and move forward with clarity.'
            : '${spec.leftLabel} carries greater weight ($lSum vs. $rSum). Hold steady until stronger pull factors emerge.';

      case CanvasEngine.e3SlidersSvg:
        if (spec.subtype == 'flow') {
          if (s1 - s2 >= 3) {
            return 'Challenge (${s1.round()}) outpaces Skill (${s2.round()}) — narrow scope or add mentorship to prevent burnout.';
          }
          if (s2 - s1 >= 3) {
            return 'Skill (${s2.round()}) exceeds Challenge (${s1.round()}) — raise ambition to re-enter the Flow channel.';
          }
          return 'Balanced inside the Flow zone (${s1.round()}/10 vs. ${s2.round()}/10). Protect distraction-free focus blocks.';
        }
        if (spec.subtype == 'energy') {
          final nowPct = math.max(0, (100 - pastPct - futurePct).round());
          if (futurePct >= 50) return 'Future-heavy focus (${futurePct.round()}%) — anchor one concrete step in today\'s $nowPct% present window.';
          if (pastPct >= 45) return 'Memory-heavy focus (${pastPct.round()}%) — carry key lessons forward into a fresh experiment.';
          return 'Present-centered balance ($nowPct% Here & Now) with healthy perspective.';
        }
        if (spec.subtype == 'sail' && s1 >= 8 && s3 <= 4) {
          return 'High obligation (${s1.round()}/10) with low desire (${s3.round()}/10) — strong signal to reshape scope or explore a role change.';
        }
        return 'Profile captured (${s1.round()}, ${s2.round()}, ${s3.round()}/10). Reinforce any axis sitting below 6/10.';

      case CanvasEngine.e4Diagnostic:
        if (spec.singleStageMode && spec.checklistItems.isNotEmpty) {
          final safeIdx = stageIndex.clamp(0, spec.checklistItems.length - 1);
          return 'Current stage: ${spec.checklistItems[safeIdx]}. Resolve this step cleanly rather than skipping ahead.';
        }
        final verified = checks.where((c) => c).length;
        return '$verified of ${spec.checklistItems.length} checks verified. Strengthen any unchecked line before committing.';

      case CanvasEngine.e5Combinator:
        if (spec.subtype == 'sixhats') {
          final synthesis = hatNotes.length > 5 && hatNotes[5].trim().isNotEmpty
              ? hatNotes[5].trim()
              : 'Capture one crisp line under each hat to lock an ego-free next step.';
          return 'Blue-Hat Synthesis: $synthesis';
        }
        if (spec.subtype == 'ninedot') {
          return 'Assumption to drop: "$brokenRule"';
        }
        final parts = <String>[];
        for (int i = 0; i < spec.morphRows.length; i++) {
          final row = spec.morphRows[i];
          final sel = (i < morphSelection.length ? morphSelection[i] : 0).clamp(0, row.options.length - 1);
          parts.add(row.options[sel]);
        }
        return 'Combined configuration: ${parts.join(' · ')}.';

      case CanvasEngine.e6TimelineCurve:
        if (spec.subtype == 'gift') {
          final mult = {'Partner': 35, 'Family': 22, 'Friend': 15, 'Colleague': 8, 'Host': 5}[giftRelation] ?? 15;
          final lo = (25 + giftYears * mult * (giftMilestone ? 1.5 : 1.0)).round();
          return 'Generosity sweet-spot for $giftRelation (${giftYears.round()} yrs): \$$lo – \$${(lo * 1.3).round()}.';
        }
        if (spec.subtype == 'threeloop') {
          final unit = (hoursTotal / 3.0).toStringAsFixed(1);
          return 'Three equal loops of $unit units ensure you complete Draft, Refinement, and Optimisation calmly.';
        }
        if (spec.subtype == 'crossroads') {
          const roadNames = [
            '1. The Beckoning Road',
            '2. Wildest Dream Road',
            '3. The Sensible Road',
            '4. Road Not Travelled',
            '5. The Familiar Road',
            '6. The Safe Road Back',
          ];
          int topIdx = 0;
          for (int i = 1; i < roadScores.length; i++) {
            if (roadScores[i] > roadScores[topIdx]) topIdx = i;
          }
          return 'Strongest pull (${roadScores[topIdx].round()}/10): ${roadNames[topIdx]}. Define one small step down that path this week.';
        }
        if (spec.subtype == 'supermemo') {
          return 'Spaced recall intervals set for Day 1, Day 10, Day 30, and Day 60.';
        }
        return 'Knowledge (${knowPct.round()}%) vs. Impact (${impactPct.round()}%) logged — commit to a clear decision checkpoint.';

      case CanvasEngine.e7Network:
        if (spec.subtype == 'chain') {
          return 'Warm path mapped across ${math.max(chainSteps.length - 1, 1)} hops — reach out to "${chainSteps.length > 1 ? chainSteps[1] : 'your first contact'}" first.';
        }
        if (spec.subtype == 'tree' || spec.subtype == 'bullseye') {
          return '${nodes.length} key relationships mapped — nurture high-trust promoters and diversify single-branch dependencies.';
        }
        return 'Resilience safeguard defined: "$swanBuffer"';

      case CanvasEngine.e8SimCustom:
        if (spec.subtype == 'montecarlo') {
          final sim = MonteCarloSummary.simulate(mcMin, mcLikely, mcMax, seed: mcSeed);
          return '80% confidence band spans ${sim.p10} to ${sim.p90} (median ${sim.p50}). Plan around ${sim.p10} for a calm safety margin.';
        }
        return 'Custom framework "$customTitle" configured and ready for reuse.';
    }
  }

  Map<String, dynamic> toMap() => {
        'topic': topic,
        'quadItems': quadItems.map((e) => e.toMap()).toList(),
        'targetQuadrant': targetQuadrant,
        'leftItems': leftItems.map((e) => e.toMap()).toList(),
        'rightItems': rightItems.map((e) => e.toMap()).toList(),
        's1': s1,
        's2': s2,
        's3': s3,
        'pastPct': pastPct,
        'futurePct': futurePct,
        'checks': checks,
        'stageIndex': stageIndex,
        'morphSelection': morphSelection,
        'hatIndex': hatIndex,
        'hatNotes': hatNotes,
        'puzzleSolved': puzzleSolved,
        'brokenRule': brokenRule,
        'giftRelation': giftRelation,
        'giftYears': giftYears,
        'giftMilestone': giftMilestone,
        'knowPct': knowPct,
        'impactPct': impactPct,
        'roadScores': roadScores,
        'memoText': memoText,
        'hoursTotal': hoursTotal,
        'guidingPrinciple': guidingPrinciple,
        'nodes': nodes.map((e) => e.toMap()).toList(),
        'chainSteps': chainSteps,
        'swanAssumption': swanAssumption,
        'swanBuffer': swanBuffer,
        'mcMin': mcMin,
        'mcLikely': mcLikely,
        'mcMax': mcMax,
        'mcSeed': mcSeed,
        'customTitle': customTitle,
        'customQuadrants': customQuadrants,
      };

  factory DecisionWorkspaceData.fromMap(Map<String, dynamic> m, DecisionModelSpec spec) {
    final base = DecisionWorkspaceData.fromSpec(spec, loadSample: false);
    return DecisionWorkspaceData(
      topic: (m['topic'] ?? spec.title).toString(),
      quadItems: (m['quadItems'] as List?)
              ?.map((e) => QuadrantEntry.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          base.quadItems,
      targetQuadrant: ((m['targetQuadrant'] ?? 0) as num).toInt(),
      leftItems: (m['leftItems'] as List?)
              ?.map((e) => WeightedForce.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          base.leftItems,
      rightItems: (m['rightItems'] as List?)
              ?.map((e) => WeightedForce.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          base.rightItems,
      s1: ((m['s1'] ?? 7) as num).toDouble(),
      s2: ((m['s2'] ?? 7) as num).toDouble(),
      s3: ((m['s3'] ?? 5) as num).toDouble(),
      pastPct: ((m['pastPct'] ?? 20) as num).toDouble(),
      futurePct: ((m['futurePct'] ?? 30) as num).toDouble(),
      checks: (m['checks'] as List?)?.map((e) => e == true).toList() ?? base.checks,
      stageIndex: ((m['stageIndex'] ?? 1) as num).toInt(),
      morphSelection: (m['morphSelection'] as List?)?.map((e) => (e as num).toInt()).toList() ?? base.morphSelection,
      hatIndex: ((m['hatIndex'] ?? 0) as num).toInt(),
      hatNotes: (m['hatNotes'] as List?)?.map((e) => e.toString()).toList() ?? base.hatNotes,
      puzzleSolved: m['puzzleSolved'] == true,
      brokenRule: (m['brokenRule'] ?? base.brokenRule).toString(),
      giftRelation: (m['giftRelation'] ?? base.giftRelation).toString(),
      giftYears: ((m['giftYears'] ?? 5) as num).toDouble(),
      giftMilestone: m['giftMilestone'] != false,
      knowPct: ((m['knowPct'] ?? 35) as num).toDouble(),
      impactPct: ((m['impactPct'] ?? 80) as num).toDouble(),
      roadScores: (m['roadScores'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? base.roadScores,
      memoText: (m['memoText'] ?? base.memoText).toString(),
      hoursTotal: ((m['hoursTotal'] ?? 12) as num).toDouble(),
      guidingPrinciple: (m['guidingPrinciple'] ?? base.guidingPrinciple).toString(),
      nodes: (m['nodes'] as List?)
              ?.map((e) => NetworkNodeEntry.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          base.nodes,
      chainSteps: (m['chainSteps'] as List?)?.map((e) => e.toString()).toList() ?? base.chainSteps,
      swanAssumption: (m['swanAssumption'] ?? base.swanAssumption).toString(),
      swanBuffer: (m['swanBuffer'] ?? base.swanBuffer).toString(),
      mcMin: ((m['mcMin'] ?? 45) as num).toDouble(),
      mcLikely: ((m['mcLikely'] ?? 80) as num).toDouble(),
      mcMax: ((m['mcMax'] ?? 140) as num).toDouble(),
      mcSeed: ((m['mcSeed'] ?? 42) as num).toInt(),
      customTitle: (m['customTitle'] ?? base.customTitle).toString(),
      customQuadrants: (m['customQuadrants'] as List?)?.map((e) => e.toString()).toList() ?? base.customQuadrants,
    );
  }
}

class SavedDecision {
  final String id;
  final int modelId;
  final String title;
  final String verdict;
  final String createdAtIso;
  final String nextReviewDateIso; // YYYY-MM-DD for SuperMemo real-calendar resilience
  final int reviewStage; // 0->1d, 1->10d, 2->30d, 3->60d, 4->complete
  final bool seeded;
  final Map<String, dynamic> workspaceMap;

  const SavedDecision({
    required this.id,
    required this.modelId,
    required this.title,
    required this.verdict,
    required this.createdAtIso,
    required this.nextReviewDateIso,
    this.reviewStage = 0,
    this.seeded = false,
    required this.workspaceMap,
  });

  bool isReviewDueOn(DateTime now) {
    if (reviewStage >= 4) return false;
    final todayStr = _dateOnly(now);
    return nextReviewDateIso.compareTo(todayStr) <= 0;
  }

  SavedDecision advanceSuperMemo(DateTime realToday) {
    const intervals = [1, 10, 30, 60];
    final nextStage = (reviewStage + 1).clamp(0, 4);
    final daysToAdd = nextStage < 4 ? intervals[nextStage] : 90;
    final targetDate = DateTime(realToday.year, realToday.month, realToday.day).add(Duration(days: daysToAdd));
    return SavedDecision(
      id: id,
      modelId: modelId,
      title: title,
      verdict: verdict,
      createdAtIso: createdAtIso,
      nextReviewDateIso: _dateOnly(targetDate),
      reviewStage: nextStage,
      seeded: seeded,
      workspaceMap: workspaceMap,
    );
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        'id': id,
        'modelId': modelId,
        'title': title,
        'verdict': verdict,
        'createdAtIso': createdAtIso,
        'nextReviewDateIso': nextReviewDateIso,
        'reviewStage': reviewStage,
        'seeded': seeded,
        'workspaceMap': workspaceMap,
      };

  factory SavedDecision.fromMap(Map<String, dynamic> m) => SavedDecision(
        id: (m['id'] ?? '').toString(),
        modelId: ((m['modelId'] ?? 6) as num).toInt(),
        title: (m['title'] ?? 'Decision').toString(),
        verdict: (m['verdict'] ?? '').toString(),
        createdAtIso: (m['createdAtIso'] ?? DateTime.now().toIso8601String()).toString(),
        nextReviewDateIso: (m['nextReviewDateIso'] ?? _dateOnly(DateTime.now())).toString(),
        reviewStage: ((m['reviewStage'] ?? 0) as num).toInt(),
        seeded: m['seeded'] == true,
        workspaceMap: m['workspaceMap'] is Map
            ? Map<String, dynamic>.from(m['workspaceMap'] as Map)
            : <String, dynamic>{},
      );
}
