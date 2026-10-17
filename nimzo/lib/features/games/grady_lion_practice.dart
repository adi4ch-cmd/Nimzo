import 'dart:math';

import 'package:flutter/material.dart';

/// This mode deliberately uses no wallet, RPC, or real-game settlement.
/// Its random samples are illustrations and do not represent production odds.
class GradyLionPracticeSelection {
  static const maxSelections = 6;
  static const options = <GradyLionPracticeOption>[
    GradyLionPracticeOption('Tomato', 0, 5),
    GradyLionPracticeOption('Mushroom', 1, 5),
    GradyLionPracticeOption('Onion', 2, 5),
    GradyLionPracticeOption('Shaljam', 3, 5),
    GradyLionPracticeOption('Meat', 5, 10),
    GradyLionPracticeOption('Fish', 6, 15),
    GradyLionPracticeOption('Jinga', 7, 25),
    GradyLionPracticeOption('Chicken', 8, 45),
  ];

  final Set<int> _selected = <int>{};

  Set<int> get selected => Set<int>.unmodifiable(_selected);
  int get count => _selected.length;

  /// Returns false only when an additional pick would exceed the limit.
  bool toggle(int index) {
    RangeError.checkValueInInterval(index, 0, options.length - 1, 'index');
    if (_selected.remove(index)) return true;
    if (_selected.length >= maxSelections) return false;
    _selected.add(index);
    return true;
  }

  bool contains(int index) => _selected.contains(index);
  void clear() => _selected.clear();
}

class GradyLionPracticeOption {
  final String name;
  final int assetIndex;
  final int referenceMultiplier;
  const GradyLionPracticeOption(
    this.name,
    this.assetIndex,
    this.referenceMultiplier,
  );
}

/// A no-stakes practice board. Financial play remains server-disabled.
class GradyLionPracticeScreen extends StatefulWidget {
  const GradyLionPracticeScreen({super.key});

  @override
  State<GradyLionPracticeScreen> createState() =>
      _GradyLionPracticeScreenState();
}

class _GradyLionPracticeScreenState extends State<GradyLionPracticeScreen> {
  static const _background = Color(0xff14052e);
  static const _gold = Color(0xffffd58a);
  static const _tile = Color(0xff32145f);

  final _selection = GradyLionPracticeSelection();
  final _random = Random();
  int? _resultIndex;
  bool _drawing = false;

  void _toggle(int index) {
    if (_drawing) return;
    setState(() {
      if (!_selection.toggle(index)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose up to 6 options per round.')),
        );
        return;
      }
      _resultIndex = null;
    });
  }

  Future<void> _draw() async {
    if (_drawing || _selection.count == 0) return;
    setState(() {
      _drawing = true;
      _resultIndex = null;
    });
    await Future<void>.delayed(
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 1100),
    );
    if (!mounted) return;
    setState(() {
      _resultIndex =
          _random.nextInt(GradyLionPracticeSelection.options.length);
      _drawing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = GradyLionPracticeSelection.options;
    final winner = _resultIndex == null ? null : options[_resultIndex!];
    final matched = _resultIndex != null &&
        _selection.contains(_resultIndex!);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: const Color(0xff3b0f7a),
        foregroundColor: Colors.white,
        title: const Text(
          'Grady Lion · Practice',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff29104f),
                border: Border.all(color: _gold.withValues(alpha: .42)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FREE PRACTICE',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pick any 6 of 8 animals or foods',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'No coins are charged or awarded. Random practice '
                    'results are not live game odds. The two special '
                    'all-four options need approved server rules.',
                    style: TextStyle(
                      color: Color(0xffd8c8f1),
                      height: 1.4,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select outcomes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${_selection.count} / 6 selected',
                  key: const ValueKey('grady-practice-count'),
                  style: const TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
                mainAxisExtent: 126,
              ),
              itemBuilder: (context, index) {
                final option = options[index];
                final selected = _selection.contains(index);
                final won = index == _resultIndex;
                return Material(
                  color: _tile,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: ValueKey('grady-practice-option-$index'),
                    onTap: _drawing ? null : () => _toggle(index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: won
                              ? Colors.greenAccent
                              : selected
                                  ? _gold
                                  : const Color(0xff624383),
                          width: won || selected ? 2.4 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/reference/grady/${option.assetIndex}.jpg',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.restaurant,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            option.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '${option.referenceMultiplier}x ref.',
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.add_circle_outline,
                            color: selected ? _gold : Colors.white60,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            if (_drawing)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: _gold),
                    SizedBox(height: 12),
                    Text(
                      'Drawing sample outcome…',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              )
            else if (winner != null)
              Container(
                key: const ValueKey('grady-practice-result'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xff29104f),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Practice result: ${winner.name}. '
                  '${matched ? 'Your selection matched.' : 'Not selected.'} '
                  'No coin payout.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('grady-practice-reset'),
                    onPressed: _drawing
                        ? null
                        : () => setState(() {
                              _selection.clear();
                              _resultIndex = null;
                            }),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const ValueKey('grady-practice-draw'),
                    onPressed:
                        _drawing || _selection.count == 0 ? null : _draw,
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: const Color(0xff3b0764),
                    ),
                    child: const Text('Start practice round'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
