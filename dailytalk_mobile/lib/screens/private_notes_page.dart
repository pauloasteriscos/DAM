import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/dao/local_private_notes_dao.dart';
import '../data/database/app_database.dart';
import '../models/communication_scenario.dart';

/// Página de notas privadas locais.
///
/// Estas notas são opcionais e ficam apenas no dispositivo.
/// Não são enviadas ao servidor e não entram na fila de sincronização.
class PrivateNotesPage extends StatefulWidget {
  const PrivateNotesPage({super.key});

  @override
  State<PrivateNotesPage> createState() => _PrivateNotesPageState();
}

class _PrivateNotesPageState extends State<PrivateNotesPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedScenario;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  List<Map<String, Object?>> _notes = [];

  static const Color _backgroundColor = Color(0xFF061823);
  static const Color _cardColor = Color(0xFF071D2A);
  static const Color _fieldColor = Color(0xFF061823);
  static const Color _accentColor = Color(0xFF35C8FF);

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Carrega as notas guardadas apenas neste dispositivo.
  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = await AppDatabase.instance.database;
      final dao = LocalPrivateNotesDao(db);

      final notes = await dao.getRecentNotes();

      if (!mounted) {
        return;
      }

      setState(() {
        _notes = notes;
      });
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

  /// Guarda uma nova nota privada local.
  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final db = await AppDatabase.instance.database;
      final dao = LocalPrivateNotesDao(db);

      await dao.createNote(
        title: _titleController.text.trim(),
        noteText: _noteController.text.trim(),
        scenario: _selectedScenario,
      );

      _titleController.clear();
      _noteController.clear();

      setState(() {
        _selectedScenario = null;
      });

      await _loadNotes();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Nota privada guardada apenas neste dispositivo.'),
        ),
      );
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
          _isSaving = false;
        });
      }
    }
  }

  /// Apaga uma nota privada local.
  Future<void> _deleteNote(int id) async {
    final db = await AppDatabase.instance.database;
    final dao = LocalPrivateNotesDao(db);

    await dao.deleteNote(id);
    await _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 760;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: const AppText(
          'Notas privadas',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
      ),
      body: Stack(
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
            height: isCompact ? 160 : 205,
            child: IgnorePointer(
              child: Opacity(
                opacity: isCompact ? 0.42 : 0.54,
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
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                18,
                isCompact ? 10 : 18,
                18,
                isCompact ? 40 : 54,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      _buildPrivacyWarning(isCompact: isCompact),
                      const SizedBox(height: 18),
                      _buildForm(),
                      const SizedBox(height: 18),
                      if (_errorMessage != null) _buildErrorBox(),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(color: _accentColor),
                        ),
                      if (!_isLoading && _notes.isEmpty) _buildEmptyState(),
                      if (_notes.isNotEmpty) _buildNotesList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyWarning({required bool isCompact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 16 : 18),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.70)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: isCompact ? 64 : 74,
            height: isCompact ? 64 : 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.withValues(alpha: 0.14),
              border: Border.all(
                color: Colors.amberAccent.withValues(alpha: 0.70),
              ),
            ),
            child: const Icon(
              Icons.lock_outline,
              color: Colors.amberAccent,
              size: 38,
            ),
          ),

          const SizedBox(height: 12),

          const AppText(
            'Nota privada local',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          AppText(
            'Estas notas ficam apenas neste dispositivo. Não são enviadas para o servidor e não entram na sincronização.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              cursorColor: _accentColor,
              decoration: _inputDecoration(
                label: 'Título',
                hint: 'Ex.: Informação importante',
                icon: Icons.note_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('Indica um título para a nota.');
                }

                return null;
              },
            ),

            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: _selectedScenario,
              dropdownColor: const Color(0xFF102A38),
              iconEnabledColor: Colors.white.withValues(alpha: 0.74),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                label: 'Cenário opcional',
                icon: Icons.category_outlined,
              ),
              items: CommunicationScenario.values.map((scenario) {
                return DropdownMenuItem<String>(
                  value: scenario.databaseValue,
                  child: AppText(scenario.label),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedScenario = value;
                });
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: _noteController,
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(color: Colors.white),
              cursorColor: _accentColor,
              decoration: _inputDecoration(
                label: 'Nota',
                hint: 'Escreve aqui a nota privada...',
                icon: Icons.edit_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('Escreve o conteúdo da nota.');
                }

                return null;
              },
            ),

            const SizedBox(height: 18),

            _buildPrimaryButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: _isSaving
              ? LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.14),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF49D7FF), Color(0xFF168CFF)],
                ),
          boxShadow: _isSaving
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF168CFF).withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveNote,
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined, size: 23),
          label: AppText(
            _isSaving ? 'A guardar...' : 'Guardar nota privada',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: AppText(
        'Ainda não existem notas privadas locais.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.70),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildNotesList() {
    return Column(
      children: _notes.map((note) {
        final id = note['id'] as int;
        final title = note['title']?.toString() ?? 'Nota';
        final noteText = note['note_text']?.toString() ?? '';
        final scenario = note['scenario']?.toString();
        final updatedAt = note['updated_at']?.toString() ?? '-';

        final scenarioLabel = scenario == null
            ? 'Sem cenário'
            : CommunicationScenario.fromDatabase(scenario).label;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppText(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.lock_outline,
                    color: Colors.amberAccent.withValues(alpha: 0.82),
                    size: 20,
                  ),
                ],
              ),

              const SizedBox(height: 6),

              AppText(
                scenarioLabel,
                style: const TextStyle(
                  color: _accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 10),

              AppText(
                noteText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 10),

              AppText(
                'Atualizada em: $updatedAt',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _deleteNote(id),
                  icon: const Icon(Icons.delete_outline),
                  label: const AppText('Apagar'),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: context.tr(label),
      hintText: hint == null ? null : context.tr(hint),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 8),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.72),
          size: 26,
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 56, minHeight: 56),
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.66),
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.38)),
      filled: true,
      fillColor: _fieldColor.withValues(alpha: 0.76),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.20),
          width: 1.25,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: _accentColor, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.35),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.85)),
      ),
      child: AppText(
        _errorMessage!,
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _cardColor.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.14),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
