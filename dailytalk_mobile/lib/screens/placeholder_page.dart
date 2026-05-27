import 'package:flutter/material.dart';

import '../widgets/top_overflow_menu.dart';

/// Página-base usada por áreas que partilham a mesma estrutura visual.
///
/// Quando [child] é informado, a página funciona como contentor para uma
/// funcionalidade real. Sem [child], apresenta apenas uma mensagem temporária.
///
/// Esta versão garante:
/// - cabeçalho superior consistente com marca e menu de três pontos;
/// - botão de voltar em páginas abertas por Navigator.push;
/// - conteúdo centrado em Web/desktop;
/// - largura máxima controlada para evitar alinhamento à esquerda.
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

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: child == null
                      ? _buildSimplePlaceholder(context)
                      : _buildPlaceholderWithContent(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Cabeçalho superior com marca, botão de voltar opcional e menu.
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              tooltip: 'Voltar',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            )
          else
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF06345C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _accentColor.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.menu_book,
                color: Colors.amber,
                size: 28,
              ),
            ),

          const SizedBox(width: 12),

          const Expanded(
            child: Text(
              'DailyTalk.pt',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const TopOverflowMenu(),
        ],
      ),
    );
  }

  /// Mantém uma composição simples para páginas ainda temporárias.
  Widget _buildSimplePlaceholder(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 42),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeaderCard(iconSize: 82, titleSize: 30, messageSize: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Usa a mesma identidade visual, mas permite acrescentar conteúdo real.
  Widget _buildPlaceholderWithContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 42),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
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
}
