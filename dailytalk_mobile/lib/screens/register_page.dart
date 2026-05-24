import 'package:flutter/material.dart';

import '../data/repositories/auth_repository.dart';

/// Página de criação de conta do DailyTalk.pt.
class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.onAuthenticated,
  });

  final VoidCallback onAuthenticated;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();

  String _selectedRole = 'student';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authRepository.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
      );

      if (!mounted) {
        return;
      }

      widget.onAuthenticated();
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B22),
        foregroundColor: Colors.white,
        title: const Text('Criar conta'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.person_add_alt_1, color: Colors.lightBlueAccent, size: 64),
                    const SizedBox(height: 14),
                    const Text(
                      'Criar perfil DailyTalk.pt',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nome',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return 'Indica o nome.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Indica um email válido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'A password deve ter pelo menos 6 caracteres.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      dropdownColor: const Color(0xFF14252D),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Perfil inicial',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.person_pin_circle, color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF14252D),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'student', child: Text('Estudante')),
                        DropdownMenuItem(value: 'host', child: Text('Anfitrião')),
                        DropdownMenuItem(value: 'teacher', child: Text('Professor')),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedRole = value;
                        });
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      _buildErrorBox(_errorMessage!),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _register,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isLoading ? 'A criar...' : 'Criar conta'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF14252D),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Text(message, style: const TextStyle(color: Colors.redAccent)),
    );
  }
}
