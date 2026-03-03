import 'dart:convert';

import 'package:logic_puzzles_app/core/models/puzzle_type.dart';

class Puzzle {
  const Puzzle({
    required this.id,
    required this.type,
    required this.title,
    required this.difficulty,
    required this.payload,
    this.isDaily = false,
  });

  final String id;
  final PuzzleType type;
  final String title;
  final String difficulty;
  final Map<String, dynamic> payload;
  final bool isDaily;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'difficulty': difficulty,
        'payload': payload,
        'isDaily': isDaily,
      };

  String toStorageString() => jsonEncode(toJson());

  static Puzzle fromStorageString(String raw) {
    return Puzzle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      id: json['id'] as String,
      type: PuzzleType.values.byName(json['type'] as String),
      title: json['title'] as String,
      difficulty: json['difficulty'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      isDaily: json['isDaily'] as bool? ?? false,
    );
  }
}
