import 'package:flutter/material.dart';

import '../data/repositories/auth_repository.dart';
import '../models/auth_user.dart';
import 'auth_gate.dart';

/// Página de conta do utilizador autenticado.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final AuthRepository _authRepository = AuthRepository();

  late Future<AuthUser?> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _authRepository.getCurrentUser();
  }

  Future<void> _logout() async {
    await _authRepository.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B22),
        foregroundColor: Colors.white,
        title: const Text('Conta'),
      ),
      body: FutureBuilder<AuthUser?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;

          if (user == null) {
            return const Center(
              child: Text(
                'Sessão não encontrada.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14252D),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.account_circle, color: Colors.lightBlueAccent, size: 72),
                        const SizedBox(height: 12),
                        Text(
                          user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(user.email, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                        _InfoRow(label: 'Perfil', value: user.preferences.selectedProfile),
                        _InfoRow(label: 'Idioma da app', value: user.preferences.appLanguageCode),
                        _InfoRow(label: 'Idioma de aprendizagem', value: user.preferences.learningLanguageCode),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Terminar sessão'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
