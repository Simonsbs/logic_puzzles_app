import 'package:flutter/material.dart';

class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.puzzleName});

  final String puzzleName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(puzzleName)),
      body: const Center(
        child: Text('Coming soon'),
      ),
    );
  }
}
