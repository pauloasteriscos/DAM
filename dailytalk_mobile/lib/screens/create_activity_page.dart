import 'package:flutter/material.dart';

import 'activity_config_content.dart';
import 'placeholder_page.dart';

/// Página secundária para criação de atividades pelo utilizador.
///
/// Esta funcionalidade não fica no rodapé principal porque o foco inicial
/// da aplicação é praticar atividades já existentes.
class CreateActivityPage extends StatelessWidget {
  const CreateActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Criar atividade',
      message:
          'Cria uma atividade com base nas tuas dificuldades de aprendizagem.',
      icon: Icons.add_circle_outline,
      showBackButton: true,
      child: ActivityConfigContent(),
    );
  }
}