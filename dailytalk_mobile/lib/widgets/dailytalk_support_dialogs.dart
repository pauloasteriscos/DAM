import 'package:flutter/material.dart';

/// Diálogos comuns de Ajuda e Sobre do DailyTalk.pt.
///
/// Este ficheiro centraliza estes conteúdos para que o menu superior
/// e a página Ajustes apontem sempre para a mesma informação.
class DailyTalkSupportDialogs {
  const DailyTalkSupportDialogs._();

  static const Color _cardColor = Color(0xFF071D2A);

  static void showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Ajuda',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const SingleChildScrollView(
            child: Text(
              'Usa a Home para acompanhar o teu percurso e aceder rapidamente às atividades.\n\n'
              'Em Praticar, responde a atividades predefinidas para treinares comunicação em contexto escolar.\n\n'
              'Em Resultados, acompanha o teu histórico, pontuações e estado de sincronização.\n\n'
              'Em Análises, consulta métricas pedagógicas agregadas, sem dados sensíveis.\n\n'
              'Em Ajustes, podes gerir conta, perfil, idiomas, notas privadas, sincronização e atividades criadas por ti.\n\n'
              'A opção Perfil permite adaptar atividades para Estudante, Anfitrião ou Professor.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  static void showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Sobre o DailyTalk.pt',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const SingleChildScrollView(
            child: Text(
              'O DailyTalk.pt é um serious game para aprendizagem de idiomas, orientado para crianças e jovens em contexto escolar e mobilidade Erasmus+.\n\n'
              'A aplicação ajuda a praticar comunicação em situações reais do quotidiano escolar, através de vocabulário, áudio, diálogos, quizzes e desafios.\n\n'
              'O projeto considera diferentes perfis de utilização, como Estudante, Anfitrião e Professor, para adaptar melhor as atividades ao papel de cada pessoa.\n\n'
              'A aplicação inclui atividades criadas pela equipa DailyTalk.pt e poderá evoluir para aceitar atividades propostas pela comunidade, com validação antes de ficarem disponíveis.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }
}
