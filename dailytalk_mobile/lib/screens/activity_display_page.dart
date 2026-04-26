import 'package:flutter/material.dart';

/// Página simples para exibir a atividade iniciada.
///
/// Nesta Sprint 1, mostra a URL devolvida pelo deploy.
/// Mais tarde pode ser substituída por uma WebView.
class ActivityDisplayPage extends StatelessWidget {
  const ActivityDisplayPage({
    super.key,
    required this.activityUrl,
  });

  final String activityUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B22),
        foregroundColor: Colors.white,
        title: const Text('Atividade'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF14252D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white12,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_circle_fill,
                  color: Colors.lightBlue,
                  size: 82,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Atividade iniciada com sucesso.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'URL devolvida pelo deploy:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  activityUrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}