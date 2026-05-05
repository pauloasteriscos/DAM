import 'package:flutter/material.dart';

import '../models/lesson_item.dart';

/// Estratégia base para os diferentes tipos de atividade.
///
/// Cada tipo de atividade define:
/// - tipo técnico usado na base/API;
/// - nome visível;
/// - ícone;
/// - cor;
/// - forma geométrica;
/// - pergunta predefinida;
/// - dica de resposta;
/// - payload de submissão.
abstract class ActivityStrategy {
  const ActivityStrategy();

  /// Código técnico da atividade usado na base local e na API.
  String get type;

  /// Nome apresentado ao utilizador.
  String get label;

  /// Ícone principal da atividade.
  IconData get icon;

  /// Forma geométrica usada no mapa de atividades.
  NodeShape get shape;

  /// Cor principal da atividade.
  Color get fillColor;

  /// Identificador predefinido usado em atividades mockadas/predefinidas.
  String get predefinedRemoteActivityId;

  /// Pergunta inicial da atividade.
  String get defaultQuestion;

  /// Texto de ajuda no campo de resposta.
  String get answerHint;

  /// Cenário sugerido para a atividade.
  String get defaultScenario;

  /// Dificuldade sugerida.
  String get defaultDifficulty;

  /// Monta a submissão da atividade.
  ///
  /// O formato já fica preparado para ser enviado no POST /submit.
  Map<String, dynamic> buildSubmission({
    required String answerText,
    String nativeLanguageCode = 'pt-PT',
    String targetLanguageCode = 'it-IT',
  }) {
    return {
      'activityType': type,
      'nativeLanguageCode': nativeLanguageCode,
      'targetLanguageCode': targetLanguageCode,
      'submittedAt': DateTime.now().toIso8601String(),
      'answers': [
        {
          'field': 'response',
          'value': answerText,
        },
      ],
    };
  }
}

/// Estratégia para atividade de vocabulário.
class VocabularyActivityStrategy extends ActivityStrategy {
  const VocabularyActivityStrategy();

  @override
  String get type => 'vocabulario';

  @override
  String get label => 'Vocabulário';

  @override
  IconData get icon => Icons.menu_book;

  @override
  NodeShape get shape => NodeShape.roundedSquare;

  @override
  Color get fillColor => Colors.orange;

  @override
  String get predefinedRemoteActivityId => 'PREDEF-VOCABULARIO-001';

  @override
  String get defaultQuestion =>
      'Escreve três palavras úteis para iniciar uma conversa com um colega.';

  @override
  String get answerHint => 'Ex.: olá, obrigado, posso ajudar?';

  @override
  String get defaultScenario => 'vocabulário do quotidiano escolar';

  @override
  String get defaultDifficulty => 'Inicial';
}

/// Estratégia para atividade de áudio.
class AudioActivityStrategy extends ActivityStrategy {
  const AudioActivityStrategy();

  @override
  String get type => 'audio';

  @override
  String get label => 'Áudio';

  @override
  IconData get icon => Icons.headphones;

  @override
  NodeShape get shape => NodeShape.circle;

  @override
  Color get fillColor => Colors.blue;

  @override
  String get predefinedRemoteActivityId => 'PREDEF-AUDIO-001';

  @override
  String get defaultQuestion =>
      'Depois de ouvires a situação, escreve o que responderias.';

  @override
  String get answerHint => 'Ex.: Sim, posso repetir a pergunta.';

  @override
  String get defaultScenario => 'compreensão oral em ambiente escolar';

  @override
  String get defaultDifficulty => 'Inicial';
}

/// Estratégia para atividade de diálogo.
class DialogActivityStrategy extends ActivityStrategy {
  const DialogActivityStrategy();

  @override
  String get type => 'dialogo';

  @override
  String get label => 'Diálogo';

  @override
  IconData get icon => Icons.chat_bubble;

  @override
  NodeShape get shape => NodeShape.hexagon;

  @override
  Color get fillColor => Colors.green;

  @override
  String get predefinedRemoteActivityId => 'PREDEF-DIALOGO-001';

  @override
  String get defaultQuestion =>
      'Como perguntarias a um colega se ele quer almoçar contigo depois da aula?';

  @override
  String get answerHint => 'Ex.: Queres almoçar comigo depois da aula?';

  @override
  String get defaultScenario => 'ambiente escolar';

  @override
  String get defaultDifficulty => 'Inicial';
}

