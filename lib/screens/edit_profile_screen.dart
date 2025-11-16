// lib/screens/edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mix_me_app/main.dart';
import 'package:mix_me_app/screens/add_portfolio_item_screen.dart';
import 'package:mix_me_app/widgets/background_glow.dart';
import 'package:image/image.dart' as img;

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profileData;
  final List<Map<String, dynamic>> initialServices;
  final List<Map<String, dynamic>> initialPortfolio;

  const EditProfileScreen({
    super.key,
    required this.profileData,
    required this.initialServices,
    required this.initialPortfolio,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _experienceController;
  bool _isLoading = false;
  XFile? _imageFile;
  String? _imageUrl;
  final List<String> _allGenres = ['Поп', 'Хип-хоп', 'Рок', 'EDM', 'R&B', 'Джаз', 'Инди', 'Метал'];
  List<String> _selectedGenres = [];

  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _portfolioItems = [];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.profileData['full_name']);
    _bioController = TextEditingController(text: widget.profileData['bio']);
    _experienceController = TextEditingController(text: widget.profileData['experience_years']?.toString() ?? '');
    _imageUrl = widget.profileData['avatar_url'];
    if (widget.profileData['genres'] != null) {
      _selectedGenres = List<String>.from(widget.profileData['genres']);
    }

    _services = List.from(widget.initialServices);
    _portfolioItems = List.from(widget.initialPortfolio);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final isEngineer = widget.profileData['role'] == 'engineer';
      String? newImageUrl;

      if (_imageFile != null) {
        final imageBytes = await _imageFile!.readAsBytes();
        final image = img.decodeImage(imageBytes)!;
        final resizedImage = img.copyResize(image, width: 1024);
        final compressedBytes = img.encodeJpg(resizedImage, quality: 85);

        final filePath = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

        await supabase.storage.from('avatars').uploadBinary(filePath, compressedBytes);

        newImageUrl = supabase.storage.from('avatars').getPublicUrl(filePath);
      }

      await supabase.from('profiles').update({
        'full_name': _fullNameController.text.trim(),
        if (newImageUrl != null) 'avatar_url': newImageUrl,
      }).eq('id', userId);

      if (isEngineer) {
        await supabase.from('engineers').update({
          'bio': _bioController.text.trim(),
          'genres': _selectedGenres,
          'experience_years': int.tryParse(_experienceController.text.trim()),
        }).eq('profile_id', userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль успешно обновлен!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
       _showErrorSnackBar('Ошибка обновления: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePortfolioItem(String itemId, String beforeUrl, String afterUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение'),
        content: const Text('Вы уверены, что хотите удалить эту работу из портфолио? Это действие необратимо.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('portfolios').delete().eq('id', itemId);

      final userId = supabase.auth.currentUser!.id;
      final beforeFileName = beforeUrl.substring(beforeUrl.lastIndexOf(userId));
      final afterFileName = afterUrl.substring(afterUrl.lastIndexOf(userId));

      await supabase.storage.from('portfolio-audio').remove([beforeFileName, afterFileName]);

      setState(() {
        _portfolioItems.removeWhere((item) => item['id'] == itemId);
      });
    } catch (e) {
      _showErrorSnackBar('Не удалось удалить работу: $e');
    }
  }

  Future<void> _refreshPortfolio() async {
     try {
       final userId = supabase.auth.currentUser!.id;
       final response = await supabase.from('portfolios').select().eq('engineer_id', userId).order('created_at', ascending: false);
       if(mounted) {
         setState(() {
           _portfolioItems = List<Map<String, dynamic>>.from(response);
         });
       }
     } catch(e) {
        _showErrorSnackBar('Не удалось обновить портфолио: $e');
     }
  }

  @override
  Widget build(BuildContext context) {
    final isEngineer = widget.profileData['role'] == 'engineer';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
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
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: kPrimaryPink.withOpacity(0.5),
                          backgroundImage: _imageFile != null
                            ? FileImage(File(_imageFile!.path)) as ImageProvider
                            : (_imageUrl != null ? NetworkImage(_imageUrl!) : null),
                          child: _imageFile == null && _imageUrl == null
                            ? const Icon(Icons.person, size: 60, color: Colors.white)
                            : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            backgroundColor: kPrimaryPink,
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                              onPressed: _pickAvatar,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(hintText: 'Полное имя'),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  if (isEngineer) ...[
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(hintText: 'О себе'),
                      maxLines: 5,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _experienceController,
                      decoration: const InputDecoration(hintText: 'Опыт работы (полных лет)'),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    const Text('Жанры, в которых вы работаете', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _allGenres.map((genre) {
                        final isSelected = _selectedGenres.contains(genre);
                        return FilterChip(
                          label: Text(genre), selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) _selectedGenres.add(genre);
                              else _selectedGenres.remove(genre);
                            });
                          },
                          backgroundColor: Colors.grey.shade800, selectedColor: kPrimaryPink,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey[300]),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    const Text('Мое портфолио', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_portfolioItems.isEmpty) const Text('У вас пока нет работ в портфолио.', style: TextStyle(color: Colors.grey)),
                    ..._portfolioItems.map((item) => Card(
                      color: Colors.grey.shade800,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.music_video, color: kPrimaryPink),
                        title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.redAccent.withOpacity(0.7)),
                          onPressed: () => _deletePortfolioItem(item['id'], item['audio_before_url'], item['audio_after_url']),
                        ),
                      ),
                    )),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить работу'),
                        // --- НАЧАЛО ИСПРАВЛЕНИЯ ---
                        onPressed: () async {
                          // Дожидаемся результата от экрана добавления
                          final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(builder: (context) => const AddPortfolioItemScreen()),
                          );
                          // Если результат true (т.е. работа добавлена успешно),
                          // вызываем функцию обновления
                          if (result == true) {
                            _refreshPortfolio();
                          }
                        },
                        // --- КОНЕЦ ИСПРАВЛЕНИЯ ---
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: kPrimaryPink), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    const Text('Мои услуги', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_services.isEmpty) const Text('У вас пока нет добавленных услуг.', style: TextStyle(color: Colors.grey)),
                    ..._services.map((service) => Card(
                      color: Colors.grey.shade800,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.music_note_outlined, color: kPrimaryPink),
                        title: Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${service['price']} ₽', style: TextStyle(color: Colors.grey[300])),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.redAccent.withOpacity(0.7)),
                          onPressed: () => _deleteService(service['id']),
                        ),
                      ),
                    )),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить услугу'),
                        onPressed: _showAddServiceDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: kPrimaryPink),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(vertical: 14)
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _updateProfile,
                            child: const Text('Сохранить изменения'),
                          ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddServiceDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text('Новая услуга', style: TextStyle(color: Colors.white)),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(hintText: 'Название услуги (напр. Сведение)'),
                  validator: (value) => value == null || value.isEmpty ? 'Введите название' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(hintText: 'Цена (напр. 5000)'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.isEmpty ? 'Введите цену' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                if (dialogFormKey.currentState!.validate()) {
                  _addService(nameController.text, int.parse(priceController.text));
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addService(String name, int price) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase.from('services').insert({
        'user_id': userId,
        'name': name.trim(),
        'price': price,
      }).select();

      setState(() {
        _services.add(response.first);
      });
    } catch (e) {
      _showErrorSnackBar('Не удалось добавить услугу: $e');
    }
  }

  Future<void> _deleteService(String serviceId) async {
    try {
      await supabase.from('services').delete().eq('id', serviceId);
      setState(() {
        _services.removeWhere((service) => service['id'] == serviceId);
      });
    } catch (e) {
       _showErrorSnackBar('Не удалось удалить услугу: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}