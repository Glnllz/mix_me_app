import 'dart:io';
import 'dart:typed_data'; // <<< ДОБАВЛЕН ИМПОРТ
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // <<< ДОБАВЛЕН ИМПОРТ
import 'package:flutter/material.dart';
import 'package:mix_me_app/main.dart';
import 'package:mix_me_app/widgets/background_glow.dart';

class AddPortfolioItemScreen extends StatefulWidget {
  const AddPortfolioItemScreen({super.key});

  @override
  State<AddPortfolioItemScreen> createState() => _AddPortfolioItemScreenState();
}

class _AddPortfolioItemScreenState extends State<AddPortfolioItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // <<< НАЧАЛО ИЗМЕНЕНИЯ: МЕНЯЕМ ТИП ХРАНЕНИЯ ФАЙЛОВ >>>
  PlatformFile? _beforeAudioFile;
  PlatformFile? _afterAudioFile;
  // <<< КОНЕЦ ИЗМЕНЕНИЯ >>>

  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAudio(bool isBefore) async {
    try {
      // <<< ИЗМЕНЕНИЕ: ПРОСИМ ЗАГРУЖАТЬ БАЙТЫ >>>
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true,
      );
      if (result != null) {
        setState(() {
          if (isBefore) {
            _beforeAudioFile = result.files.single;
          } else {
            _afterAudioFile = result.files.single;
          }
        });
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка выбора файла: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _submitPortfolioItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_beforeAudioFile == null || _afterAudioFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пожалуйста, загрузите оба аудиофайла ("до" и "после")'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;

      // --- Загрузка файла "до" ---
      final beforeExt = _beforeAudioFile!.name.split('.').last;
      final beforePath = '$userId/${DateTime.now().millisecondsSinceEpoch}_before.$beforeExt';
      
      // <<< НАЧАЛО ИЗМЕНЕНИЯ: УМНАЯ ЗАГРУЗКА >>>
      if (kIsWeb) {
        await supabase.storage.from('portfolio-audio').uploadBinary(beforePath, _beforeAudioFile!.bytes!);
      } else {
        await supabase.storage.from('portfolio-audio').upload(beforePath, File(_beforeAudioFile!.path!));
      }
      // <<< КОНЕЦ ИЗМЕНЕНИЯ >>>
      
      final beforeUrl = supabase.storage.from('portfolio-audio').getPublicUrl(beforePath);

      // --- Загрузка файла "после" ---
      final afterExt = _afterAudioFile!.name.split('.').last;
      final afterPath = '$userId/${DateTime.now().millisecondsSinceEpoch}_after.$afterExt';
      
      // <<< НАЧАЛО ИЗМЕНЕНИЯ: УМНАЯ ЗАГРУЗКА >>>
      if (kIsWeb) {
        await supabase.storage.from('portfolio-audio').uploadBinary(afterPath, _afterAudioFile!.bytes!);
      } else {
        await supabase.storage.from('portfolio-audio').upload(afterPath, File(_afterAudioFile!.path!));
      }
      // <<< КОНЕЦ ИЗМЕНЕНИЯ >>>
      
      final afterUrl = supabase.storage.from('portfolio-audio').getPublicUrl(afterPath);

      // --- Сохранение ссылок в базу данных ---
      await supabase.from('portfolios').insert({
        'engineer_id': userId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'audio_before_url': beforeUrl,
        'audio_after_url': afterUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Работа успешно добавлена в портфолио!'), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая работа'),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          const BackgroundGlow(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(controller: _titleController, style: const TextStyle(color: Colors.black), decoration: const InputDecoration(hintText: 'Название работы (напр. Рок-баллада)'), validator: (v) => v == null || v.isEmpty ? 'Введите название' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _descriptionController, style: const TextStyle(color: Colors.black), decoration: const InputDecoration(hintText: 'Краткое описание проделанной работы'), maxLines: 4),
                  const SizedBox(height: 24),
                  
                  const Text('Аудиофайлы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  Card(
                    color: Colors.grey.shade800,
                    child: ListTile(
                      leading: Icon(Icons.mic_off_outlined, color: _beforeAudioFile != null ? Colors.orange : Colors.grey),
                      title: const Text('Аудио "ДО"'),
                      // <<< ИЗМЕНЕНИЕ: ИСПОЛЬЗУЕМ .name >>>
                      subtitle: Text(_beforeAudioFile?.name ?? 'Файл не выбран', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _beforeAudioFile != null ? Colors.white : Colors.grey)),
                      trailing: const Icon(Icons.upload_file),
                      onTap: () => _pickAudio(true),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.grey.shade800,
                    child: ListTile(
                      leading: Icon(Icons.mic_outlined, color: _afterAudioFile != null ? Colors.greenAccent : Colors.grey),
                      title: const Text('Аудио "ПОСЛЕ"'),
                      // <<< ИЗМЕНЕНИЕ: ИСПОЛЬЗУЕМ .name >>>
                      subtitle: Text(_afterAudioFile?.name ?? 'Файл не выбран', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _afterAudioFile != null ? Colors.white : Colors.grey)),
                      trailing: const Icon(Icons.upload_file),
                      onTap: () => _pickAudio(false),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(onPressed: _submitPortfolioItem, child: const Text('Добавить работу'))
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}