import 'package:logic_puzzles_app/core/models/user_progress.dart';

abstract class ProgressSyncService {
  Future<void> syncProgress(UserProgress progress);
}
