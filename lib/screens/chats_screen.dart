// lib/screens/chats_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mix_me_app/main.dart';
import 'package:mix_me_app/screens/project_detail_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  // <<< 1. ДОБАВЛЯЕМ ПЕРЕМЕННЫЕ ДЛЯ ПОИСКА И УПРАВЛЕНИЯ СОСТОЯНИЕМ >>>
  final _searchController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allChats = [];
  List<Map<String, dynamic>> _filteredChats = [];

  @override
  void initState() {
    super.initState();
    _fetchChats();
    _searchController.addListener(_filterChats);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterChats);
    _searchController.dispose();
    super.dispose();
  }

  // <<< 2. ОБНОВЛЕННАЯ ФУНКЦИЯ: ТЕПЕРЬ ВЫЗЫВАЕТ RPC >>>
  Future<void> _fetchChats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Вызываем нашу SQL-функцию
      final response = await supabase.rpc('get_user_chats');
      
      if (mounted) {
        setState(() {
          _allChats = List<Map<String, dynamic>>.from(response);
          _filteredChats = _allChats; // Изначально показываем все
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки чатов: $e'), backgroundColor: Colors.red));
      }
    }
  }
  
  // <<< 3. НОВАЯ ФУНКЦИЯ ДЛЯ ФИЛЬТРАЦИИ ЧАТОВ >>>
  void _filterChats() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredChats = _allChats.where((chat) {
        final otherPartyName = (chat['other_party_username'] as String? ?? '').toLowerCase();
        return otherPartyName.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // <<< 4. ДОБАВЛЯЕМ ПОЛЕ ПОИСКА >>>
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Поиск по собеседнику...',
                prefixIcon: const Icon(Icons.search),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // <<< 5. ОБНОВЛЕННАЯ ЛОГИКА ОТОБРАЖЕНИЯ >>>
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchChats,
                    child: _filteredChats.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Text(
                                _allChats.isEmpty
                                  ? 'У вас пока нет начатых диалогов.'
                                  : 'Ничего не найдено.',
                                style: const TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredChats.length,
                            itemBuilder: (context, index) {
                              final chatData = _filteredChats[index];
                              
                              final otherPartyName = chatData['other_party_username'] ?? 'Собеседник';
                              final otherPartyAvatarUrl = chatData['other_party_avatar_url'] as String?;
                              final lastMessage = chatData['last_message_content'] as String? ?? 'Нет сообщений';
                              final lastMessageAt = chatData['last_message_at'] != null
                                  ? DateTime.parse(chatData['last_message_at'])
                                  : null;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: kPrimaryPink,
                                  backgroundImage: otherPartyAvatarUrl != null ? NetworkImage(otherPartyAvatarUrl) : null,
                                  child: otherPartyAvatarUrl == null ? Text(otherPartyName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20)) : null,
                                ),
                                title: Text(otherPartyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                // Отображаем последнее сообщение
                                subtitle: Text(
                                  lastMessage,
                                  style: TextStyle(color: Colors.grey[400]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Отображаем время последнего сообщения
                                trailing: lastMessageAt != null
                                    ? Text(
                                        timeago.format(lastMessageAt, locale: 'ru'),
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ProjectDetailScreen(projectData: chatData),
                                    ),
                                  ).then((_) => _fetchChats()); // Обновляем чаты по возвращении
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}