// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:mix_me_app/main.dart';
import 'package:mix_me_app/screens/chats_screen.dart';
import 'package:mix_me_app/screens/feed_screen.dart';
import 'package:mix_me_app/screens/profile_screen.dart';
import 'package:mix_me_app/screens/projects_screen.dart';
import 'package:mix_me_app/screens/search_screen.dart';

class MainScreen extends StatefulWidget {
  // <<< ИСПРАВЛЕНИЕ: Добавляем необязательный параметр initialIndex >>>
  final int? initialIndex;
  const MainScreen({super.key, this.initialIndex});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    FeedScreen(),
    SearchScreen(),
    ProjectsScreen(),
    ChatsScreen(),
    ProfileScreen(),
  ];

  // <<< ИСПРАВЛЕНИЕ: Устанавливаем начальный индекс при инициализации экрана >>>
  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != null) {
      _selectedIndex = widget.initialIndex!;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Лента'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Поиск'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_copy_outlined), label: 'Проекты'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Чаты'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Профиль'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.grey[900],
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kPrimaryPink,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
      ),
    );
  }
}