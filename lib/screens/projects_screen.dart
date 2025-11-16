import 'package:flutter/material.dart';
import 'package:mix_me_app/main.dart';
import 'package:intl/intl.dart';
import 'package:mix_me_app/screens/project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late Future<List<Map<String, dynamic>>> _projectsFuture;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _fetchProjects();
  }

  Future<List<Map<String, dynamic>>> _fetchProjects() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('orders')
          .select('*, customer:profiles!customer_id(*), engineer:profiles!engineer_id(*)')
          .or('customer_id.eq.$userId,engineer_id.eq.$userId')
          .order('created_at', ascending: false);
      return response as List<Map<String, dynamic>>;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки проектов: $e'), backgroundColor: Colors.red));
      return [];
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await supabase.from('orders').update({'status': newStatus}).eq('id', orderId);
      _refreshProjects();
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка обновления статуса: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  void _refreshProjects() {
     setState(() {
      _projectsFuture = _fetchProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои проекты', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _projectsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !_isUpdatingStatus) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
              
              final projects = snapshot.data ?? [];
              if (projects.isEmpty) {
                return Center(
                  child: RefreshIndicator(
                    onRefresh: () async => _refreshProjects(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: const Center(child: Text('У вас пока нет активных проектов.', style: TextStyle(fontSize: 16, color: Colors.grey))),
                      ),
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _refreshProjects(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    return ProjectCard(
                      projectData: projects[index],
                      onStatusUpdate: _updateOrderStatus,
                      refreshProjects: _refreshProjects, // <<< Передаем функцию обновления
                    );
                  },
                ),
              );
            },
          ),
          if (_isUpdatingStatus)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

class ProjectCard extends StatefulWidget {
  final Map<String, dynamic> projectData;
  final Function(String orderId, String newStatus) onStatusUpdate;
  final VoidCallback refreshProjects; // <<< Добавили колбэк

  const ProjectCard({
    super.key, 
    required this.projectData, 
    required this.onStatusUpdate,
    required this.refreshProjects, // <<< Добавили в конструктор
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final requirements = widget.projectData['requirements'] as String?;
    final status = widget.projectData['status'] ?? 'unknown';
    final bool isCurrentUserEngineer = widget.projectData['engineer_id'] == currentUser.id;
    final otherPartyName = !isCurrentUserEngineer ? (widget.projectData['engineer']?['username'] ?? 'Инженер') : (widget.projectData['customer']?['username'] ?? 'Заказчик');
    final roleOfOtherParty = !isCurrentUserEngineer ? 'Исполнитель' : 'Заказчик';
    final price = widget.projectData['price'] ?? 0;
    final createdAt = DateTime.parse(widget.projectData['created_at']);
    final formattedDate = DateFormat('dd.MM.yyyy').format(createdAt);

    return Card(
      color: Colors.grey.shade800.withOpacity(0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProjectDetailScreen(
                projectData: widget.projectData,
              ),
            ),
          );
          // Обновляем список по возвращению с экрана деталей в любом случае
          widget.refreshProjects();
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade700), child: const Icon(Icons.album_outlined, color: Colors.white, size: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Заказ от $formattedDate', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('$roleOfOtherParty: $otherPartyName', style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 18),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: _getStatusColor(status), borderRadius: BorderRadius.circular(8)), child: Text(_translateStatus(status), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Text('$price ₽', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                ],
              ),
              if (requirements != null && requirements.isNotEmpty) ...[
                 const Divider(color: Colors.white12, height: 24),
                InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Описание проекта', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
                Visibility(
                  visible: _isExpanded,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0, left: 4, right: 4),
                    child: Text(requirements, style: TextStyle(color: Colors.grey[300], height: 1.5, fontSize: 14)),
                  ),
                ),
              ],

              // <<< НАЧАЛО ИЗМЕНЕНИЙ: НОВЫЙ БЛОК ЛОГИКИ ДЛЯ КНОПОК >>>

              // Если Я - ЗАКАЗЧИК и статус "Ожидает ответа" (т.е. мне прислали предложение)
              if (!isCurrentUserEngineer && status == 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Column(
                    children: [
                      Text('Вам поступило предложение от инженера. Принять?', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[300])),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: () => widget.onStatusUpdate(widget.projectData['id'], 'cancelled'), style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text('Отклонить'))),
                          const SizedBox(width: 12),
                          Expanded(child: ElevatedButton(onPressed: () => widget.onStatusUpdate(widget.projectData['id'], 'in_progress'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text('Принять'))),
                        ],
                      ),
                    ],
                  ),
                ),
              
              // Если Я - ИНЖЕНЕР и статус "Ожидает ответа" (т.е. мне прислали стандартный заказ из профиля)
              if (isCurrentUserEngineer && status == 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                   child: Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => widget.onStatusUpdate(widget.projectData['id'], 'cancelled'), style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text('Отклонить'))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(onPressed: () => widget.onStatusUpdate(widget.projectData['id'], 'in_progress'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text('Принять'))),
                    ],
                  ),
                ),
                
              // <<< КОНЕЦ ИЗМЕНЕНИЙ >>>
            ],
          ),
        ),
      ),
    );
  }

  String _translateStatus(String status) {
    switch (status) { case 'pending': return 'Ожидает ответа'; case 'in_progress': return 'В работе'; case 'completed': return 'Завершен'; case 'cancelled': return 'Отменен'; case 'pending_completion': return 'Ждет подтверждения'; default: return status; }
  }

  Color _getStatusColor(String status) {
    switch (status) { case 'pending': return Colors.orange.shade800; case 'in_progress': return Colors.blue.shade800; case 'completed': return Colors.green.shade800; case 'cancelled': return Colors.red.shade800; case 'pending_completion': return Colors.indigo.shade800; default: return Colors.grey.shade800; }
  }
}