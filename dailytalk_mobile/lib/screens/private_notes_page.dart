import 'package:flutter/material.dart';

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
  String? _errorMessage;
  List<Map<String, Object?>> _notes = [];

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
          content: Text('Nota privada guardada apenas neste dispositivo.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B22),
        foregroundColor: Colors.white,
        title: const Text('Notas privadas'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _buildPrivacyWarning(),
              const SizedBox(height: 18),
              _buildForm(),
              const SizedBox(height: 18),
              if (_errorMessage != null) _buildErrorBox(),
              if (_isLoading) const CircularProgressIndicator(),
              if (!_isLoading && _notes.isEmpty) _buildEmptyState(),
              if (_notes.isNotEmpty) _buildNotesList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amberAccent),
      ),
      child: const Column(
        children: [
          Icon(Icons.lock, color: Colors.amberAccent, size: 42),
          SizedBox(height: 10),
          Text(
            'Nota privada local',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Esta nota fica apenas neste dispositivo. '
            'Não será enviada para o servidor e não será sincronizada.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14252D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                label: 'Título',
                hint: 'Ex.: Informação importante',
                icon: Icons.note,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Indica um título para a nota.';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedScenario,
              dropdownColor: const Color(0xFF14252D),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                label: 'Cenário opcional',
                icon: Icons.category,
              ),
              items: CommunicationScenario.values.map((scenario) {
                return DropdownMenuItem<String>(
                  value: scenario.databaseValue,
                  child: Text(scenario.label),
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
              decoration: _inputDecoration(
                label: 'Nota',
                hint: 'Escreve aqui a nota privada...',
                icon: Icons.edit,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Escreve o conteúdo da nota.';
                }

                return null;
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saveNote,
                icon: const Icon(Icons.save),
                label: const Text(
                  'Guardar nota privada',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14252D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: const Text(
        'Ainda não existem notas privadas locais.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, height: 1.4),
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
          decoration: BoxDecoration(
            color: const Color(0xFF14252D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                scenarioLabel,
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                noteText,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 10),
              Text(
                'Atualizada em: $updatedAt',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _deleteNote(id),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Apagar'),
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
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIconColor: Colors.lightBlue,
      filled: true,
      fillColor: const Color(0xFF0D1B22),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white24),
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
