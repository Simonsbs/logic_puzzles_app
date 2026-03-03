import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logic_puzzles_app/core/models/mode_streak.dart';
import 'package:logic_puzzles_app/core/models/puzzle.dart';
import 'package:logic_puzzles_app/core/models/puzzle_progress_status.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/features/queens/queens_page.dart';
import 'package:logic_puzzles_app/features/sudoku/sudoku_page.dart';
import 'package:logic_puzzles_app/state/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PuzzleListPage extends ConsumerStatefulWidget {
  const PuzzleListPage({super.key, required this.type});

  final PuzzleType type;

  @override
  ConsumerState<PuzzleListPage> createState() => _PuzzleListPageState();
}

class _PuzzleListPageState extends ConsumerState<PuzzleListPage> {
  late Future<_PuzzleListData> _future;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{};

  int _selectedMonthIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.type.displayName} Puzzles')),
      body: FutureBuilder<_PuzzleListData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          if (data.sections.isEmpty) {
            return const Center(child: Text('No puzzles available yet.'));
          }

          if (_selectedMonthIndex >= data.months.length) {
            _selectedMonthIndex = data.months.length - 1;
          }

          final modeStreak =
              ref.watch(modeStreakProvider(widget.type)).valueOrNull;

          return Column(
            children: <Widget>[
              _buildCalendarControl(data, modeStreak),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                  itemCount: data.sections.length,
                  itemBuilder: (context, index) {
                    final section = data.sections[index];
                    final key = _sectionKeys.putIfAbsent(
                      _dayKey(section.date),
                      () => GlobalKey(),
                    );
                    return Container(
                      key: key,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: _buildDaySection(data, section),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendarControl(_PuzzleListData data, ModeStreak? modeStreak) {
    final month = data.months[_selectedMonthIndex];
    final monthDates = data.datesForMonth(month);

    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7;

    final cells = <DateTime?>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(null);
    }
    for (var day = 1; day <= daysInMonth; day++) {
      cells.add(DateTime(month.year, month.month, day));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: const Color(0xFFF7FAFC),
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFB9D4F5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 16,
                  color: Color(0xFFCF6A00),
                ),
                const SizedBox(width: 6),
                Text(
                  'Basic ${modeStreak?.basicDays ?? 0}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF28425D),
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Icons.workspace_premium_rounded,
                  size: 16,
                  color: Color(0xFF0D8A63),
                ),
                const SizedBox(width: 6),
                Text(
                  'Pro ${modeStreak?.proDays ?? 0}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF28425D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              IconButton(
                onPressed:
                    _selectedMonthIndex > 0
                        ? () => setState(() => _selectedMonthIndex--)
                        : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous month',
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _monthLabel(month),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed:
                    _selectedMonthIndex < data.months.length - 1
                        ? () => setState(() => _selectedMonthIndex++)
                        : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next month',
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: <Widget>[
              _WeekdayCell('S'),
              _WeekdayCell('M'),
              _WeekdayCell('T'),
              _WeekdayCell('W'),
              _WeekdayCell('T'),
              _WeekdayCell('F'),
              _WeekdayCell('S'),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: cells.length,
            itemBuilder: (context, i) {
              final date = cells[i];
              if (date == null) {
                return const SizedBox.shrink();
              }

              final summary = monthDates[_dayKey(date)];
              if (summary == null) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF3F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: const TextStyle(
                        color: Color(0xFF98A7B3),
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }

              final streakType = _streakType(
                solved: summary.solvedCount,
                inProgress: summary.inProgressCount,
                total: summary.totalCount,
              );
              final color = _streakColor(streakType);
              final icon = _streakIcon(streakType);

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _jumpToDate(date),
                child: Ink(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Icon(icon, size: 13, color: color),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 10,
            runSpacing: 6,
            children: <Widget>[
              _LegendItem(
                label: 'No streak',
                color: Color(0xFFC0392B),
                icon: Icons.radio_button_unchecked,
              ),
              _LegendItem(
                label: 'Basic streak',
                color: Color(0xFFB26A00),
                icon: Icons.local_fire_department_rounded,
              ),
              _LegendItem(
                label: 'Pro streak',
                color: Color(0xFF198754),
                icon: Icons.workspace_premium_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(_PuzzleListData data, _PuzzleDaySection section) {
    final dateLabel = _formatDate(section.date);
    final stats =
        'Solved ${section.solvedCount}/${section.rows.length}'
        '${section.inProgressCount > 0 ? ' • In progress ${section.inProgressCount}' : ''}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x12000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F7FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '$dateLabel - $stats',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          ...section.rows.map((row) => _buildPuzzleRow(data, row)),
        ],
      ),
    );
  }

  Widget _buildPuzzleRow(_PuzzleListData data, _PuzzleRow row) {
    final difficulty = row.puzzle.difficulty.toLowerCase();
    final (icon, color, label) = switch (difficulty) {
      'hard' => (Icons.whatshot_rounded, const Color(0xFFD64545), 'Hard'),
      'medium' => (Icons.flash_on_rounded, const Color(0xFFC07A00), 'Medium'),
      _ => (Icons.eco_rounded, const Color(0xFF1C8D55), 'Easy'),
    };

    final solved = row.status.completed;
    final inProgress = row.status.inProgress;

    return InkWell(
      onTap: () => _openPuzzle(data, row.puzzle, row.status),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ),
            if (solved)
              const _StatePill(
                label: 'Completed',
                color: Color(0xFF198754),
                bgColor: Color(0xFFE9F7EF),
              )
            else if (inProgress)
              const _StatePill(
                label: 'In progress',
                color: Color(0xFF275EA8),
                bgColor: Color(0xFFE8F0FA),
              )
            else
              const _StatePill(
                label: 'Unsolved',
                color: Color(0xFF7E8C98),
                bgColor: Color(0xFFF1F4F7),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Future<_PuzzleListData> _load() async {
    final puzzles = await ref
        .read(puzzleRepositoryProvider)
        .getPuzzles(widget.type);
    final remote = await ref
        .read(puzzleProgressServiceProvider)
        .progressByType(widget.type);
    final merged = Map<String, PuzzleProgressStatus>.from(remote);

    final auth = ref.read(authServiceProvider);
    final userId = auth.currentUser?.id ?? 'guest-local';
    final prefs = await SharedPreferences.getInstance();

    for (final puzzle in puzzles) {
      final localCompleted =
          prefs.getBool('puzzle_completed_${userId}_${puzzle.id}') ?? false;
      final remoteStatus = merged[puzzle.id];

      var localInProgress = false;
      if (puzzle.type == PuzzleType.sudoku) {
        final session = await ref
            .read(puzzleSessionServiceProvider)
            .loadSudokuSession(puzzleId: puzzle.id);
        localInProgress = session != null && session.elapsedSeconds > 0;
      }

      final completed = (remoteStatus?.completed ?? false) || localCompleted;
      final inProgress =
          !completed &&
          ((remoteStatus?.inProgress ?? false) || localInProgress);
      final bestSeconds = remoteStatus?.bestSeconds ?? 0;

      merged[puzzle.id] = PuzzleProgressStatus(
        completed: completed,
        inProgress: inProgress,
        bestSeconds: bestSeconds,
        updatedAt: remoteStatus?.updatedAt,
      );
    }

    final sorted = List<Puzzle>.from(puzzles)..sort((a, b) {
      final da =
          a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final db =
          b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final dateCmp = db.compareTo(da);
      if (dateCmp != 0) {
        return dateCmp;
      }
      return _difficultyRank(
        a.difficulty,
      ).compareTo(_difficultyRank(b.difficulty));
    });

    final sequence = sorted;
    final indexById = <String, int>{};
    for (var i = 0; i < sequence.length; i++) {
      indexById[sequence[i].id] = i;
    }

    final byDay = <String, List<_PuzzleRow>>{};
    final dayDate = <String, DateTime>{};

    for (final puzzle in sorted) {
      final date = _dateOnly(puzzle.publishedAt ?? DateTime.now().toUtc());
      final key = _dayKey(date);
      dayDate[key] = date;
      byDay
          .putIfAbsent(key, () => <_PuzzleRow>[])
          .add(
            _PuzzleRow(
              puzzle: puzzle,
              status:
                  merged[puzzle.id] ??
                  const PuzzleProgressStatus(
                    completed: false,
                    inProgress: false,
                    bestSeconds: 0,
                  ),
            ),
          );
    }

    final dayKeys =
        byDay.keys.toList()..sort((a, b) => dayDate[b]!.compareTo(dayDate[a]!));

    final sections = <_PuzzleDaySection>[];
    for (final key in dayKeys) {
      final rows =
          byDay[key]!..sort(
            (a, b) => _difficultyRank(
              a.puzzle.difficulty,
            ).compareTo(_difficultyRank(b.puzzle.difficulty)),
          );
      final solvedCount = rows.where((row) => row.status.completed).length;
      final inProgressCount = rows.where((row) => row.status.inProgress).length;
      sections.add(
        _PuzzleDaySection(
          date: dayDate[key]!,
          rows: rows,
          solvedCount: solvedCount,
          inProgressCount: inProgressCount,
        ),
      );
    }

    final monthSet = <String, DateTime>{};
    for (final s in sections) {
      final m = DateTime(s.date.year, s.date.month, 1);
      monthSet['${m.year}-${m.month}'] = m;
    }
    final months = monthSet.values.toList()..sort((a, b) => a.compareTo(b));
    final currentMonth = DateTime.now();
    var selectedMonthIndex = months.indexWhere(
      (m) => m.year == currentMonth.year && m.month == currentMonth.month,
    );
    if (selectedMonthIndex == -1) {
      selectedMonthIndex = months.length - 1;
    }
    _selectedMonthIndex = selectedMonthIndex.clamp(0, months.length - 1);

    return _PuzzleListData(
      sequence: sequence,
      indexById: indexById,
      sections: sections,
      months: months,
    );
  }

  Future<void> _openPuzzle(
    _PuzzleListData data,
    Puzzle puzzle,
    PuzzleProgressStatus status,
  ) async {
    if (status.completed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Replay solved puzzle?'),
              content: const Text(
                'Your previous result will be replaced with this new run.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Replay'),
                ),
              ],
            ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }

    switch (puzzle.type) {
      case PuzzleType.sudoku:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => SudokuPage(
                  puzzle: puzzle,
                  puzzleSequence: data.sequence,
                  puzzleIndex: data.indexById[puzzle.id] ?? 0,
                ),
          ),
        );
      case PuzzleType.queens:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => QueensPage(puzzle: puzzle)));
      case PuzzleType.kakuro:
      case PuzzleType.nonogram:
      case PuzzleType.minesweeper:
        break;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _future = _load();
    });
  }

  void _jumpToDate(DateTime date) {
    final key = _sectionKeys[_dayKey(_dateOnly(date))];
    if (key?.currentContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  int _difficultyRank(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'hard':
        return 0;
      case 'medium':
        return 1;
      default:
        return 2;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _monthLabel(DateTime month) {
    const names = <String>[
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[month.month]} ${month.year}';
  }

  _DayStreakType _streakType({
    required int solved,
    required int inProgress,
    required int total,
  }) {
    if (total == 0) {
      return _DayStreakType.none;
    }
    if (solved >= total) {
      return _DayStreakType.pro;
    }
    if (solved > 0 || inProgress > 0) {
      return _DayStreakType.basic;
    }
    return _DayStreakType.none;
  }

  Color _streakColor(_DayStreakType streakType) {
    switch (streakType) {
      case _DayStreakType.none:
        return const Color(0xFFC0392B);
      case _DayStreakType.basic:
        return const Color(0xFFB26A00);
      case _DayStreakType.pro:
        return const Color(0xFF198754);
    }
  }

  IconData _streakIcon(_DayStreakType streakType) {
    switch (streakType) {
      case _DayStreakType.none:
        return Icons.radio_button_unchecked;
      case _DayStreakType.basic:
        return Icons.local_fire_department_rounded;
      case _DayStreakType.pro:
        return Icons.workspace_premium_rounded;
    }
  }
}

class _PuzzleListData {
  const _PuzzleListData({
    required this.sequence,
    required this.indexById,
    required this.sections,
    required this.months,
  });

  final List<Puzzle> sequence;
  final Map<String, int> indexById;
  final List<_PuzzleDaySection> sections;
  final List<DateTime> months;

  Map<String, _PuzzleDaySection> datesForMonth(DateTime month) {
    final out = <String, _PuzzleDaySection>{};
    for (final section in sections) {
      if (section.date.year == month.year &&
          section.date.month == month.month) {
        out['${section.date.year}-${section.date.month.toString().padLeft(2, '0')}-${section.date.day.toString().padLeft(2, '0')}'] =
            section;
      }
    }
    return out;
  }
}

class _PuzzleDaySection {
  const _PuzzleDaySection({
    required this.date,
    required this.rows,
    required this.solvedCount,
    required this.inProgressCount,
  });

  final DateTime date;
  final List<_PuzzleRow> rows;
  final int solvedCount;
  final int inProgressCount;

  int get totalCount => rows.length;
}

class _PuzzleRow {
  const _PuzzleRow({required this.puzzle, required this.status});

  final Puzzle puzzle;
  final PuzzleProgressStatus status;
}

enum _DayStreakType { none, basic, pro }

class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _WeekdayCell extends StatelessWidget {
  const _WeekdayCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF7D8D99),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
