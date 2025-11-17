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
  // <<< НАЧАЛО ИЗМЕНЕНИЙ: УПРОЩАЕМ УПРАВЛЕНИЕ СОСТОЯНИЕМ >>>
  bool _isLoading = true;
  List<Map<String, dynamic>> _allProjects = [];
  String _activeFilter = 'all';
  // <<< КОНЕЦ ИЗМЕНЕНИЙ >>>

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    // Не показываем индикатор при обновлении, только при первой загрузке
    if (_allProjects.isEmpty) {
      setState(() => _isLoading = true);
    }
    
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('orders')
          .select('*, customer:profiles!customer_id(*), engineer:profiles!engineer_id(*)')
          .or('customer_id.eq.$userId,engineer_id.eq.$userId')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allProjects = response as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки проектов: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    setState(() {
      final index = _allProjects.indexWhere((p) => p['id'] == orderId);
      if (index != -1) {
        _allProjects[index]['status'] = newStatus;
      }
    });

    try {
      await supabase.from('orders').update({'status': newStatus}).eq('id', orderId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка обновления статуса: $e'), backgroundColor: Colors.red));
        _fetchProjects(); // В случае ошибки откатываем изменения
      }
    }
  }

  // <<< НАЧАЛО ИЗМЕНЕНИЙ: НОВАЯ ЛОГИКА УДАЛЕНИЯ >>>
  Future<void> _deleteOrder(String orderId) async {
    // 1. Оптимистичное обновление: мгновенно удаляем из UI
    setState(() {
      _allProjects.removeWhere((project) => project['id'] == orderId);
    });

    try {
      // 2. Отправляем запрос на удаление в фоне
      await supabase.from('orders').delete().eq('id', orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Проект удален'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      // 3. В случае ошибки, показываем сообщение и перезагружаем данные, чтобы вернуть удаленный элемент
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red),
        );
        _fetchProjects();
      }
    }
  }
  // <<< КОНЕЦ ИЗМЕНЕНИЙ >>>

  @override
  Widget build(BuildContext context) {
    // <<< НАЧАЛО ИЗМЕНЕНИЙ: ФИЛЬТРАЦИЯ ПРЯМО В BUILD МЕТОДЕ >>>
    final List<Map<String, dynamic>> filteredProjects;
    if (_activeFilter == 'all') {
      filteredProjects = _allProjects;
    } else {
      filteredProjects = _allProjects.where((p) => p['status'] == _activeFilter).toList();
    }
    // <<< КОНЕЦ ИЗМЕНЕНИЙ >>>

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои проекты', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('all', 'Все'),
                _buildFilterChip('in_progress', 'В работе'),
                _buildFilterChip('pending', 'Ожидают'),
                _buildFilterChip('completed', 'Завершены'),
                _buildFilterChip('cancelled', 'Отменены'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchProjects,
                    child: filteredProjects.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  _allProjects.isEmpty ? 'У вас пока нет проектов.' : 'Нет проектов в этой категории.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: filteredProjects.length,
                            itemBuilder: (context, index) {
                              return ProjectCard(
                                projectData: filteredProjects[index],
                                onStatusUpdate: _updateOrderStatus,
                                refreshProjects: _fetchProjects,
                                onDeleteOrder: _deleteOrder,
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filter, String label) {
    final isSelected = _activeFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _activeFilter = filter;
            });
          }
        },
        backgroundColor: Colors.grey.shade800,
        selectedColor: kPrimaryPink,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey[300]),
        side: BorderSide.none,
      ),
    );
  }
}

class ProjectCard extends StatefulWidget {
  final Map<String, dynamic> projectData;
  final Function(String orderId, String newStatus) onStatusUpdate;
  final VoidCallback refreshProjects;
  final Function(String orderId) onDeleteOrder;

  const ProjectCard({
    super.key,
    required this.projectData,
    required this.onStatusUpdate,
    required this.refreshProjects,
    required this.onDeleteOrder,
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
    final bool isFeedOffer = (requirements ?? '').startsWith('Отклик на пост в ленте:');

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
                  if (status == 'cancelled')
                    IconButton(
                      icon: Icon(Icons.delete_forever, color: Colors.redAccent.withOpacity(0.7)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Удалить проект?'),
                            content: const Text('Это действие нельзя будет отменить.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Отмена')),
                              TextButton(
                                onPressed: () {
                                  widget.onDeleteOrder(widget.projectData['id']);
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Удалить', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  else
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 18),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: _getStatusColor(status), borderRadius: BorderRadius.circular(8)), child: Text(_translateStatus(status, isCurrentUserEngineer, isFeedOffer), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
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
              if (status == 'pending')
                if (!isCurrentUserEngineer)
                  if (isFeedOffer)
                    _ActionButtons(
                      prompt: 'Вам поступило предложение от инженера. Принять?',
                      onDecline: () => widget.onStatusUpdate(widget.projectData['id'], 'cancelled'),
                      onAccept: () => widget.onStatusUpdate(widget.projectData['id'], 'in_progress'),
                    )
                  else
                    const SizedBox.shrink()
                else if (!isFeedOffer)
                  _ActionButtons(
                    prompt: 'Вам поступил новый заказ от клиента. Принять?',
                    onDecline: () => widget.onStatusUpdate(widget.projectData['id'], 'cancelled'),
                    onAccept: () => widget.onStatusUpdate(widget.projectData['id'], 'in_progress'),
                  )
                else
                  const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  String _translateStatus(String status, bool isEngineer, bool isFeedOffer) {
    if (status == 'pending') {
      if (isEngineer) {
        return isFeedOffer ? 'Отправлено' : 'Требует ответа';
      } else {
        return isFeedOffer ? 'Требует ответа' : 'Ожидает инженера';
      }
    }
    switch (status) {
      case 'in_progress':
        return 'В работе';
      case 'completed':
        return 'Завершен';
      case 'cancelled':
        return 'Отменен';
      case 'pending_completion':
        return 'Ждет подтверждения';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange.shade800;
      case 'in_progress':
        return Colors.blue.shade800;
      case 'completed':
        return Colors.green.shade800;
      case 'cancelled':
        return Colors.red.shade800;
      case 'pending_completion':
        return Colors.indigo.shade800;
      default:
        return Colors.grey.shade800;
    }
  }
}

class _ActionButtons extends StatelessWidget {
  final String prompt;
  final VoidCallback onDecline;
  final VoidCallback onAccept;

  const _ActionButtons({
    required this.prompt,
    required this.onDecline,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Column(
        children: [
          Text(prompt, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[300])),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: onDecline, style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text('Отклонить'))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(onPressed: onAccept, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text('Принять'))),
            ],
          ),
        ],
      ),
    );
  }
}