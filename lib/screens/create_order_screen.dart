// lib/screens/create_order_screen.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mix_me_app/main.dart';
import 'package:mix_me_app/screens/main_screen.dart';
import 'package:mix_me_app/widgets/background_glow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateOrderScreen extends StatefulWidget {
  final Map<String, dynamic> engineerProfile;
  final Map<String, dynamic> serviceData;

  const CreateOrderScreen({
    super.key,
    required this.engineerProfile,
    required this.serviceData,
  });

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _requirementsController = TextEditingController();
  bool _isLoading = false;

  List<File> _pickedFiles = [];
  List<String> _pickedFileNames = [];

  @override
  void dispose() {
    _requirementsController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null) {
        setState(() {
          _pickedFiles = result.paths.map((path) => File(path!)).toList();
          _pickedFileNames = result.names.map((name) => name!).toList();
        });
      }
    } catch (e) {
      _showError('Ошибка выбора файлов: $e');
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final customerId = supabase.auth.currentUser!.id;
      final engineerId = widget.engineerProfile['id'];
      final price = widget.serviceData['price'];

      final orderResponse = await supabase.from('orders').insert({
        'customer_id': customerId,
        'engineer_id': engineerId,
        'price': price,
        'status': 'pending',
        'requirements': _requirementsController.text.trim(),
      }).select('id');

      final orderId = orderResponse.first['id'];

      if (_pickedFiles.isNotEmpty) {
        for (int i = 0; i < _pickedFiles.length; i++) {
          final file = _pickedFiles[i];
          final fileName = _pickedFileNames[i];
          
          // --- ИСПРАВЛЕНИЕ ---
          String fileExt = 'bin'; // Тип по умолчанию, если нет расширения
          if (fileName.contains('.')) {
              fileExt = fileName.split('.').last.toLowerCase();
              if (fileExt.length > 10) { // Обрезаем слишком длинные расширения
                  fileExt = fileExt.substring(0, 10);
              }
          }
          // --- КОНЕЦ ИСПРАВЛЕНИЯ ---

          final storagePath = '$orderId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

          await supabase.storage.from('project-files').upload(
                storagePath,
                file,
                fileOptions: FileOptions(
                  upsert: false,
                  metadata: {'order_id': orderId},
                ),
              );
          
          final fileUrl = supabase.storage.from('project-files').getPublicUrl(storagePath);

          await supabase.from('order_files').insert({
            'order_id': orderId,
            'uploader_id': customerId,
            'file_name': fileName,
            'file_type': fileExt, // Используем исправленное расширение
            'file_url': fileUrl,
            'storage_path': storagePath,
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заказ успешно создан!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen(initialIndex: 2)),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('*** ОШИБКА ПРИ СОЗДАНИИ ЗАКАЗА: $e');
      _showError('Ошибка при создании заказа: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final engineerName = widget.engineerProfile['username'] ?? 'Инженер';
    final serviceName = widget.serviceData['name'] ?? 'Услуга';
    final servicePrice = widget.serviceData['price'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Оформление заказа'),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Вы заказываете:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.grey.shade800,
                    child: ListTile(
                      leading: const Icon(Icons.music_note_outlined, color: kPrimaryPink, size: 30),
                      title: Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text('У инженера: $engineerName'),
                      trailing: Text('$servicePrice ₽', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Требования и пожелания', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _requirementsController,
                    maxLines: 6,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Опишите ваше видение...',
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Пожалуйста, опишите требования к заказу';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  const Text('Файлы проекта', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_pickedFiles.isNotEmpty)
                    ..._pickedFileNames.map((name) => Card(
                          color: Colors.grey.shade800,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.insert_drive_file_outlined, color: Colors.white70),
                            title: Text(name, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                              onPressed: () {
                                final index = _pickedFileNames.indexOf(name);
                                setState(() {
                                  _pickedFiles.removeAt(index);
                                  _pickedFileNames.removeAt(index);
                                });
                              },
                            ),
                          ),
                        )),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Прикрепить файлы'),
                    onPressed: _pickFiles,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: Colors.grey),
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _submitOrder,
                            child: const Text('Подтвердить и оплатить'),
                          ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}