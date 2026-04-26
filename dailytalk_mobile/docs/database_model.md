# Modelo de base de dados local — DailyTalk.pt Mobile

## Objetivo

A base de dados local SQLite serve para:

1. guardar cache de atividades e parâmetros;
2. permitir funcionamento básico sem rede;
3. guardar submissões pendentes;
4. guardar resultados recebidos do backend;
5. suportar a área de análises do professor;
6. preparar sincronização posterior.

## Tabelas

### `activities`

Representa a atividade configurada, executada ou cacheada localmente.

Usada nos ecrãs:

- Nova Atividade;
- Atividade;
- Meus Resultados;
- Análises.

Campos importantes:

- `remote_activity_id`;
- `type`;
- `scenario`;
- `language_code`;
- `difficulty`;
- `activity_url`.

### `activity_params`

Guarda os parâmetros dinâmicos obtidos por `GET /json-params`.

Exemplo:

```json
[
  { "name": "scenario", "type": "text/plain" },
  { "name": "language", "type": "text/plain" }
]
```

### `students`

Guarda alunos identificados pelo campo `inveniraStdID`, usado nas análises.

### `submissions`

Guarda submissões feitas ou ainda pendentes de envio para `POST /submit`.

Estados recomendados:

- `draft`;
- `pending`;
- `synced`;
- `failed`.

### `submission_results`

Guarda a resposta do backend após `POST /submit`.

Campos esperados:

- `score`;
- `feedback_text`;
- `feedback_url`;
- `metrics_json`.

### `analytics_definitions`

Guarda a estrutura de métricas recebida de `GET /analytics-list`.

### `analytics_records`

Guarda os resultados recebidos de `POST /analytics`, por atividade e por aluno.

Campos úteis para o ecrã do professor:

- `invenira_std_id`;
- `total_interactions`;
- `activity_time_seconds`;
- `student_profile`;
- `heatmap_url`.

### `sync_queue`

Fila de sincronização local para dados que precisam ser enviados quando a rede voltar.

### `app_settings`

Configurações locais simples, como idioma padrão, última sincronização, modo debug, etc.

## Observação importante

Tokens, passwords, API keys e credenciais não devem ser guardados no SQLite. Para isso, usar `flutter_secure_storage`.
