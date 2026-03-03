import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logic_puzzles_app/core/models/puzzle_type.dart';
import 'package:logic_puzzles_app/state/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _syncing = false;
  bool _deleting = false;
  bool _clearing = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider).value;
    final userId = user?.id ?? 'guest-local';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: <Widget>[
          _sectionTitle('Account'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'User ID (debug)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    userId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: userId));
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User ID copied')),
                      );
                    },
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Copy user ID'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle('Data'),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading:
                      _syncing
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.sync),
                  title: const Text('Sync data now'),
                  subtitle: const Text(
                    'Refresh puzzles from cloud and update local cache',
                  ),
                  onTap: _syncing ? null : _syncDataNow,
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      _clearing
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.delete_sweep_outlined),
                  title: const Text('Reset local progress'),
                  subtitle: const Text(
                    'Clears this device progress for current user',
                  ),
                  onTap: _clearing ? null : _clearLocalProgress,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle('Danger Zone'),
          Card(
            child: ListTile(
              leading:
                  _deleting
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(
                        Icons.person_remove,
                        color: Color(0xFFC62828),
                      ),
              title: const Text('Delete account'),
              subtitle: const Text(
                'Deletes user and resets cloud + local progress',
              ),
              onTap: _deleting ? null : _deleteAccount,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Delete account is permanent and cannot be undone.',
            style: TextStyle(fontSize: 12, color: Color(0xFF8B3535)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }

  Future<void> _syncDataNow() async {
    setState(() => _syncing = true);
    try {
      final repository = ref.read(puzzleRepositoryProvider);
      for (final type in PuzzleType.values.where((p) => p.isAvailableNow)) {
        await repository.getPuzzles(type);
        ref.invalidate(modeStreakProvider(type));
      }
      ref.invalidate(showcasePuzzlesProvider);
      ref.invalidate(sudokuTypeLeaderboardProvider);
      ref.invalidate(queensTypeLeaderboardProvider);
      ref.invalidate(streakLeaderboardProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data sync complete')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _clearLocalProgress() async {
    final approved = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset local progress?'),
            content: const Text(
              'This will clear local progress and sessions for this user on this device.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Reset'),
              ),
            ],
          ),
    );
    if (approved != true || !mounted) {
      return;
    }

    final userId =
        ref.read(authServiceProvider).currentUser?.id ?? 'guest-local';
    setState(() => _clearing = true);
    try {
      await _clearLocalUserData(userId);
      for (final type in PuzzleType.values.where((p) => p.isAvailableNow)) {
        ref.invalidate(modeStreakProvider(type));
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Local progress reset')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reset failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in first to delete account')),
      );
      return;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete account permanently?'),
            content: const Text(
              'All cloud progress, leaderboard data, and local data for this user will be removed.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete account'),
              ),
            ],
          ),
    );
    if (approved != true || !mounted) {
      return;
    }

    setState(() => _deleting = true);
    try {
      await _clearLocalUserData(user.id);
      await ref.read(authServiceProvider).deleteAccount();
      for (final type in PuzzleType.values) {
        ref.invalidate(modeStreakProvider(type));
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account deleted')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Future<void> _clearLocalUserData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('puzzle_completed_${userId}_') ||
          key.startsWith('sudoku_session_${userId}_')) {
        await prefs.remove(key);
      }
    }
  }
}
