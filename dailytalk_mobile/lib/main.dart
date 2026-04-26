import 'package:flutter/material.dart';

import 'screens/main_navigation.dart';

void main() {
  runApp(const DailyTalkApp());
}

/// Aplicação principal do DailyTalk.pt.
class DailyTalkApp extends StatelessWidget {
  const DailyTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DailyTalk.pt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}