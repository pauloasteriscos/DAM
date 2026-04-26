-- DailyTalk.pt Mobile — SQLite Schema
-- Base local para cache, funcionamento offline básico e sincronização.
-- Preparada para futura migração conceptual para SQL Server via backend/API.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS activities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Identificador da atividade no backend.
    remote_activity_id TEXT NOT NULL UNIQUE,

    -- Campos funcionais da atividade.
    title TEXT,
    type TEXT NOT NULL,
    scenario TEXT,
    language_code TEXT NOT NULL, --Ex.: pt-PT
    difficulty TEXT,

    -- URL devolvida pelo endpoint GET /deploy.
    activity_url TEXT,

    -- Origem: remote, local ou mock.
    source TEXT NOT NULL DEFAULT 'remote',

    -- Flags booleanas em SQLite: 0 = false, 1 = true.
    is_cached INTEGER NOT NULL DEFAULT 0,
    is_active INTEGER NOT NULL DEFAULT 1,

    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    last_opened_at TEXT
);

CREATE TABLE IF NOT EXISTS activity_params (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Pode estar associado a uma atividade específica ou ser genérico.
    activity_id INTEGER,

    -- Estrutura dinâmica vinda de GET /json-params.
    param_name TEXT NOT NULL,
    param_type TEXT NOT NULL,
    param_value TEXT,

    is_required INTEGER NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 0,

    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,

    FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS students (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Identificador externo do aluno, devolvido/usado nas análises.
    invenira_std_id TEXT NOT NULL UNIQUE,

    display_name TEXT,
    class_name TEXT,

    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    last_seen_at TEXT
);

CREATE TABLE IF NOT EXISTS submissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    activity_id INTEGER NOT NULL,
    student_id INTEGER,

    remote_activity_id TEXT NOT NULL,

    -- JSON com as respostas locais a enviar para POST /submit.
    submission_json TEXT NOT NULL,

    -- draft, pending, synced, failed
    sync_status TEXT NOT NULL DEFAULT 'pending',

    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,

    submitted_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    last_sync_at TEXT,

    FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS submission_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    submission_id INTEGER NOT NULL UNIQUE,

    remote_activity_id TEXT NOT NULL,

    -- Resultado devolvido por POST /submit.
    score REAL,
    feedback_text TEXT,
    feedback_url TEXT,
    metrics_json TEXT,

    created_at TEXT NOT NULL,

    FOREIGN KEY (submission_id) REFERENCES submissions(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS analytics_definitions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Código interno da métrica, se existir.
    code TEXT NOT NULL UNIQUE,

    -- Nome apresentado ao professor.
    name TEXT NOT NULL,

    -- quant ou qual
    analytics_type TEXT NOT NULL,

    -- number, text, url, json, etc.
    value_type TEXT,

    description TEXT,

    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS analytics_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    activity_id INTEGER,
    student_id INTEGER,

    remote_activity_id TEXT NOT NULL,
    invenira_std_id TEXT NOT NULL,

    -- Arrays completos devolvidos pelo endpoint POST /analytics.
    quant_analytics_json TEXT,
    qual_analytics_json TEXT,

    -- Campos derivados para listagem rápida no ecrã de análises.
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
);

CREATE TABLE IF NOT EXISTS sync_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Ex.: submission, analytics, activity.
    entity_type TEXT NOT NULL,

    -- ID local da entidade.
    entity_id INTEGER NOT NULL,

    -- Ex.: create, update, upload.
    operation TEXT NOT NULL,

    -- Endpoint remoto: /submit, /analytics, etc.
    endpoint TEXT NOT NULL,

    -- GET, POST, PUT, PATCH, DELETE.
    method TEXT NOT NULL DEFAULT 'POST',

    -- JSON a enviar quando a ligação estiver disponível.
    payload_json TEXT NOT NULL,

    -- pending, processing, synced, failed
    sync_status TEXT NOT NULL DEFAULT 'pending',

    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,

    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    next_retry_at TEXT,
    processed_at TEXT
);

CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value TEXT,
    value_type TEXT NOT NULL DEFAULT 'text',
    updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_activities_remote_activity_id
ON activities(remote_activity_id);

CREATE INDEX IF NOT EXISTS idx_activity_params_activity_id
ON activity_params(activity_id);

CREATE INDEX IF NOT EXISTS idx_students_invenira_std_id
ON students(invenira_std_id);

CREATE INDEX IF NOT EXISTS idx_submissions_activity_id
ON submissions(activity_id);

CREATE INDEX IF NOT EXISTS idx_submissions_sync_status
ON submissions(sync_status);

CREATE INDEX IF NOT EXISTS idx_submission_results_submission_id
ON submission_results(submission_id);

CREATE INDEX IF NOT EXISTS idx_analytics_records_activity_student
ON analytics_records(remote_activity_id, invenira_std_id);

CREATE INDEX IF NOT EXISTS idx_sync_queue_status
ON sync_queue(sync_status);
