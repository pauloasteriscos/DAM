import 'package:flutter/material.dart';

import 'data/database/app_database.dart';
import 'data/dao/activity_dao.dart';

void main() async {
  // Garante que o Flutter está inicializado antes de usar recursos nativos,
  // como o SQLite através do pacote sqflite.
  WidgetsFlutterBinding.ensureInitialized();

  // Abre ou cria a base de dados local da aplicação.
  final db = await AppDatabase.instance.database;

  // Cria o DAO responsável pelas operações da tabela activities.
  final activityDao = ActivityDao(db);

  // Insere ou atualiza uma atividade de teste.
  // Este registo serve apenas para validar se a base SQLite está a funcionar.
  await activityDao.upsertActivity({
    'remote_activity_id': 'TEST-QUIZ-001',
    'title': 'Diálogo em sala de aula',
    'type': 'quiz',
    'scenario': 'sala de aula',
    'language_code': 'pt-PT',
    'difficulty': 'iniciante',
    'source': 'mock',
    'is_cached': 1,
    'is_active': 1,
  });

  // Lê todas as atividades ativas guardadas localmente.
  final activities = await activityDao.getActiveActivities();

  // Mostra o resultado no terminal/debug console.
  debugPrint('Atividades locais encontradas: ${activities.length}');
  debugPrint('Conteúdo das atividades: $activities');

  // Inicia a aplicação Flutter, passando a quantidade de atividades encontradas.
  runApp(MyApp(activityCount: activities.length));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.activityCount,
  });

  // Quantidade de atividades encontradas na base local.
  final int activityCount;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DailyTalk.pt Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: HomePage(activityCount: activityCount),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.activityCount,
  });

  // Valor recebido depois do teste de leitura da base SQLite.
  final int activityCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DailyTalk.pt Mobile'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Base de dados SQLite OK.\n'
            'Atividades locais encontradas: $activityCount',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
    );
  }
}