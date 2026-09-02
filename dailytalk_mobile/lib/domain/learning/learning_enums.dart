/// Estado pedagógico visível de uma atividade.
///
/// Este estado é deliberadamente separado de [ProgressSyncState].
enum LearningActivityState { locked, available, inProgress, completed }

/// Estado técnico de sincronização do progresso local.
enum ProgressSyncState { clean, pending, syncing, failed }

/// Origem editorial de uma atividade.
enum ContentOrigin { official, personal, community }

/// Alcance em que uma revisão pode ser consultada.
enum ContentVisibility { private, community, public }

/// Tipo conhecido de atividade executável pelo runtime.
enum LearningActivityType {
  vocabulary,
  dialogue,
  speech,
  quiz,
  review,
  integratedChallenge,
}

/// Natureza de um elemento apresentado no percurso.
enum PathElementType { activity, checkpoint, scene, reward }

/// Preferência de prática; não altera a disponibilidade curricular.
enum PracticePreference { balanced, vocabulary, dialogue, speech }

/// Operador lógico aplicado a um grupo de pré-requisitos.
enum PrerequisiteOperator { all, any }
