// lib/screens/search_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mix_me_app/main.dart';
import 'package:mix_me_app/screens/profile_screen.dart'; // <<< ИМПОРТ PROFILE_SCREEN

/// Класс для хранения всех активных значений фильтров.
class FilterValues {
  final Set<String> genres;
  final RangeValues? priceRange;
  final RangeValues? experienceRange;
  final double minRating;
  final bool hasPortfolio;

  FilterValues({
    required this.genres,
    this.priceRange,
    this.experienceRange,
    this.minRating = 0,
    this.hasPortfolio = false,
  });
}

/// Enum для удобного и безопасного управления вариантами сортировки.
enum SortOption {
  popularity,
  priceAsc,
  priceDesc,
  rating,
  experience,
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _allEngineers = [];
  List<Map<String, dynamic>> _filteredEngineers = [];
  
  FilterValues _activeFilters = FilterValues(genres: {});
  SortOption _currentSort = SortOption.popularity;

  double _maxPrice = 50000;
  double _maxExperience = 20;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_filterAndSortEngineers);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterAndSortEngineers);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final response = await supabase
          .from('profiles')
          .select('*, services(price), engineers!inner(*, portfolios(id))')
          .eq('role', 'engineer');

      if (mounted) {
        _allEngineers = response as List<Map<String, dynamic>>;
        
        double maxFoundPrice = 0;
        double maxFoundExperience = 0;

        for (var engineer in _allEngineers) {
          final services = (engineer['services'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          if (services.isNotEmpty) {
            final prices = services.map((s) => s['price'] as int?).whereType<int>();
            if (prices.isNotEmpty) {
              final maxInServices = prices.reduce(max);
              if (maxInServices > maxFoundPrice) maxFoundPrice = maxInServices.toDouble();
            }
          }
          final exp = (engineer['engineers']['experience_years'] as int?) ?? 0;
          if (exp > maxFoundExperience) maxFoundExperience = exp.toDouble();
        }

        setState(() {
          if (maxFoundPrice > 0) _maxPrice = (maxFoundPrice / 1000).ceil() * 1000;
          if (maxFoundExperience > 0) _maxExperience = (maxFoundExperience / 5).ceil() * 5;
          _isLoading = false;
        });

        _filterAndSortEngineers();
      }
    } catch (e) {
      debugPrint('Error fetching engineers: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  void _filterAndSortEngineers() {
    final searchQuery = _searchController.text.toLowerCase();
    List<Map<String, dynamic>> tempEngineers;

    tempEngineers = _allEngineers.where((engineer) {
      final profile = engineer;
      final engineerData = engineer['engineers'];
      final services = (engineer['services'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final portfolios = (engineerData['portfolios'] as List?) ?? [];
      
      final displayName = (profile['username'] ?? '').toLowerCase();
      final genres = (engineerData['genres'] as List?)?.cast<String>() ?? [];
      if (searchQuery.isNotEmpty && !displayName.contains(searchQuery) && !genres.any((g) => g.toLowerCase().contains(searchQuery))) return false;
      if (_activeFilters.genres.isNotEmpty && !_activeFilters.genres.every((g) => genres.contains(g))) return false;
      final priceRange = _activeFilters.priceRange;
      if (priceRange != null) {
        if (!services.any((s) => (s['price'] as int? ?? -1) >= priceRange.start && (s['price'] as int? ?? -1) <= priceRange.end)) return false;
      }
      final expRange = _activeFilters.experienceRange;
      final currentExp = (engineerData['experience_years'] as int?) ?? 0;
      if (expRange != null && (currentExp < expRange.start || currentExp > expRange.end)) return false;
      final currentRating = (engineerData['avg_rating'] as num?)?.toDouble() ?? 0.0;
      if (currentRating < _activeFilters.minRating) return false;
      if (_activeFilters.hasPortfolio && portfolios.isEmpty) return false;
      return true;
    }).toList();

    tempEngineers.sort((a, b) {
       switch (_currentSort) {
        case SortOption.priceAsc:
          final priceA = _getMinPrice(a) ?? double.infinity;
          final priceB = _getMinPrice(b) ?? double.infinity;
          return priceA.compareTo(priceB);
        case SortOption.priceDesc:
          final priceA = _getMinPrice(a) ?? -1;
          final priceB = _getMinPrice(b) ?? -1;
          return priceB.compareTo(priceA);
        case SortOption.rating:
        case SortOption.popularity:
          final ratingA = (a['engineers']['avg_rating'] as num?)?.toDouble() ?? 0;
          final ratingB = (b['engineers']['avg_rating'] as num?)?.toDouble() ?? 0;
          return ratingB.compareTo(ratingA);
        case SortOption.experience:
          final expA = (a['engineers']['experience_years'] as int?) ?? 0;
          final expB = (b['engineers']['experience_years'] as int?) ?? 0;
          return expB.compareTo(expA);
      }
    });

    if (mounted) {
      setState(() => _filteredEngineers = tempEngineers);
    }
  }

  int? _getMinPrice(Map<String, dynamic> engineer) {
    final services = (engineer['services'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (services.isEmpty) return null;
    final prices = services.map((s) => s['price'] as int?).whereType<int>();
    return prices.isEmpty ? null : prices.reduce(min);
  }
  
  void _showFilterDialog() async {
    final newFilters = await showModalBottomSheet<FilterValues>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FilterDialog(
        initialFilters: _activeFilters,
        maxPrice: _maxPrice,
        maxExperience: _maxExperience,
      ),
    );

    if (newFilters != null) {
      setState(() => _activeFilters = newFilters);
      _filterAndSortEngineers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortOptions = {
      SortOption.popularity: '🔥 Популярные',
      SortOption.rating: '⭐ По рейтингу',
      SortOption.priceAsc: '₽ Сначала дешевые',
      SortOption.priceDesc: '₽ Сначала дорогие',
      SortOption.experience: '🎓 По опыту',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Найти инженера', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent, elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16,0,16,8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _showFilterDialog,
                  icon: const Icon(Icons.filter_list_alt),
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.all(14)),
                )
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: sortOptions.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: _currentSort == entry.key,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _currentSort = entry.key);
                        _filterAndSortEngineers();
                      }
                    },
                    backgroundColor: Colors.grey.shade800,
                    selectedColor: kPrimaryPink,
                    labelStyle: const TextStyle(color: Colors.white),
                    side: BorderSide(color: Colors.grey.shade700)
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEngineers.isEmpty
                    ? const Center(
                        child: Text(
                          'Инженеры не найдены.\nПопробуйте изменить условия поиска.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _filteredEngineers.length,
                        itemBuilder: (context, index) => EngineerCard(engineerData: _filteredEngineers[index]),
                      ),
          ),
        ],
      ),
    );
  }
}
         
