import 'package:flutter/material.dart';

import 'placeholder_page.dart';

/// Página com as atividades criadas pelo utilizador.
///
/// Nesta fase, ainda é uma estrutura inicial.
class MyActivitiesPage extends StatelessWidget {
  const MyActivitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Minhas atividades',
      message:
          'Aqui serão apresentadas as atividades criadas por ti, o estado de aprovação e a avaliação da comunidade.',
      icon: Icons.folder_special_outlined,
      showBackButton: true,
    );
  }
}