import 'package:flutter/material.dart';

/// Página-base usada por áreas que partilham a mesma estrutura visual.
///
/// Quando [child] é informado, a página funciona como contentor para uma
/// funcionalidade real. Sem [child], apresenta apenas uma mensagem temporária.
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

  static const Color _backgroundColor = Color(0xFF061823);
  static const Color _cardColor = Color(0xFF071D2A);
  static const Color _accentColor = Color(0xFF35C8FF);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _backgroundColor,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.25,
                  colors: [
                    Color(0xFF103653),
                    Color(0xFF061823),
                    Color(0xFF041019),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 180,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.44,
                child: Image.asset(
                  'assets/branding/dailytalk_login_footer.png',
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),

          child == null
              ? _buildSimplePlaceholder(context)
              : _buildPlaceholderWithContent(context),
        ],
      ),
    );
  }

  /// Mantém uma composição simples para páginas ainda temporárias.
  Widget _buildSimplePlaceholder(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (showBackButton) _buildBackButton(context),

            const SizedBox(height: 24),

            _buildHeaderCard(iconSize: 82, titleSize: 30, messageSize: 20),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  /// Usa a mesma identidade visual, mas permite acrescentar conteúdo real.
  Widget _buildPlaceholderWithContent(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 42),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              if (showBackButton) _buildBackButton(context),

              _buildHeaderCard(iconSize: 64, titleSize: 29, messageSize: 17),

              const SizedBox(height: 26),

              child!,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required double iconSize,
    required double titleSize,
    required double messageSize,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF52D8FF),
                  Color(0xFF168CFF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Color(0xFF092333),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: _accentColor,
                size: iconSize * 0.52,
              ),
            ),
          ),

          const SizedBox(height: 14),

          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              height: 1.12,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: messageSize,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
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
