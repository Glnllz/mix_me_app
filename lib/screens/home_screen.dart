// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:mix_me_app/main.dart';
import 'package:mix_me_app/screens/welcome_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Получаем текущего пользователя, чтобы показать его email
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Главный экран'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Логика выхода
              await supabase.auth.signOut();
              
              // Возвращаемся на экран входа и очищаем все предыдущие экраны
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                (route) => false,
              );
            },
          )
        ],
      ),
      body: Center(
        child: Text(
          'Добро пожаловать!\nВы вошли как: ${user?.email}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}