/// Estratégia para atividade de quiz.
class QuizActivityStrategy extends ActivityStrategy {
  const QuizActivityStrategy();

  @override
  String get type => 'quiz';

  @override
  String get label => 'Quiz';

  @override
  IconData get icon => Icons.quiz;

  @override
  NodeShape get shape => NodeShape.diamond;

  @override
  Color get fillColor => Colors.purple;

  @override
  String get predefinedRemoteActivityId => 'PREDEF-QUIZ-001';

  @override
  String get defaultQuestion =>
      'Qual seria uma forma educada de pedir ajuda a um professor?';

  @override
  String get answerHint => 'Ex.: Professor, pode ajudar-me, por favor?';

  @override
  String get defaultScenario => 'perguntas e respostas em sala de aula';

  @override
  String get defaultDifficulty => 'Inicial';
}

/// Estratégia para atividade de revisão.
class ReviewActivityStrategy extends ActivityStrategy {
  const ReviewActivityStrategy();

  @override
  String get type => 'revisao';

  @override
  String get label => 'Revisão';

  @override
  IconData get icon => Icons.refresh;

  @override
  NodeShape get shape => NodeShape.pentagon;

  @override
  Color get fillColor => Colors.teal;

  @override
  String get predefinedRemoteActivityId => 'PREDEF-REVISAO-001';

  @override
  String get defaultQuestion =>
      'Reescreve uma frase que aprendeste hoje usando outras palavras.';

  @override
  String get answerHint => 'Ex.: Posso juntar-me ao vosso grupo?';

  @override
  String get defaultScenario => 'revisão de expressões aprendidas';

  @override
  String get defaultDifficulty => 'Média';
}

/// Estratégia para desafio final.
class FinalChallengeActivityStrategy extends ActivityStrategy {
  const FinalChallengeActivityStrategy();

  @override
  String get type => 'desafio_final';

  @override
  String get label => 'Desafio Final';

  @override
  IconData get icon => Icons.star;

  @override
  NodeShape get shape => NodeShape.star;

  @override
  Color get fillColor => Colors.amber;

  @override
  String get predefinedRemoteActivityId => 'PREDEF-DESAFIO-FINAL-001';

  @override
  String get defaultQuestion =>
      'Cria um pequeno diálogo para combinar um trabalho de grupo com colegas.';

  @override
  String get answerHint =>
      'Ex.: Olá, queres combinar o trabalho de grupo para amanhã?';

  @override
  String get defaultScenario => 'desafio de comunicação integrada';

  @override
  String get defaultDifficulty => 'Avançada';
}

/// Factory simples para escolher a estratégia certa.
///
/// Esta factory evita espalhar switch/case pelas telas.
class ActivityStrategyFactory {
  const ActivityStrategyFactory._();

  static const ActivityStrategy vocabulary = VocabularyActivityStrategy();
  static const ActivityStrategy audio = AudioActivityStrategy();
  static const ActivityStrategy dialog = DialogActivityStrategy();
  static const ActivityStrategy quiz = QuizActivityStrategy();
  static const ActivityStrategy review = ReviewActivityStrategy();
  static const ActivityStrategy finalChallenge = FinalChallengeActivityStrategy();

  /// Lista de estratégias disponíveis no jogo.
  static const List<ActivityStrategy> all = [
    vocabulary,
    audio,
    dialog,
    quiz,
    review,
    finalChallenge,
  ];

  /// Opções que podem ser usadas no formulário de criação/configuração.
  static Map<String, String> get creationOptions {
    return {
      for (final strategy in all) strategy.type: strategy.label,
    };
  }

  /// Obtém uma estratégia a partir do tipo técnico.
  static ActivityStrategy fromType(String type) {
    switch (type) {
      case 'vocabulario':
        return vocabulary;
      case 'audio':
        return audio;
      case 'dialogo':
        return dialog;
      case 'quiz':
        return quiz;
      case 'revisao':
        return review;
      case 'desafio_final':
        return finalChallenge;
      default:
        return dialog;
    }
  }

  /// Obtém uma estratégia a partir do enum usado no mapa da Home.
  static ActivityStrategy fromLessonType(LessonType lessonType) {
    switch (lessonType) {
      case LessonType.vocabulario:
        return vocabulary;
      case LessonType.audio:
        return audio;
      case LessonType.dialogo:
        return dialog;
      case LessonType.quiz:
        return quiz;
      case LessonType.revisao:
        return review;
      case LessonType.desafioFinal:
        return finalChallenge;
    }
  }
}