import 'package:flutter/material.dart';
import 'package:mix_me_app/main.dart';
import 'package:mix_me_app/screens/create_post_screen.dart';
import 'package:mix_me_app/screens/profile_screen.dart';
import 'package:mix_me_app/screens/project_detail_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<List<Map<String, dynamic>>> _postsFuture;
  String? _currentUserId;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ru', timeago.RuMessages());
    _postsFuture = _loadInitialDataAndFetchPosts();
  }

  Future<List<Map<String, dynamic>>> _loadInitialDataAndFetchPosts() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final profileResponse = await supabase.from('profiles').select('role').eq('id', userId).single();

      _currentUserId = userId;
      _currentUserRole = profileResponse['role'] ?? 'customer';

      return _fetchPosts();
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки данных: $e')));
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPosts() async {
    // <<< ИЗМЕНЕНИЕ: ДОБАВЛЯЕМ avatar_url В ЗАПРОС >>>
    final response = await supabase
        .from('posts')
        .select('*, profiles(id, username, role, avatar_url)')
        .order('created_at', ascending: false);
    
    return response as List<Map<String, dynamic>>;
  }

  void _refreshFeed() {
    setState(() {
      _postsFuture = _loadInitialDataAndFetchPosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 30),
            const SizedBox(width: 12),
            const Text(
              'Лента',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (_currentUserRole == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          }
          final posts = snapshot.data!;
          if (posts.isEmpty) {
            return Center(
              child: RefreshIndicator(
                onRefresh: () async => _refreshFeed(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const Center(child: Text('В ленте пока пусто.', style: TextStyle(fontSize: 16, color: Colors.grey))),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refreshFeed(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                return FeedPostCard(
                  postData: posts[index],
                  currentUserId: _currentUserId!,
                  currentUserRole: _currentUserRole!,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
          if (result == true) {
            _refreshFeed();
          }
        },
        backgroundColor: kPrimaryPink,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class FeedPostCard extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String currentUserId;
  final String currentUserRole;

  const FeedPostCard({super.key, required this.postData, required this.currentUserId, required this.currentUserRole});

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  bool _isLoading = false;

  Future<int?> _showPriceProposalDialog() async {
    final formKey = GlobalKey<FormState>();
    final priceController = TextEditingController();

    return showDialog<int?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ваше предложение'),
          backgroundColor: Colors.grey.shade800,
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: priceController,
              autofocus: true,
              style: const TextStyle(color: Colors.white), // Изменено для темной темы
              decoration: const InputDecoration(
                hintText: 'Введите стоимость в ₽',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.currency_ruble, color: Colors.grey),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Пожалуйста, введите цену';
                }
                if (int.tryParse(value) == null) {
                  return 'Введите корректное число';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final price = int.parse(priceController.text);
                  Navigator.of(context).pop(price);
                }
              },
              child: const Text('Предложить'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createOffer() async {
    final price = await _showPriceProposalDialog();

    if (price == null) return;

    setState(() => _isLoading = true);

    try {
      final postAuthorId = widget.postData['profiles']['id'];

      if (postAuthorId == widget.currentUserId) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нельзя предложить услуги самому себе.'), backgroundColor: Colors.orange));
        return;
      }

      final orderResponse = await supabase.from('orders').insert({
        'customer_id': postAuthorId,
        'engineer_id': widget.currentUserId,
        'status': 'pending',
        'price': price,
        'requirements': 'Отклик на пост в ленте: "${widget.postData['content']}"'
      }).select('*, customer:profiles!customer_id(*), engineer:profiles!engineer_id(*)');

      final newOrderData = orderResponse.first;

      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => ProjectDetailScreen(projectData: newOrderData),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deletePost() async {
    final postId = widget.postData['id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить пост?'),
        content: const Text('Это действие нельзя будет отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('posts').delete().eq('id', postId);
      context.findAncestorStateOfType<_FeedScreenState>()?._refreshFeed();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorProfile = widget.postData['profiles'];
    if (authorProfile == null) return const SizedBox.shrink();

    final authorName = authorProfile['username'] ?? 'Аноним';
    final authorAvatarUrl = authorProfile['avatar_url'] as String?; // <<< ДОБАВЛЕНО
    final authorRole = authorProfile['role'] ?? 'customer';
    final authorId = authorProfile['id'];
    final postText = widget.postData['content'] ?? '';
    final createdAt = DateTime.parse(widget.postData['created_at']);

    final roleText = authorRole == 'engineer' ? 'Инженер' : 'Заказчик';
    final roleColor = authorRole == 'engineer' ? Colors.blueAccent : Colors.green;

    Widget actionButton;

    if (_isLoading) {
      actionButton = const Center(child: CircularProgressIndicator());
    } else {
      if (widget.currentUserRole == 'engineer' && authorRole == 'customer') {
        actionButton = ElevatedButton(
          onPressed: _createOffer,
          child: const Text('Предложить услуги'),
        );
      } else if (authorId != widget.currentUserId) {
        actionButton = ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: authorId),
            ));
          },
          style: ElevatedButton.styleFrom(backgroundColor: kPrimaryPink.withOpacity(0.2)),
          child: const Text('Перейти в профиль'),
        );
      } else {
        actionButton = const SizedBox.shrink();
      }
    }

    return Card(
      color: Colors.grey.shade800.withOpacity(0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // <<< НАЧАЛО ИЗМЕНЕНИЯ: ОБНОВЛЯЕМ CircleAvatar >>>
                CircleAvatar(
                  radius: 24,
                  backgroundColor: kPrimaryPink,
                  backgroundImage: authorAvatarUrl != null ? NetworkImage(authorAvatarUrl) : null,
                  child: authorAvatarUrl == null 
                      ? Text(authorName.isNotEmpty ? authorName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 20)) 
                      : null,
                ),
                // <<< КОНЕЦ ИЗМЕНЕНИЯ >>>
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(timeago.format(createdAt, locale: 'ru'), style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: roleColor, borderRadius: BorderRadius.circular(4)),
                            child: Text(roleText, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                          )
                        ],
                      )
                    ],
                  ),
                ),
                if (authorId == widget.currentUserId)
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                    onPressed: _deletePost,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(postText, style: const TextStyle(color: Colors.white, height: 1.5)),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: actionButton)
          ],
        ),
      ),
    );
  }
}