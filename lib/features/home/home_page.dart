import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logic_puzzles_app/core/models/leaderboard_entry.dart';
import 'package:logic_puzzles_app/core/services/auth_service.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/features/coming_soon/coming_soon_page.dart';
import 'package:logic_puzzles_app/features/home/puzzle_type_card.dart';
import 'package:logic_puzzles_app/features/puzzles/puzzle_list_page.dart';
import 'package:logic_puzzles_app/features/settings/settings_page.dart';
import 'package:logic_puzzles_app/state/app_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider).value;
    final config = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Puzzle Quest')),
      drawer: _AppDrawer(user: user),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFE9F6F0), Color(0xFFF4F7F5)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: <Widget>[
              _HeroPanel(
                userName: user?.displayName,
                modeLabel:
                    config.supabaseEnabled ? 'Cloud Sync On' : 'Local Mode',
              ),
              const SizedBox(height: 18),
              Text(
                'Choose a puzzle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...PuzzleType.values.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PuzzleTypeTile(
                    type: type,
                    onTap: () => _openPuzzleType(context, type),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Leaderboards',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _LeaderboardSection(
                title: 'Sudoku',
                provider: sudokuTypeLeaderboardProvider,
              ),
              _LeaderboardSection(
                title: 'Queens',
                provider: queensTypeLeaderboardProvider,
              ),
              _LeaderboardSection(
                title: 'Daily streaks',
                provider: streakLeaderboardProvider,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPuzzleType(BuildContext context, PuzzleType type) {
    switch (type) {
      case PuzzleType.sudoku:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PuzzleListPage(type: PuzzleType.sudoku),
          ),
        );
      case PuzzleType.queens:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PuzzleListPage(type: PuzzleType.queens),
          ),
        );
      case PuzzleType.kakuro:
      case PuzzleType.nonogram:
      case PuzzleType.minesweeper:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ComingSoonPage(puzzleName: type.displayName),
          ),
        );
    }
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer({required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            UserAccountsDrawerHeader(
              margin: EdgeInsets.zero,
              decoration: const BoxDecoration(color: Color(0xFF0B6E4F)),
              accountName: Text(user?.displayName ?? 'Guest'),
              accountEmail: Text(
                user?.email.isNotEmpty == true ? user!.email : 'Not signed in',
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: const Color(0xFFBDE8D6),
                child: Icon(
                  user == null ? Icons.person_outline : Icons.person,
                  color: const Color(0xFF0D2A22),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
              },
            ),
            ListTile(
              leading: Icon(user == null ? Icons.login : Icons.logout),
              title: Text(user == null ? 'Sign in with Google' : 'Sign out'),
              onTap: () async {
                Navigator.of(context).pop();
                await _toggleAuth(context, ref);
              },
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Free forever. No ads. No subscription.',
                style: TextStyle(fontSize: 12, color: Color(0xFF5D6C66)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _toggleAuth(BuildContext context, WidgetRef ref) async {
  final auth = ref.read(authServiceProvider);
  try {
    if (auth.currentUser == null) {
      await auth.signInWithGoogle();
      return;
    }
    await auth.signOut();
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$error')));
  }
}

class _PuzzleTypeTile extends ConsumerWidget {
  const _PuzzleTypeTile({required this.type, required this.onTap});

  final PuzzleType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(modeStreakProvider(type)).valueOrNull;
    return PuzzleTypeCard(type: type, onTap: onTap, streak: streak);
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.userName, required this.modeLabel});

  final String? userName;
  final String modeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF123D2E), Color(0xFF1A7A5A)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            userName == null
                ? 'Play free forever. No ads.'
                : 'Welcome back, $userName',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Sudoku and Queens are live now. More puzzle types are on the way.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFE6FFF5)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              modeLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardSection extends ConsumerWidget {
  const _LeaderboardSection({required this.title, required this.provider});

  final String title;
  final FutureProvider<List<LeaderboardEntry>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(provider);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x11000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          data.when(
            data:
                (rows) => Column(
                  children:
                      rows
                          .map(
                            (row) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: const Color(0xFFE9F6F0),
                                    child: Text(
                                      '${row.rank}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(row.userName)),
                                  Text('${row.score} ${row.label}'),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Failed to load leaderboard'),
          ),
        ],
      ),
    );
  }
}
