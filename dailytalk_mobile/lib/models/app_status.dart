/// Estados de sincronização de uma submissão.
///
/// Estes valores devem ser usados em vez de strings soltas como:
/// 'pending', 'synced' e 'failed'.
enum SubmissionSyncStatus {
  pending(
    databaseValue: 'pending',
    label: 'Pendente',
  ),
  synced(
    databaseValue: 'synced',
    label: 'Sincronizado',
  ),
  failed(
    databaseValue: 'failed',
    label: 'Falhou',
  );

  const SubmissionSyncStatus({
    required this.databaseValue,
    required this.label,
  });

  final String databaseValue;
  final String label;

  static SubmissionSyncStatus fromDatabase(String? value) {
    return tryFromDatabase(value) ?? SubmissionSyncStatus.pending;
  }

  static SubmissionSyncStatus? tryFromDatabase(String? value) {
    if (value == null) {
      return null;
    }

    for (final status in SubmissionSyncStatus.values) {
      if (status.databaseValue == value) {
        return status;
      }
    }

    return null;
  }
}

/// Estado de uma atividade criada pela comunidade.
///
/// Estes estados serão úteis para "Minhas atividades".
enum CommunityActivityStatus {
  draft(
    databaseValue: 'draft',
    label: 'Rascunho',
  ),
  underReview(
    databaseValue: 'under_review',
    label: 'Em revisão',
  ),
  approved(
    databaseValue: 'approved',
    label: 'Aprovada',
  ),
  rejected(
    databaseValue: 'rejected',
    label: 'Rejeitada',
  );

  const CommunityActivityStatus({
    required this.databaseValue,
    required this.label,
  });

  final String databaseValue;
  final String label;

  static CommunityActivityStatus fromDatabase(String? value) {
    return tryFromDatabase(value) ?? CommunityActivityStatus.draft;
  }

  static CommunityActivityStatus? tryFromDatabase(String? value) {
    if (value == null) {
      return null;
    }

    for (final status in CommunityActivityStatus.values) {
      if (status.databaseValue == value) {
        return status;
      }
    }

    return null;
  }
}

/// Origem de uma atividade.
///
/// Ajuda a distinguir atividades criadas pela equipa, predefinidas,
/// criadas pela comunidade ou locais.
enum ActivitySourceType {
  developer(
    databaseValue: 'developer',
    label: 'Equipa DailyTalk.pt',
  ),
  predefined(
    databaseValue: 'predefined',
    label: 'Predefinida',
  ),
  community(
    databaseValue: 'community',
    label: 'Comunidade',
  ),
  local(
    databaseValue: 'local',
    label: 'Local',
  );

  const ActivitySourceType({
    required this.databaseValue,
    required this.label,
  });

  final String databaseValue;
  final String label;

  static ActivitySourceType fromDatabase(String? value) {
    return tryFromDatabase(value) ?? ActivitySourceType.local;
  }

  static ActivitySourceType? tryFromDatabase(String? value) {
    if (value == null) {
      return null;
    }

    for (final source in ActivitySourceType.values) {
      if (source.databaseValue == value) {
        return source;
      }
    }

    return null;
  }
}