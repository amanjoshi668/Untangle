import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/decision_model.dart';

const List<Color> _quadHues = [
  Color(0xFF4F8560), // sage
  Color(0xFFC4613A), // terracotta
  Color(0xFF9A928A), // stone
  Color(0xFF4F6AA8), // slate indigo
];

class CanvasEngineWidget extends StatefulWidget {
  final DecisionModelSpec spec;
  final DecisionWorkspaceData data;
  final VoidCallback onChanged;

  const CanvasEngineWidget({
    super.key,
    required this.spec,
    required this.data,
    required this.onChanged,
  });

  @override
  State<CanvasEngineWidget> createState() => _CanvasEngineWidgetState();
}

class _CanvasEngineWidgetState extends State<CanvasEngineWidget> {
  final TextEditingController _addCtrl = TextEditingController();
  late TextEditingController _brokenRuleCtrl;
  late TextEditingController _memoCtrl;
  late TextEditingController _principleCtrl;
  late TextEditingController _swanAssumpCtrl;
  late TextEditingController _swanBufferCtrl;
  late TextEditingController _customTitleCtrl;
  late TextEditingController _hatCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant CanvasEngineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec.id != widget.spec.id || oldWidget.data != widget.data) {
      _syncControllers();
    }
  }

  void _initControllers() {
    _brokenRuleCtrl = TextEditingController(text: widget.data.brokenRule);
    _memoCtrl = TextEditingController(text: widget.data.memoText);
    _principleCtrl = TextEditingController(text: widget.data.guidingPrinciple);
    _swanAssumpCtrl = TextEditingController(text: widget.data.swanAssumption);
    _swanBufferCtrl = TextEditingController(text: widget.data.swanBuffer);
    _customTitleCtrl = TextEditingController(text: widget.data.customTitle);
    final hi = widget.data.hatIndex.clamp(0, 5);
    _hatCtrl = TextEditingController(
      text: hi < widget.data.hatNotes.length ? widget.data.hatNotes[hi] : '',
    );
  }

  void _syncControllers() {
    _brokenRuleCtrl.text = widget.data.brokenRule;
    _memoCtrl.text = widget.data.memoText;
    _principleCtrl.text = widget.data.guidingPrinciple;
    _swanAssumpCtrl.text = widget.data.swanAssumption;
    _swanBufferCtrl.text = widget.data.swanBuffer;
    _customTitleCtrl.text = widget.data.customTitle;
    final hi = widget.data.hatIndex.clamp(0, 5);
    _hatCtrl.text = hi < widget.data.hatNotes.length ? widget.data.hatNotes[hi] : '';
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    _brokenRuleCtrl.dispose();
    _memoCtrl.dispose();
    _principleCtrl.dispose();
    _swanAssumpCtrl.dispose();
    _swanBufferCtrl.dispose();
    _customTitleCtrl.dispose();
    _hatCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.spec.engine) {
      case CanvasEngine.e1Quadrant:
        return _buildE1Quadrant(context);
      case CanvasEngine.e2Force:
        return _buildE2Force(context);
      case CanvasEngine.e3SlidersSvg:
        return _buildE3Sliders(context);
      case CanvasEngine.e4Diagnostic:
        return _buildE4Diagnostic(context);
      case CanvasEngine.e5Combinator:
        return _buildE5Combinator(context);
      case CanvasEngine.e6TimelineCurve:
        return _buildE6Timeline(context);
      case CanvasEngine.e7Network:
        return _buildE7Network(context);
      case CanvasEngine.e8SimCustom:
        return _buildE8SimCustom(context);
    }
  }

  // ===========================================================================
  // E1: 2x2 QUADRANT SORTER (360px Safe + Responsive 2-Column on Wide)
  // ===========================================================================
  Widget _buildE1Quadrant(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final quads = widget.spec.quadrants;
    final hints = widget.spec.quadrantHints;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('e1_add_field'),
          controller: _addCtrl,
          decoration: const InputDecoration(hintText: 'Add item, task, or factor...'),
          onSubmitted: (_) => _addQuadrantItem(widget.data.targetQuadrant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(4, (qi) {
            final selected = widget.data.targetQuadrant == qi;
            return InkWell(
              key: Key('e1_add_quad_$qi'),
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                if (_addCtrl.text.trim().isNotEmpty) {
                  _addQuadrantItem(qi);
                } else {
                  widget.data.targetQuadrant = qi;
                  _emit();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.secondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? cs.primary : cs.outline),
                ),
                child: Text(
                  '+ ${quads[qi]}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? cs.onPrimary : cs.onSurface,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final twoCol = constraints.maxWidth >= 520;
            final cards = List.generate(4, (qi) {
              final entries = <MapEntry<int, QuadrantEntry>>[];
              for (int i = 0; i < widget.data.quadItems.length; i++) {
                if (widget.data.quadItems[i].quadrant == qi) {
                  entries.add(MapEntry(i, widget.data.quadItems[i]));
                }
              }
              return Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(right: 8, top: 1),
                          decoration: BoxDecoration(color: _quadHues[qi], shape: BoxShape.circle),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(quads[qi], style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                              if (qi < hints.length && hints[qi].isNotEmpty)
                                Text(hints[qi], style: tt.bodySmall),
                            ],
                          ),
                        ),
                        Text('${entries.length}', style: tt.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: cs.outline),
                    const SizedBox(height: 6),
                    if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('No items', style: tt.bodySmall),
                      )
                    else
                      for (final e in entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Text(e.value.text, style: tt.bodyMedium?.copyWith(fontSize: 13))),
                              InkWell(
                                onTap: () {
                                  widget.data.quadItems[e.key].quadrant = (qi + 1) % 4;
                                  _emit();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  child: Icon(Icons.swap_horiz, size: 16, color: cs.onSurface.withOpacity(0.6)),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  widget.data.quadItems.removeAt(e.key);
                                  _emit();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                                  child: Icon(Icons.close, size: 15, color: cs.onSurface.withOpacity(0.55)),
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              );
            });

            if (twoCol) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 10),
                      Expanded(child: cards[1]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[2]),
                      const SizedBox(width: 10),
                      Expanded(child: cards[3]),
                    ],
                  ),
                ],
              );
            }
            return Column(
              children: [
                for (int i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  cards[i],
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  void _addQuadrantItem(int qi) {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    widget.data.quadItems.add(QuadrantEntry(text: text, quadrant: qi));
    widget.data.targetQuadrant = qi;
    _addCtrl.clear();
    _emit();
  }

  // ===========================================================================
  // E2: TUG-OF-WAR FORCE BALANCE
  // ===========================================================================
  Widget _buildE2Force(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final lSum = widget.data.leftItems.fold<int>(0, (s, x) => s + x.weight);
    final rSum = widget.data.rightItems.fold<int>(0, (s, x) => s + x.weight);
    final total = math.max(lSum + rSum, 1);
    final leftFlex = math.max(((lSum / total) * 100).round(), 8);
    final rightFlex = math.max(((rSum / total) * 100).round(), 8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${widget.spec.leftLabel} ($lSum)',
                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '($rSum) ${widget.spec.rightLabel}',
                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(flex: leftFlex, child: Container(color: cs.onSurface.withOpacity(0.25))),
                Expanded(flex: rightFlex, child: Container(color: cs.primary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('e2_add_field'),
          controller: _addCtrl,
          decoration: const InputDecoration(hintText: 'Add force or factor...'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('e2_add_left_btn'),
                onPressed: () {
                  final v = _addCtrl.text.trim();
                  if (v.isEmpty) return;
                  widget.data.leftItems.add(WeightedForce(text: v, weight: 3));
                  _addCtrl.clear();
                  _emit();
                },
                child: const Text('+ Left', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                key: const Key('e2_add_right_btn'),
                onPressed: () {
                  final v = _addCtrl.text.trim();
                  if (v.isEmpty) return;
                  widget.data.rightItems.add(WeightedForce(text: v, weight: 4));
                  _addCtrl.clear();
                  _emit();
                },
                child: const Text('+ Right', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildForceColumn(context, widget.spec.leftLabel, widget.data.leftItems),
        const SizedBox(height: 10),
        _buildForceColumn(context, widget.spec.rightLabel, widget.data.rightItems),
      ],
    );
  }

  Widget _buildForceColumn(BuildContext context, String title, List<WeightedForce> list) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Divider(height: 1, color: cs.outline),
          const SizedBox(height: 6),
          if (list.isEmpty)
            Text('None added', style: tt.bodySmall)
          else
            for (int i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(list[i].text, style: tt.bodyMedium?.copyWith(fontSize: 13))),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        list[i].weight = (list[i].weight % 5) + 1;
                        _emit();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          '${'●' * list[i].weight}${'○' * (5 - list[i].weight)}',
                          style: TextStyle(fontSize: 12, color: cs.primary, letterSpacing: 1),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        list.removeAt(i);
                        _emit();
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.close, size: 15, color: cs.onSurface.withOpacity(0.55)),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ===========================================================================
  // E3: ARCHITECTURAL CHARTS & SLIDERS
  // ===========================================================================
  Widget _buildE3Sliders(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sub = widget.spec.subtype;
    if (sub == 'energy') {
      final nowPct = math.max(0.0, 100.0 - widget.data.pastPct - widget.data.futurePct);
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _metricTile(context, 'Past', '${widget.data.pastPct.round()}%'),
                const SizedBox(width: 8),
                _metricTile(context, 'Present', '${nowPct.round()}%', highlight: true),
                const SizedBox(width: 8),
                _metricTile(context, 'Future', '${widget.data.futurePct.round()}%'),
              ],
            ),
            const SizedBox(height: 12),
            _labeledSlider(context, 'Past Reflection', widget.data.pastPct, 0, 80, (v) {
              widget.data.pastPct = v;
              if (widget.data.pastPct + widget.data.futurePct > 100) {
                widget.data.futurePct = 100 - widget.data.pastPct;
              }
              _emit();
            }),
            _labeledSlider(context, 'Future Planning / Worry', widget.data.futurePct, 0, 80, (v) {
              widget.data.futurePct = v;
              if (widget.data.pastPct + widget.data.futurePct > 100) {
                widget.data.pastPct = 100 - widget.data.futurePct;
              }
              _emit();
            }),
          ],
        ),
      );
    }

    if (sub == 'flow') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(
                painter: _FlowChartPainter(
                  challenge: widget.data.s1,
                  skill: widget.data.s2,
                  primary: cs.primary,
                  ink: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _labeledSlider(context, 'Challenge Level', widget.data.s1, 1, 10, (v) {
              widget.data.s1 = v;
              _emit();
            }),
            _labeledSlider(context, 'Skill & Readiness', widget.data.s2, 1, 10, (v) {
              widget.data.s2 = v;
              _emit();
            }),
          ],
        ),
      );
    }

    final labels = sub == 'sail'
        ? ['Have To (Obligation)', 'Able To (Capability)', 'Want To (Desire)']
        : sub == 'elbaek'
            ? ['Global (vs. Local)', 'Team (vs. Individual)', 'Brain (vs. Body)']
            : sub == 'potential'
                ? ['My Expectations', 'Others\' Expectations', 'Actual Results']
                : sub == 'teamskills'
                    ? ['Domain Craft', 'Execution Reliability', 'Composure']
                    : ['Cost-Effectiveness', 'Prestige & Quality', 'Market Awareness'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _SailRadarPainter(
                v1: widget.data.s1,
                v2: widget.data.s2,
                v3: widget.data.s3,
                primary: cs.primary,
                ink: cs.onSurface,
              ),
            ),
          ),
          _labeledSlider(context, labels[0], widget.data.s1, 1, 10, (v) {
            widget.data.s1 = v;
            _emit();
          }),
          _labeledSlider(context, labels[1], widget.data.s2, 1, 10, (v) {
            widget.data.s2 = v;
            _emit();
          }),
          _labeledSlider(context, labels[2], widget.data.s3, 1, 10, (v) {
            widget.data.s3 = v;
            _emit();
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // E4: DIAGNOSTIC CHECKLIST & STAGE STEPPER
  // ===========================================================================
  Widget _buildE4Diagnostic(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final items = widget.spec.checklistItems;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: List.generate(items.length, (idx) {
          final active = widget.spec.singleStageMode
              ? widget.data.stageIndex == idx
              : (idx < widget.data.checks.length && widget.data.checks[idx]);
          return Column(
            children: [
              if (idx > 0) Divider(height: 1, color: cs.outline),
              InkWell(
                onTap: () {
                  if (widget.spec.singleStageMode) {
                    widget.data.stageIndex = idx;
                  } else if (idx < widget.data.checks.length) {
                    widget.data.checks[idx] = !widget.data.checks[idx];
                  }
                  _emit();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          items[idx],
                          style: tt.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                            color: active ? cs.onSurface : cs.onSurface.withOpacity(0.72),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: active ? cs.primary : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: active ? cs.primary : cs.outline),
                        ),
                        child: active ? Icon(Icons.check, size: 13, color: cs.onPrimary) : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // E5: COMBINATOR, 9-DOT PUZZLE & SIX THINKING HATS
  // ===========================================================================
  Widget _buildE5Combinator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sub = widget.spec.subtype;

    if (sub == 'sixhats') {
      const hats = [
        ('White', 'Objective facts & missing data'),
        ('Red', 'Intuition & gut feelings'),
        ('Black', 'Risks & failure modes'),
        ('Yellow', 'Best-case upside'),
        ('Green', 'Creative alternatives'),
        ('Blue', 'Big-picture synthesis'),
      ];
      final cur = widget.data.hatIndex.clamp(0, 5);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(hats.length, (i) {
              final sel = cur == i;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  widget.data.hatIndex = i;
                  _hatCtrl.text = i < widget.data.hatNotes.length ? widget.data.hatNotes[i] : '';
                  _emit();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? cs.primary : cs.secondary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? cs.primary : cs.outline),
                  ),
                  child: Text(
                    hats[i].$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel ? cs.onPrimary : cs.onSurface,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text('${hats[cur].$1} Hat — ${hats[cur].$2}', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _hatCtrl,
            maxLines: 3,
            onChanged: (v) {
              while (widget.data.hatNotes.length <= cur) {
                widget.data.hatNotes.add('');
              }
              widget.data.hatNotes[cur] = v;
              widget.onChanged();
            },
            decoration: const InputDecoration(hintText: 'Capture thoughts under this lens...'),
          ),
        ],
      );
    }

    if (sub == 'ninedot') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('9-Dot Lateral Boundary', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                TextButton(
                  onPressed: () {
                    widget.data.puzzleSolved = !widget.data.puzzleSolved;
                    _emit();
                  },
                  child: Text(widget.data.puzzleSolved ? 'Reset' : 'Reveal 4-Line Path', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(
                painter: _NineDotPainter(
                  solved: widget.data.puzzleSolved,
                  primary: cs.primary,
                  ink: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Self-imposed assumption you can drop:', style: tt.bodySmall),
            const SizedBox(height: 6),
            TextField(
              controller: _brokenRuleCtrl,
              onChanged: (v) {
                widget.data.brokenRule = v;
                widget.onChanged();
              },
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(widget.spec.morphRows.length, (ri) {
          final row = widget.spec.morphRows[ri];
          final sel = ri < widget.data.morphSelection.length ? widget.data.morphSelection[ri] : 0;
          return Padding(
            padding: EdgeInsets.only(bottom: ri == widget.spec.morphRows.length - 1 ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.parameter, style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(row.options.length, (oi) {
                    final chosen = sel == oi;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        while (widget.data.morphSelection.length <= ri) {
                          widget.data.morphSelection.add(0);
                        }
                        widget.data.morphSelection[ri] = oi;
                        _emit();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: chosen ? cs.primary : cs.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: chosen ? cs.primary : cs.outline),
                        ),
                        child: Text(
                          row.options[oi],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: chosen ? FontWeight.w600 : FontWeight.w400,
                            color: chosen ? cs.onPrimary : cs.onSurface,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // E6: TIMELINES, CURVES & 3-LOOP PLANNER
  // ===========================================================================
  Widget _buildE6Timeline(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sub = widget.spec.subtype;

    if (sub == 'gift') {
      const rels = ['Partner', 'Family', 'Friend', 'Colleague', 'Host'];
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: rels.map((r) {
                final sel = widget.data.giftRelation == r;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    widget.data.giftRelation = r;
                    _emit();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? cs.primary : cs.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? cs.primary : cs.outline),
                    ),
                    child: Text(
                      r,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sel ? cs.onPrimary : cs.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            _labeledSlider(context, 'Years known', widget.data.giftYears, 1, 20, (v) {
              widget.data.giftYears = v;
              _emit();
            }),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('Major milestone occasion', style: tt.bodyMedium?.copyWith(fontSize: 13)),
              value: widget.data.giftMilestone,
              onChanged: (v) {
                widget.data.giftMilestone = v;
                _emit();
              },
            ),
          ],
        ),
      );
    }

    if (sub == 'threeloop') {
      final unit = (widget.data.hoursTotal / 3.0).toStringAsFixed(1);
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          children: [
            _labeledSlider(context, 'Total time until deadline (hrs/days)', widget.data.hoursTotal, 3, 60, (v) {
              widget.data.hoursTotal = v;
              _emit();
            }),
            Divider(color: cs.outline),
            _loopRow(context, 'Loop 1 · Complete rough draft', '$unit units'),
            _loopRow(context, 'Loop 2 · Critique & structural fix', '$unit units'),
            _loopRow(context, 'Loop 3 · Polish & surprise buffer', '$unit units'),
          ],
        ),
      );
    }

    if (sub == 'crossroads') {
      const roads = [
        '1. The Beckoning Road',
        '2. Wildest Dream Road',
        '3. The Sensible Road',
        '4. Road Not Travelled',
        '5. The Familiar Road',
        '6. The Safe Road Back',
      ];
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          children: List.generate(roads.length, (i) {
            final val = i < widget.data.roadScores.length ? widget.data.roadScores[i] : 5.0;
            return _labeledSlider(context, roads[i], val, 1, 10, (v) {
              widget.data.roadScores[i] = v;
              _emit();
            });
          }),
        ),
      );
    }

    if (sub == 'supermemo') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key insight or lesson to retain:', style: tt.bodySmall),
            const SizedBox(height: 6),
            TextField(
              controller: _memoCtrl,
              maxLines: 2,
              onChanged: (v) {
                widget.data.memoText = v;
                widget.onChanged();
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const ['Day 1', 'Day 10', 'Day 30', 'Day 60']
                  .map((d) => Chip(label: Text(d, style: const TextStyle(fontSize: 12)), visualDensity: VisualDensity.compact))
                  .toList(),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labeledSlider(context, 'Current Knowledge (%)', widget.data.knowPct, 5, 95, (v) {
            widget.data.knowPct = v;
            _emit();
          }),
          _labeledSlider(context, 'Decision Impact (%)', widget.data.impactPct, 5, 95, (v) {
            widget.data.impactPct = v;
            _emit();
          }),
          const SizedBox(height: 6),
          Text('Guiding principle moving forward:', style: tt.bodySmall),
          const SizedBox(height: 6),
          TextField(
            controller: _principleCtrl,
            onChanged: (v) {
              widget.data.guidingPrinciple = v;
              widget.onChanged();
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // E7: NETWORK, WARM CHAIN & RESILIENCE
  // ===========================================================================
  Widget _buildE7Network(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sub = widget.spec.subtype;

    if (sub == 'chain') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          children: List.generate(widget.data.chainSteps.length, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: cs.secondary,
                    child: Text('$i', style: TextStyle(fontSize: 12, color: cs.onSurface)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: widget.data.chainSteps[i],
                      onChanged: (v) {
                        widget.data.chainSteps[i] = v;
                        widget.onChanged();
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      );
    }

    if (sub == 'tree' || sub == 'bullseye') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addCtrl,
                    decoration: const InputDecoration(hintText: 'Add person or client...'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final v = _addCtrl.text.trim();
                    if (v.isEmpty) return;
                    widget.data.nodes.add(NetworkNodeEntry(name: v));
                    _addCtrl.clear();
                    _emit();
                  },
                  child: const Text('Add', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < widget.data.nodes.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.data.nodes[i].name,
                        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${widget.data.nodes[i].relation} · ${widget.data.nodes[i].badge}',
                      style: tt.bodySmall,
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        widget.data.nodes.removeAt(i);
                        _emit();
                      },
                      child: Icon(Icons.close, size: 15, color: cs.onSurface.withOpacity(0.55)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Key fragility or crowded assumption:', style: tt.bodySmall),
          const SizedBox(height: 6),
          TextField(
            controller: _swanAssumpCtrl,
            onChanged: (v) {
              widget.data.swanAssumption = v;
              widget.onChanged();
            },
          ),
          const SizedBox(height: 12),
          Text('Resilient safeguard / niche counter-move:', style: tt.bodySmall),
          const SizedBox(height: 6),
          TextField(
            controller: _swanBufferCtrl,
            onChanged: (v) {
              widget.data.swanBuffer = v;
              widget.onChanged();
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // E8: MONTE CARLO SIMULATOR & CUSTOM MODEL STUDIO
  // ===========================================================================
  Widget _buildE8SimCustom(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (widget.spec.subtype == 'montecarlo') {
      final sim = MonteCarloSummary.simulate(
        widget.data.mcMin,
        widget.data.mcLikely,
        widget.data.mcMax,
        seed: widget.data.mcSeed,
      );
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text('1,000 Randomized Trials', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                OutlinedButton(
                  onPressed: () {
                    widget.data.mcSeed++;
                    _emit();
                  },
                  child: const Text('Resimulate', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
              width: double.infinity,
              child: CustomPaint(
                painter: _HistogramPainter(bins: sim.bins, primary: cs.primary),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _metricTile(context, 'P10 Low', '${sim.p10}'),
                const SizedBox(width: 8),
                _metricTile(context, 'Median', '${sim.p50}', highlight: true),
                const SizedBox(width: 8),
                _metricTile(context, 'P90 High', '${sim.p90}'),
              ],
            ),
            const SizedBox(height: 10),
            _labeledSlider(context, 'Conservative (Min)', widget.data.mcMin, 10, 120, (v) {
              widget.data.mcMin = v;
              _emit();
            }),
            _labeledSlider(context, 'Most Likely', widget.data.mcLikely, 20, 180, (v) {
              widget.data.mcLikely = v;
              _emit();
            }),
            _labeledSlider(context, 'Optimistic (Max)', widget.data.mcMax, 40, 260, (v) {
              widget.data.mcMax = v;
              _emit();
            }),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Custom Framework Name', style: tt.bodySmall),
          const SizedBox(height: 6),
          TextField(
            controller: _customTitleCtrl,
            onChanged: (v) {
              widget.data.customTitle = v;
              widget.onChanged();
            },
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < widget.data.customQuadrants.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextFormField(
                initialValue: widget.data.customQuadrants[i],
                decoration: InputDecoration(labelText: 'Quadrant ${i + 1}'),
                onChanged: (v) {
                  widget.data.customQuadrants[i] = v;
                  widget.onChanged();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _labeledSlider(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: tt.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text('${value.round()}', style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _metricTile(BuildContext context, String label, String value, {bool highlight = false}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: highlight ? cs.primary : cs.outline),
        ),
        child: Column(
          children: [
            Text(label, style: tt.bodySmall, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(value, style: tt.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _loopRow(BuildContext context, String label, String val) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: tt.bodyMedium?.copyWith(fontSize: 13))),
          const SizedBox(width: 8),
          Text(val, style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _FlowChartPainter extends CustomPainter {
  final double challenge;
  final double skill;
  final Color primary;
  final Color ink;

  const _FlowChartPainter({
    required this.challenge,
    required this.skill,
    required this.primary,
    required this.ink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = ink.withOpacity(0.25)
      ..strokeWidth = 1.2;
    final padL = 22.0, padB = size.height - 18.0, padT = 12.0, padR = size.width - 14.0;
    canvas.drawLine(Offset(padL, padB), Offset(padR, padB), axisPaint);
    canvas.drawLine(Offset(padL, padB), Offset(padL, padT), axisPaint);

    final channelPath = Path()
      ..moveTo(padL, padB)
      ..lineTo(padR - 36, padT)
      ..lineTo(padR, padT)
      ..lineTo(padL + 36, padB)
      ..close();
    canvas.drawPath(channelPath, Paint()..color = primary.withOpacity(0.16));

    final px = padL + ((skill - 1) / 9.0) * (padR - padL);
    final py = padB - ((challenge - 1) / 9.0) * (padB - padT);
    canvas.drawCircle(Offset(px, py), 6.5, Paint()..color = primary);
  }

  @override
  bool shouldRepaint(covariant _FlowChartPainter old) =>
      old.challenge != challenge || old.skill != skill || old.primary != primary;
}

class _SailRadarPainter extends CustomPainter {
  final double v1;
  final double v2;
  final double v3;
  final Color primary;
  final Color ink;

  const _SailRadarPainter({
    required this.v1,
    required this.v2,
    required this.v3,
    required this.primary,
    required this.ink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.62;
    final r = math.min(size.width, size.height) * 0.44;
    final guide = Paint()
      ..color = ink.withOpacity(0.2)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(cx, cy), Offset(cx, cy - r), guide);
    canvas.drawLine(Offset(cx, cy), Offset(cx + r * 0.86, cy + r * 0.5), guide);
    canvas.drawLine(Offset(cx, cy), Offset(cx - r * 0.86, cy + r * 0.5), guide);

    final p1 = Offset(cx, cy - r * (v1 / 10.0));
    final p2 = Offset(cx + r * 0.86 * (v2 / 10.0), cy + r * 0.5 * (v2 / 10.0));
    final p3 = Offset(cx - r * 0.86 * (v3 / 10.0), cy + r * 0.5 * (v3 / 10.0));

    final poly = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    canvas.drawPath(poly, Paint()..color = primary.withOpacity(0.22));
    canvas.drawPath(
      poly,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SailRadarPainter old) =>
      old.v1 != v1 || old.v2 != v2 || old.v3 != v3;
}

class _NineDotPainter extends CustomPainter {
  final bool solved;
  final Color primary;
  final Color ink;

  const _NineDotPainter({
    required this.solved,
    required this.primary,
    required this.ink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const step = 30.0;
    final dotPaint = Paint()..color = ink.withOpacity(0.75);
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        canvas.drawCircle(Offset(cx + dx * step, cy + dy * step), 4.2, dotPaint);
      }
    }
    if (solved) {
      final p = Path()
        ..moveTo(cx - step, cy + step)
        ..lineTo(cx - step, cy - step * 1.65)
        ..lineTo(cx + step * 1.65, cy + step)
        ..lineTo(cx - step * 1.4, cy + step)
        ..lineTo(cx + step * 1.2, cy - step * 1.2);
      canvas.drawPath(
        p,
        Paint()
          ..color = primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NineDotPainter old) => old.solved != solved;
}

class _HistogramPainter extends CustomPainter {
  final List<double> bins;
  final Color primary;

  const _HistogramPainter({required this.bins, required this.primary});

  @override
  void paint(Canvas canvas, Size size) {
    if (bins.isEmpty) return;
    final barW = (size.width / bins.length) * 0.72;
    final gap = (size.width / bins.length) * 0.28;
    for (int i = 0; i < bins.length; i++) {
      final h = math.max(bins[i] * (size.height - 8), 3.0);
      final x = i * (barW + gap) + gap / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, barW, h),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = primary.withOpacity(i >= 2 && i <= 11 ? 0.85 : 0.38),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HistogramPainter old) => old.bins != bins;
}
