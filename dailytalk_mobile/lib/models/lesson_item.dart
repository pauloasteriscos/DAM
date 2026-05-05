/// Tipos de atividade disponíveis no percurso gamificado.
enum LessonType { audio, dialogo, vocabulario, quiz, revisao, desafioFinal }

/// Estados possíveis da atividade.
enum LessonStatus { completed, current, available, locked }

/// Formas geométricas possíveis para cada nó do percurso.
enum NodeShape { circle, roundedSquare, diamond, pentagon, hexagon, star }

/// Modelo simples para representar uma atividade no percurso.
class LessonItem {
  final String title;
  final LessonType type;
  final LessonStatus status;

  const LessonItem({
    required this.title,
    required this.type,
    required this.status,
  });
}
