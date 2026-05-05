import 'package:flutter/material.dart';

/// Conteúdo inicial da página de Análises.
///
/// Esta área será usada sobretudo pelo professor para consultar métricas
/// de desempenho por atividade e por aluno.
class AnalyticsContent extends StatelessWidget {
  const AnalyticsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoCard(
          icon: Icons.school,
          title: 'Área do professor',
          description:
              'Aqui serão apresentadas métricas agregadas por atividade e por aluno.',
        ),
        const SizedBox(height: 14),
        _InfoCard(
          icon: Icons.bar_chart,
          title: 'Métricas quantitativas',
          description:
              'Total de interações, tempo de atividade, pontuação e evolução.',
        ),
        const SizedBox(height: 14),
        _InfoCard(
          icon: Icons.psychology_alt,
          title: 'Métricas qualitativas',
          description:
              'Perfil do estudante, dificuldades recorrentes e feedback pedagógico.',
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'A integração com /analytics será implementada na próxima etapa.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.analytics),
            label: const Text(
              'Carregar análises',
              style: TextStyle(fontSize: 17),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14252D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.lightBlueAccent,
            size: 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}