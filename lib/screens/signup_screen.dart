// lib/screens/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:mix_me_app/main.dart';
import 'package:mix_me_app/screens/main_screen.dart'; 
import 'package:mix_me_app/widgets/background_glow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpScreen extends StatefulWidget {
  final String selectedRole;
  
  const SignUpScreen({
    super.key, 
    required this.selectedRole
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _agreedToTerms = false;
  
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // 👇👇👇 ИЗМЕНЕНИЯ В ЭТОЙ ФУНКЦИИ 👇👇👇
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showSnackBar('Пожалуйста, согласитесь с условиями использования');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = authResponse.user;
      if (user != null) {
        // --- Шаг 1: Всегда создаем запись в 'profiles' ---
        await supabase.from('profiles').insert({
          'id': user.id,
          'username': _usernameController.text.trim(),
          'role': widget.selectedRole,
          'full_name': _nameController.text.trim()
        });

        // --- Шаг 2: ЕСЛИ РОЛЬ - ИНЖЕНЕР, СОЗДАЕМ ЗАПИСЬ В ТАБЛИЦЕ 'engineers' ---
        if (widget.selectedRole == 'engineer') {
          await supabase.from('engineers').insert({
            'profile_id': user.id, // Связываем с профилем по ID
            // Можно сразу добавить и другие поля, если они есть на экране регистрации
            // 'bio': '',
            // 'genres': []
          });
        }
        // --- КОНЕЦ ИЗМЕНЕНИЙ ---

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Регистрация успешна! Добро пожаловать!'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (route) => false,
          );
        }
      }
    } on AuthException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Произошла непредвиденная ошибка: $error');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ... остальная часть файла без изменений
  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BackgroundGlow(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    Image.asset('assets/images/logo.png', height: 50),
                    const SizedBox(height: 20),
                    const Text('Станьте частью MixMe', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 30),
                    
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(hintText: 'Имя'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Пожалуйста, введите ваше имя';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(hintText: 'Псевдоним/Название студии'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Пожалуйста, введите псевдоним';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(hintText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || !value.contains('@') || !value.contains('.')) {
                          return 'Введите корректный email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(hintText: 'Пароль'),
                      obscureText: true,
                       validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Пароль должен быть не менее 6 символов';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirmPasswordController,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(hintText: 'Подтверждение пароля'),
                      obscureText: true,
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Пароли не совпадают';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    GestureDetector(
                      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _agreedToTerms,
                            onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
                            activeColor: kPrimaryPink,
                            checkColor: Colors.white,
                            side: const BorderSide(color: kPrimaryPink, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          const Expanded(child: Text('Я согласен с условиями использования и политикой конфиденциальности', style: TextStyle(color: Colors.white70, fontSize: 13))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    SizedBox(
                      width: double.infinity,
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _signUp,
                            child: const Text('Зарегистрироваться'),
                          ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Уже есть аккаунт? Войти', style: TextStyle(color: Colors.white, fontSize: 16)),
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}