/// Виджет для отображения карточки одного инженера.
class EngineerCard extends StatelessWidget {
  final Map<String, dynamic> engineerData;
  const EngineerCard({super.key, required this.engineerData});

  @override
  Widget build(BuildContext context) {
    final profile = engineerData;
    final engineerId = profile['id'] as String;
    final displayName = profile['username'] ?? profile['full_name'] ?? 'Без имени';
    final avatarUrl = profile['avatar_url'] as String?;
    final engineer = engineerData['engineers'];
    final bio = engineer['bio'] as String? ?? 'Описание отсутствует.';
    final genres = (engineer['genres'] as List?)?.cast<String>() ?? [];
    final avgRating = (engineer['avg_rating'] as num?)?.toDouble() ?? 0.0;
    final services = (engineerData['services'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    int? minPrice;
    if (services.isNotEmpty) {
      final prices = services.map((s) => s['price'] as int?).whereType<int>();
      if (prices.isNotEmpty) {
        minPrice = prices.reduce(min);
      }
    }
    return Card(
      color: Colors.grey.shade800.withOpacity(0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: engineerId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: kPrimaryPink,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null ? Text(displayName[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.white)) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (avgRating > 0) ...[
                              const Icon(Icons.star, color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                            ],
                            if (minPrice != null)
                              Text('от $minPrice ₽', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.greenAccent[400])),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 18),
                ],
              ),
              const Divider(height: 24, color: Colors.white12),
              Text(bio, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[300], height: 1.4)),
              const SizedBox(height: 12),
              if (genres.isNotEmpty)
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: genres
                      .map((genre) => Chip(
                            label: Text(genre),
                            backgroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            labelStyle: const TextStyle(fontSize: 12, color: Colors.white),
                            side: BorderSide.none,
                          ))
                      .toList(),
                )
            ],
          ),
        ),
      ),
    );
  }
}

/// Виджет, который строит UI для модального окна с фильтрами.
class FilterDialog extends StatefulWidget {
  final FilterValues initialFilters;
  final double maxPrice;
  final double maxExperience;
  
