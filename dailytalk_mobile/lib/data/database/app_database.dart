import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Classe central de acesso à base de dados local SQLite.
///
/// Esta implementação usa sqflite diretamente, sem Drift.
/// A base é usada para cache local, submissões pendentes,
/// resultados, análises e fila de sincronização.
class AppDatabase {
  AppDatabase._privateConstructor();

  static final AppDatabase instance = AppDatabase._privateConstructor();

  static const String _databaseName = 'dailytalk_mobile.db';
  static const int _databaseVersion = 1;

  static Database? _database;

  /// Retorna a instância aberta da base de dados.
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  /// Inicializa a base SQLite no diretório padrão da aplicação.
  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Ativa suporte a chaves estrangeiras no SQLite.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Cria as tabelas da versão inicial da base de dados.
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    _createTables(batch);
    _createIndexes(batch);
    _seedInitialSettings(batch);

    await batch.commit(noResult: true);
  }

  /// Ponto de evolução para versões futuras da base.
  ///
  /// Exemplo:
  /// if (oldVersion < 2) { await db.execute('ALTER TABLE ...'); }
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Nesta versão inicial ainda não há migrações.
  }

  /// Fecha a base de dados.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Cria todas as tabelas do modelo local.
  void _createTables(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_activity_id TEXT NOT NULL UNIQUE,
        title TEXT,
        type TEXT NOT NULL,
        scenario TEXT,
        language_code TEXT NOT NULL,
        difficulty TEXT,
        activity_url TEXT,
        source TEXT NOT NULL DEFAULT 'remote',
        is_cached INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_opened_at TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS activity_params (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activity_id INTEGER,
        param_name TEXT NOT NULL,
        param_type TEXT NOT NULL,
        param_value TEXT,
        is_required INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invenira_std_id TEXT NOT NULL UNIQUE,
        display_name TEXT,
        class_name TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_seen_at TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS submissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activity_id INTEGER NOT NULL,
        student_id INTEGER,
        remote_activity_id TEXT NOT NULL,
        submission_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        submitted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_sync_at TEXT,
        FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE SET NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS submission_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        submission_id INTEGER NOT NULL UNIQUE,
        remote_activity_id TEXT NOT NULL,
        score REAL,
        feedback_text TEXT,
        feedback_url TEXT,
        metrics_json TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (submission_id) REFERENCES submissions(id) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS analytics_definitions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        analytics_type TEXT NOT NULL,
        value_type TEXT,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS analytics_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activity_id INTEGER,
        student_id INTEGER,
        remote_activity_id TEXT NOT NULL,
        invenira_std_id TEXT NOT NULL,
        quant_analytics_json TEXT,
        qual_analytics_json TEXT,
        total_interactions INTEGER,
        activity_time_seconds INTEGER,
        student_profile TEXT,
        heatmap_url TEXT,
        fetched_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE SET NULL,
        FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE SET NULL,
        UNIQUE(remote_activity_id, invenira_std_id)
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        method TEXT NOT NULL DEFAULT 'POST',
        payload_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        next_retry_at TEXT,
        processed_at TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        value_type TEXT NOT NULL DEFAULT 'text',
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// Cria índices para acelerar consultas frequentes.
  void _createIndexes(Batch batch) {
    batch.execute('CREATE INDEX IF NOT EXISTS idx_activities_remote_activity_id ON activities(remote_activity_id)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_activity_params_activity_id ON activity_params(activity_id)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_students_invenira_std_id ON students(invenira_std_id)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_submissions_activity_id ON submissions(activity_id)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_submissions_sync_status ON submissions(sync_status)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_submission_results_submission_id ON submission_results(submission_id)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_analytics_records_activity_student ON analytics_records(remote_activity_id, invenira_std_id)');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(sync_status)');
  }

  /// Insere configurações iniciais da aplicação.
  void _seedInitialSettings(Batch batch) {
    final now = DateTime.now().toIso8601String();

    batch.insert('app_settings', {
      'key': 'default_language',
      'value': 'pt-PT',
      'value_type': 'text',
      'updated_at': now,
    });

    batch.insert('app_settings', {
      'key': 'database_version',
      'value': _databaseVersion.toString(),
      'value_type': 'number',
      'updated_at': now,
    });
  }
}
