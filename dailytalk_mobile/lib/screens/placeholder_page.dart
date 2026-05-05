import 'package:flutter/material.dart';

/// Página temporária usada enquanto as telas reais ainda não foram desenvolvidas.
///
/// Também pode receber um conteúdo adicional através de [child],
/// permitindo evoluir a página sem perder a estrutura visual já criada.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.child,
    this.showBackButton = false,
  });

  final String title;
  final String message;
  final IconData icon;

  /// Conteúdo adicional opcional da página.
  final Widget? child;

  /// Define se a página deve mostrar um botão de voltar.
  ///
  /// Útil quando a página é aberta por Navigator.push,
  /// como no menu "Criar atividade".
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0D1B22),
      child: child == null
          ? _buildSimplePlaceholder(context)
          : _buildPlaceholderWithContent(context),
    );
  }

  /// Mantém o visual original das páginas que ainda são apenas placeholder.
  Widget _buildSimplePlaceholder(BuildContext context) {
    return SafeArea(
      child: Container(
        color: const Color(0xFF0D1B22),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (showBackButton) _buildBackButton(context),

            const SizedBox(height: 24),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w600,
              ),
            ),

            const Spacer(),

            Icon(icon, color: Colors.lightBlue, size: 90),

            const SizedBox(height: 24),

            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 22,
                height: 1.4,
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  /// Usa a mesma identidade visual, mas permite acrescentar conteúdo real.
  Widget _buildPlaceholderWithContent(BuildContext context) {
    return SafeArea(
      child: Container(
        color: const Color(0xFF0D1B22),
        width: double.infinity,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (showBackButton) _buildBackButton(context),

              const SizedBox(height: 24),

              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 20),

              Icon(icon, color: Colors.lightBlue, size: 72),

              const SizedBox(height: 18),

              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 28),

              child!,
            ],
          ),
        ),
      ),
    );
  }

  /// Botão de voltar usado quando a página é aberta fora da navegação principal.
  Widget _buildBackButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
      ),
    );
  }
}
