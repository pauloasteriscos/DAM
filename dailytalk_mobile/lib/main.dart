import 'package:flutter/material.dart';

import 'data/database/database_factory_config.dart';
import 'screens/auth_gate.dart';

/// Ponto de entrada da aplicação DailyTalk.pt.
///
/// Antes de iniciar a interface gráfica, configuramos a factory da base de dados.
/// Isto é necessário porque:
/// - no Android, o sqflite funciona de forma nativa;
/// - no Web, é necessário inicializar a implementação SQLite/WASM.
Future<void> main() async {
  // Garante que o Flutter está inicializado antes de qualquer operação assíncrona.
  WidgetsFlutterBinding.ensureInitialized();

  // Configura a base de dados conforme a plataforma atual.
  await configureDatabaseFactory();

  // Inicia a aplicação.
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
      home: const AuthGate(),
    );
  }
}