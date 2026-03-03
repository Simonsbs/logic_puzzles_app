import 'package:logic_puzzles_app/core/models/user_progress.dart';
import 'package:logic_puzzles_app/core/services/progress_sync_service.dart';

class MockProgressSyncService implements ProgressSyncService {
  @override
  Future<void> syncProgress(UserProgress progress) async {
    // TODO: replace with backend write. For now this is a local no-op.
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}
