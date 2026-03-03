import 'package:logic_puzzles_app/core/models/user_progress.dart';

abstract class ProgressSyncService {
  Future<void> syncProgress(UserProgress progress);
}

class ProgressSyncException implements Exception {
  const ProgressSyncException(this.message, {this.reasonCode});

  final String message;
  final String? reasonCode;

  @override
  String toString() => message;
}