  const FilterDialog({
    super.key, 
    required this.initialFilters,
    required this.maxPrice,
    required this.maxExperience,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late FilterValues _tempFilters;
  
  final List<String> _allGenres = ['Поп', 'Хип-хоп', 'Рок', 'EDM', 'R&B', 'Джаз', 'Инди', 'Метал', 'Классика'];

  @override
  void initState() {
    super.initState();
    _tempFilters = FilterValues(
      genres: Set.from(widget.initialFilters.genres),
      priceRange: widget.initialFilters.priceRange,
      experienceRange: widget.initialFilters.experienceRange,
      minRating: widget.initialFilters.minRating,
      hasPortfolio: widget.initialFilters.hasPortfolio,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2C),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView( 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Фильтры', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Divider(height: 32, color: Colors.white12),
            
            const Text('Жанры', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8.0, runSpacing: 8.0,
              children: _allGenres.map((genre) {
                final isSelected = _tempFilters.genres.contains(genre);
                return FilterChip(
                  label: Text(genre), selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) _tempFilters.genres.add(genre);
                      else _tempFilters.genres.remove(genre);
                    });
                  },
                  backgroundColor: Colors.grey.shade800,
                  selectedColor: kPrimaryPink,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey[300]),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 24),
            const Text('Ценовой диапазон', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
            RangeSlider(
              values: _tempFilters.priceRange ?? RangeValues(0, widget.maxPrice),
              min: 0, max: widget.maxPrice,
              divisions: widget.maxPrice > 0 ? (widget.maxPrice / 1000).round() : 1,
              activeColor: kPrimaryPink, inactiveColor: Colors.grey.shade700,
              labels: RangeLabels(
                currencyFormat.format((_tempFilters.priceRange ?? RangeValues(0, widget.maxPrice)).start),
                currencyFormat.format((_tempFilters.priceRange ?? RangeValues(0, widget.maxPrice)).end),
              ),
              onChanged: (values) => setState(() => _tempFilters = FilterValues(genres: _tempFilters.genres, priceRange: values, experienceRange: _tempFilters.experienceRange, minRating: _tempFilters.minRating, hasPortfolio: _tempFilters.hasPortfolio)),
            ),

            const SizedBox(height: 12),
            const Text('Опыт работы (лет)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
            RangeSlider(
              values: _tempFilters.experienceRange ?? RangeValues(0, widget.maxExperience),
              min: 0, max: widget.maxExperience,
              divisions: widget.maxExperience > 0 ? widget.maxExperience.round() : 1,
              activeColor: kPrimaryPink, inactiveColor: Colors.grey.shade700,
              labels: RangeLabels(
                '${(_tempFilters.experienceRange ?? RangeValues(0, widget.maxExperience)).start.round()} г.',
                '${(_tempFilters.experienceRange ?? RangeValues(0, widget.maxExperience)).end.round()} г.',
              ),
              onChanged: (values) => setState(() => _tempFilters = FilterValues(genres: _tempFilters.genres, priceRange: _tempFilters.priceRange, experienceRange: values, minRating: _tempFilters.minRating, hasPortfolio: _tempFilters.hasPortfolio)),
            ),

            const SizedBox(height: 12),
            const Text('Минимальный рейтинг', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
            Slider(
              value: _tempFilters.minRating,
              min: 0, max: 5, divisions: 10,
              activeColor: kPrimaryPink, inactiveColor: Colors.grey.shade700,
              label: 'от ${_tempFilters.minRating.toStringAsFixed(1)} ⭐',
              onChanged: (value) => setState(() => _tempFilters = FilterValues(genres: _tempFilters.genres, priceRange: _tempFilters.priceRange, experienceRange: _tempFilters.experienceRange, minRating: value, hasPortfolio: _tempFilters.hasPortfolio)),
            ),

            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Только с портфолио', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70)),
              value: _tempFilters.hasPortfolio,
              onChanged: (value) => setState(() => _tempFilters = FilterValues(genres: _tempFilters.genres, priceRange: _tempFilters.priceRange, experienceRange: _tempFilters.experienceRange, minRating: _tempFilters.minRating, hasPortfolio: value)),
              activeColor: kPrimaryPink,
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(FilterValues(genres: {}));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                       padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Сбросить'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(_tempFilters);
                    },
                     style: ElevatedButton.styleFrom(
                       padding: const EdgeInsets.symmetric(vertical: 16),
                     ),
                    child: const Text('Применить'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}