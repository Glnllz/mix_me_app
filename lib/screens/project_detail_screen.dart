import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mix_me_app/main.dart';
import 'package:mix_me_app/screens/create_review_screen.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;

  const ProjectDetailScreen({super.key, required this.projectData});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _messageController = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  late Future<List<Map<String, dynamic>>> _filesFuture;
  late final String _orderId;
  late final String _currentUserId;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _orderId = widget.projectData['id'];
    _currentUserId = supabase.auth.currentUser!.id;
    _filesFuture = _fetchFiles();

    _messagesStream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('order_id', _orderId)
        .order('sent_at', ascending: true);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchFiles() async {
    try {
      final response = await supabase
          .from('order_files')
          .select()
          .eq('order_id', _orderId)
          .order('uploaded_at', ascending: false);
      return response;
    } catch (e) {
      _showError('Не удалось загрузить файлы: $e');
      return [];
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    try {
      await supabase.from('messages').insert({
        'order_id': _orderId,
        'sender_id': _currentUserId,
        'content': content,
      });
      _messageController.clear();
    } catch (e) {
      _showError('Ошибка отправки: $e');
    }
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;

    setState(() => _isUploading = true);
    try {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      
      String fileExt = 'bin';
      if (fileName.contains('.')) {
          fileExt = fileName.split('.').last.toLowerCase();
          if (fileExt.length > 10) {
              fileExt = fileExt.substring(0, 10);
          }
      }

      final storagePath = '$_orderId/chat/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('project-files').upload(
            storagePath,
            file,
            fileOptions: const FileOptions(
              upsert: false,
            ),
          );
      final fileUrl = supabase.storage.from('project-files').getPublicUrl(storagePath);
      
      await supabase.from('order_files').insert({
          'order_id': _orderId,
          'uploader_id': _currentUserId,
          'file_name': fileName,
          'file_type': fileExt,
          'file_url': fileUrl,
          'storage_path': storagePath,
      });

      await supabase.from('messages').insert({
        'order_id': _orderId,
        'sender_id': _currentUserId,
        'content': 'файл: $fileName',
        'file_url': fileUrl,
        'file_name': fileName,
      });

      setState(() {
        _filesFuture = _fetchFiles();
      });
    } catch (e) {
      debugPrint('*** ОШИБКА ЗАГРУЗКИ ФАЙЛА В ЧАТЕ: $e');
      _showError('Ошибка загрузки файла: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
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

  Future<void> _downloadAndOpenFile(String storagePath, String fileName) async {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final localPath = '${dir.path}/$fileName';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Скачивание файла: $fileName...')),
        );

        final Uint8List fileBytes = await supabase.storage.from('project-files').download(storagePath);
        
        final file = File(localPath);
        await file.writeAsBytes(fileBytes);
        
        final result = await OpenFile.open(localPath);
        if (result.type != ResultType.done) {
          _showError('Не удалось открыть файл: ${result.message}');
        }
      } on StorageException catch (e) {
          _showError('Ошибка скачивания: ${e.message}');
      } catch (e) {
        _showError('Произошла ошибка: $e');
      }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    try {
      await supabase.from('orders').update({'status': newStatus}).eq('id', _orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Статус заказа обновлен!'), backgroundColor: Colors.green),
      );
       if(mounted) {
         setState(() {
           widget.projectData['status'] = newStatus;
         });
       }

    } catch (e) {
      _showError('Ошибка обновления статуса: $e');
    }
  }

  Future<void> _promptForReview() async {
    // Показываем индикатор загрузки для лучшего UX
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Проверяем, существует ли уже отзыв для данного заказа
      final response = await supabase
          .from('reviews')
          .select('id') // Нам не нужны все данные, только сам факт существования
          .eq('order_id', _orderId)
          .limit(1); // Оптимизация: останавливаем поиск после первой находки

      // Убираем индикатор загрузки
      if (mounted) Navigator.of(context).pop();

      // 2. Анализируем результат
      if (response.isNotEmpty) {
        // Если response не пустой, значит отзыв уже существует
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Вы уже оставили отзыв для этого заказа.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Если response пустой, отзыва нет, можно переходить на экран создания
        if (mounted) {
          final engineerId = widget.projectData['engineer_id'];
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CreateReviewScreen(
                orderId: _orderId,
                revieweeId: engineerId,
              ),
            ),
          );
        }
      }
    } catch (e) {
      // В случае ошибки также убираем индикатор и показываем ошибку
      if (mounted) Navigator.of(context).pop();
      _showError('Ошибка при проверке отзыва: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherPartyName = widget.projectData['customer_id'] == _currentUserId
        ? (widget.projectData['engineer']?['username'] ?? 'Инженер')
        : (widget.projectData['customer']?['username'] ?? 'Заказчик');
    
    final status = widget.projectData['status'] as String? ?? 'unknown';
    final isCurrentUserEngineer = widget.projectData['engineer_id'] == _currentUserId;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Проект', style: TextStyle(fontSize: 14)),
              Text(otherPartyName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: kPrimaryPink,
            labelColor: kPrimaryPink,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Чат'),
              Tab(icon: Icon(Icons.attach_file_outlined), text: 'Файлы'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  _buildChatView(),
                  _buildFilesView(),
                ],
              ),
            ),
            _buildActionPanel(status, isCurrentUserEngineer),
            _buildMessageInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPanel(String status, bool isEngineer) {
    if (isEngineer && status == 'in_progress') {
      return Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        color: Colors.green.withOpacity(0.2),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Отметить как выполненный'),
          onPressed: () => _updateOrderStatus('pending_completion'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      );
    }
    if (!isEngineer && status == 'pending_completion') {
       return Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        color: Colors.blue.withOpacity(0.2),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.thumb_up_alt_outlined),
          label: const Text('Подтвердить выполнение'),
          onPressed: () async {
            await _updateOrderStatus('completed');
            _promptForReview(); 
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        ),
      );
    }
    if (!isEngineer && status == 'completed') {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          width: double.infinity,
          color: Colors.grey.shade800,
          child: TextButton.icon(
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Оставить отзыв'),
            onPressed: _promptForReview,
          ),
        );
    }
    return const SizedBox.shrink();
  }

  Widget _buildFilesView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _filesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }
        final files = snapshot.data!;
        if (files.isEmpty) {
          return const Center(child: Text('К этому проекту еще не прикреплено ни одного файла.'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _filesFuture = _fetchFiles();
            });
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final fileData = files[index];
              return Card(
                color: Colors.grey.shade800,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined, color: kPrimaryPink),
                  title: Text(fileData['file_name']),
                  subtitle: Text('Загружен: ${timeago.format(DateTime.parse(fileData['uploaded_at']), locale: 'ru')}'),
                  trailing: const Icon(Icons.download_for_offline_outlined),
                  onTap: () {
                    final storagePath = fileData['storage_path'];
                    if (storagePath == null) {
                      _showError('Путь к файлу не найден. Невозможно скачать.');
                      return;
                    }
                    _downloadAndOpenFile(storagePath, fileData['file_name']);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
  
  // Внутри _ProjectDetailScreenState в файле lib/screens/project_detail_screen.dart

Widget _buildChatView() {
  return StreamBuilder<List<Map<String, dynamic>>>(
    stream: _messagesStream,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Text('Ошибка загрузки сообщений: ${snapshot.error}'));
      }
      final messages = snapshot.data ?? [];
      if (messages.isEmpty) {
        return const Center(child: Text('Сообщений пока нет. Начните диалог!'));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(12),
        // reverse: true, // <<< УБЕРИТЕ ИЛИ ЗАКОММЕНТИРУЙТЕ ЭТУ СТРОКУ
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final isMe = message['sender_id'] == _currentUserId;

          // ... остальной код itemBuilder без изменений
          if (message['file_url'] != null) {
            return FileBubble(
              fileName: message['file_name'],
              fileUrl: message['file_url'],
              sentAt: DateTime.parse(message['sent_at']),
              isMe: isMe,
              onTap: () {
                final bucketUrl = supabase.storage.from('project-files').getPublicUrl('');
                final storagePath = (message['file_url'] as String).replaceFirst(bucketUrl, '');
                _downloadAndOpenFile(storagePath, message['file_name']);
              },
            );
          }

          return MessageBubble(
            content: message['content'],
            sentAt: DateTime.parse(message['sent_at']),
            isMe: isMe,
          );
        },
      );
    },
  );
}

  Widget _buildMessageInputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          border: Border(top: BorderSide(color: Colors.grey.shade700, width: 1.0)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: Colors.white70),
              onPressed: _isUploading ? null : _pickAndSendFile,
            ),
            Expanded(
              child: TextFormField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Введите сообщение...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey.shade700,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _isUploading
                ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))
                : CircleAvatar(
                    backgroundColor: kPrimaryPink,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String content;
  final DateTime sentAt;
  final bool isMe;

  const MessageBubble({super.key, required this.content, required this.sentAt, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? kPrimaryPink : Colors.grey.shade700,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
              ),
            ),
            child: Text(content, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ),
          const SizedBox(height: 4),
          Text(timeago.format(sentAt, locale: 'ru'), style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        ],
      ),
    );
  }
}

class FileBubble extends StatelessWidget {
  final String fileName;
  final String fileUrl;
  final DateTime sentAt;
  final bool isMe;
  final VoidCallback onTap;

  const FileBubble({
    super.key,
    required this.fileName,
    required this.fileUrl,
    required this.sentAt,
    required this.isMe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            decoration: BoxDecoration(
              color: isMe ? kPrimaryPink.withOpacity(0.8) : Colors.grey.shade700,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          fileName,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(timeago.format(sentAt, locale: 'ru'), style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        ],
      ),
    );
  }
}