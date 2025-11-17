import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mix_me_app/main.dart';
import 'package:mix_me_app/screens/create_order_screen.dart';
import 'package:mix_me_app/screens/edit_profile_screen.dart';
import 'package:mix_me_app/screens/reviews_screen.dart';
import 'package:mix_me_app/screens/welcome_screen.dart';
import 'package:intl/intl.dart';

class ProfileData {
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> reviews;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> portfolio;

  ProfileData({required this.profile, required this.services, required this.reviews, required this.orders, required this.portfolio});
}

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<ProfileData> _profileDataFuture;
  late final bool _isOwnProfile;
  late final String _targetUserId;

  @override
  void initState() {
    super.initState();
    _targetUserId = widget.userId ?? supabase.auth.currentUser!.id;
    _isOwnProfile = _targetUserId == supabase.auth.currentUser!.id;
    _profileDataFuture = _fetchProfileData();
  }

  Future<ProfileData> _fetchProfileData() async {
    final profileResponse = await supabase
        .from('profiles')
        .select('*, engineers(*, portfolios(*))')
        .eq('id', _targetUserId)
        .single();
    
    List<Map<String, dynamic>> portfolioResponse = [];
    
    if (profileResponse.containsKey('engineers') && profileResponse['engineers'] != null) {
      final engineerRelationData = profileResponse.remove('engineers');
      Map<String, dynamic>? engineerData;

      if (engineerRelationData is List && engineerRelationData.isNotEmpty) {
        engineerData = engineerRelationData.first as Map<String, dynamic>;
      } else if (engineerRelationData is Map<String, dynamic>) {
        engineerData = engineerRelationData;
      }
      
      if (engineerData != null) {
        if (engineerData.containsKey('portfolios') && engineerData['portfolios'] != null) {
          portfolioResponse = (engineerData.remove('portfolios') as List).cast<Map<String, dynamic>>();
        }
        profileResponse.addAll(engineerData);
      }
    }

    final servicesResponse = await supabase.from('services').select().eq('user_id', _targetUserId);
    final reviewsResponse = await supabase.from('reviews').select().eq('reviewee_id', _targetUserId);
    final ordersResponse = await supabase.from('orders').select('status').eq('engineer_id', _targetUserId);

    return ProfileData(
      profile: profileResponse,
      services: (servicesResponse as List).cast<Map<String, dynamic>>(),
      reviews: (reviewsResponse as List).cast<Map<String, dynamic>>(),
      orders: (ordersResponse as List).cast<Map<String, dynamic>>(),
      portfolio: portfolioResponse,
    );
  }
  
  void _refreshProfile() {
    setState(() {
      _profileDataFuture = _fetchProfileData();
    });
  }

  void _showServicesToOrder(List<Map<String, dynamic>> services, Map<String, dynamic> engineerProfile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Выберите услугу для заказа', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (services.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text('У этого инженера пока нет добавленных услуг.')),
                )
              else
                Flexible( // Используем Flexible, чтобы список занимал доступное место
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: services.length,
                    itemBuilder: (context, index) {
                      final service = services[index];
                      return ListTile(
                        title: Text(service['name']),
                        subtitle: Text('${service['price']} ₽'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Закрываем BottomSheet
                          Navigator.of(context).pop();
                          // Переходим на экран создания заказа с выбранной услугой
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => CreateOrderScreen(
                              engineerProfile: engineerProfile,
                              serviceData: service,
                            ),
                          ));
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(_isOwnProfile ? 'Мой профиль' : 'Профиль инженера'),
        actions: [
          if (_isOwnProfile)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () async {
                final currentData = await _profileDataFuture;
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => EditProfileScreen(
                      profileData: currentData.profile,
                      initialServices: currentData.services,
                      initialPortfolio: currentData.portfolio,
                    ),
                  ),
                );
                if (result == true) {
                  _refreshProfile();
                }
              },
            ),
        ],
      ),
      body: FutureBuilder<ProfileData>(
        future: _profileDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Ошибка загрузки профиля: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          final profile = data.profile;
          final services = data.services;
          final reviews = data.reviews;
          final orders = data.orders;
          final portfolio = data.portfolio;
          
          final isEngineer = profile['role'] == 'engineer';
          final bio = profile['bio'] as String?;
          final genres = (profile['genres'] as List?)?.cast<String>();
          final experienceYears = profile['experience_years'] as int?;
          final displayName = profile['username'] ?? profile['full_name'] ?? 'Пользователь';
          final completedCount = orders.where((o) => o['status'] == 'completed').length;
          final inProgressCount = orders.where((o) => o['status'] == 'in_progress').length;
          double averageRating = 0;
          if (reviews.isNotEmpty) {
            final ratings = reviews.map((r) => r['rating'] as int? ?? 0);
            if (ratings.isNotEmpty) {
                averageRating = ratings.reduce((a, b) => a + b) / ratings.length;
            }
          }

          return RefreshIndicator(
            onRefresh: () async => _refreshProfile(),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildProfileHeader(profile, averageRating, reviews.length, isEngineer: isEngineer),
                const SizedBox(height: 24),
                
                if (!_isOwnProfile && isEngineer) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Написать'),
                          onPressed: () { /* TODO: Логика перехода в чат */ },
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                         child: ElevatedButton.icon(
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: const Text('Заказать'),
                          onPressed: () {
                            // Вызываем новую функцию, передавая ей список услуг и профиль
                            _showServicesToOrder(services, profile);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                if (isEngineer && bio != null && bio.isNotEmpty) ...[
                  ProfileInfoCard(
                    title: 'О себе',
                    child: Text(bio, style: TextStyle(color: Colors.grey[300], height: 1.5)),
                  ),
                  const SizedBox(height: 16),
                ],
                
                if (isEngineer) ...[
                  if (portfolio.isNotEmpty) ...[
                    ProfileInfoCard(
                      title: 'Портфолио',
                      child: ListView.separated(
                        itemCount: portfolio.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) => PortfolioItemCard(itemData: portfolio[index]),
                        separatorBuilder: (context, index) => const Divider(height: 24, color: Colors.white12),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (genres != null && genres.isNotEmpty) ...[
                    ProfileInfoCard(
                      title: 'Жанры',
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: genres.map((genre) => Chip(label: Text(genre), backgroundColor: Colors.grey.shade700)).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ProfileInfoCard(
                    title: 'Статистика',
                    child: Column(
                      children: [
                        _buildStatItem(Icons.work_history_outlined, 'Опыт работы', _getExperienceString(experienceYears)),
                        _buildStatItem(Icons.check_circle_outline, 'Завершено проектов', completedCount.toString()),
                        _buildStatItem(Icons.hourglass_bottom_outlined, 'В работе', inProgressCount.toString()),
                        _buildStatItem(Icons.star_border_outlined, 'Средняя оценка', reviews.isEmpty ? 'N/A' : '${averageRating.toStringAsFixed(1)} (${reviews.length})'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (reviews.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => ReviewsScreen(userId: profile['id'], userName: displayName))),
                      child: ProfileInfoCard(
                        title: 'Отзывы (${reviews.length})',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Посмотреть все отзывы'),
                            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
                if (_isOwnProfile)
                  ElevatedButton(
                    onPressed: () async {
                      await supabase.auth.signOut();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const WelcomeScreen()), (route) => false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8)),
                    child: const Text('Выйти из аккаунта'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getExperienceString(int? years) {
    if (years == null || years == 0) return 'Не указан';
    final lastDigit = years % 10;
    final lastTwoDigits = years % 100;
    if (lastTwoDigits >= 11 && lastTwoDigits <= 14) return '$years лет';
    if (lastDigit == 1) return '$years год';
    if (lastDigit >= 2 && lastDigit <= 4) return '$years года';
    return '$years лет';
  }

  Widget _buildProfileHeader(Map<String, dynamic> profile, double rating, int reviewCount, {required bool isEngineer}) {
    final displayName = profile['username'] ?? profile['full_name'] ?? 'Пользователь';
    final registrationDate = DateTime.parse(profile['created_at']);
    final formattedDate = DateFormat('MMMM yyyy', 'ru').format(registrationDate);
    final avatarUrl = profile['avatar_url'] as String?;
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.pinkAccent,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null && displayName.isNotEmpty ? Text(displayName[0].toUpperCase(), style: const TextStyle(fontSize: 32, color: Colors.white)) : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('В MixMe с $formattedDate', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
              const SizedBox(height: 8),
              if (isEngineer && reviewCount > 0)
                Row(
                  children: [
                    ...List.generate(5, (index) => Icon(index < rating.round() ? Icons.star : Icons.star_border, color: Colors.amber, size: 18)),
                    const SizedBox(width: 8),
                    Text('${rating.toStringAsFixed(1)} ($reviewCount)', style: TextStyle(color: Colors.grey[300])),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 22),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[300])),
        ],
      ),
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const ProfileInfoCard({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade800.withOpacity(0.8), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 24, color: Colors.white12),
          child,
        ],
      ),
    );
  }
}

class PortfolioItemCard extends StatefulWidget {
  final Map<String, dynamic> itemData;
  const PortfolioItemCard({super.key, required this.itemData});

  @override
  State<PortfolioItemCard> createState() => _PortfolioItemCardState();
}

class _PortfolioItemCardState extends State<PortfolioItemCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Stream<PlayerState>? _playerStateStream;
  String? _currentlyPlayingUrl;

  @override
  void initState() {
    super.initState();
    _playerStateStream = _audioPlayer.playerStateStream;
    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if(mounted) {
          setState(() {
            _currentlyPlayingUrl = null;
            _audioPlayer.seek(Duration.zero);
            _audioPlayer.pause();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause(String url) async {
    if (_audioPlayer.playing && _currentlyPlayingUrl == url) {
      await _audioPlayer.pause();
    } else {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(url);
        _audioPlayer.play();
        if(mounted) setState(() => _currentlyPlayingUrl = url);
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Не удалось воспроизвести аудио: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.itemData['title'] ?? 'Без названия';
    final description = widget.itemData['description'] as String?;
    final beforeUrl = widget.itemData['audio_before_url'] as String?;
    final afterUrl = widget.itemData['audio_after_url'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(description, style: TextStyle(color: Colors.grey[400])),
        ],
        const SizedBox(height: 12),
        StreamBuilder<PlayerState>(
          stream: _playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final isPlaying = playerState?.playing ?? false;
            final processingState = playerState?.processingState ?? ProcessingState.idle;

            Widget buildButtonChild(String url, bool isPrimary) {
              if ((processingState == ProcessingState.loading || processingState == ProcessingState.buffering) && _currentlyPlayingUrl == url) {
                return SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: isPrimary ? Colors.white : Theme.of(context).colorScheme.primary));
              }
              return Text(isPrimary ? 'После' : 'До');
            }

            return Row(
              children: [
                if (beforeUrl != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _playPause(beforeUrl),
                      icon: Icon(isPlaying && _currentlyPlayingUrl == beforeUrl ? Icons.pause : Icons.play_arrow),
                      label: buildButtonChild(beforeUrl, false),
                    ),
                  ),
                if (beforeUrl != null && afterUrl != null) const SizedBox(width: 12),
                if (afterUrl != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _playPause(afterUrl),
                      icon: Icon(isPlaying && _currentlyPlayingUrl == afterUrl ? Icons.pause : Icons.play_arrow, color: Colors.white),
                      label: buildButtonChild(afterUrl, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
              ],
            );
          },
        )
      ],
    );
  }
}