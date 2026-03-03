import 'package:flutter/material.dart';
import 'package:logic_puzzles_app/features/home/home_page.dart';

class LogicGamesApp extends StatelessWidget {
  const LogicGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logic Games',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF26667F)),
      ),
      home: const HomePage(),
    );
  }
}
