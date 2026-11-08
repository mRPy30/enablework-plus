import 'package:flutter/material.dart';

void main() => runApp(const MainApp());

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EnableWork+ Admin',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('EnableWork+ Admin')),
        body: const SafeArea(
          child: Center(child: Text('Project setup complete.')),
        ),
      ),
    );
  }
}
