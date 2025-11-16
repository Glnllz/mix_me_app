import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mix_me_app/main.dart';
import 'package:mix_me_app/screens/login_screen.dart';
import 'package:mix_me_app/screens/signup_screen.dart';
import 'package:mix_me_app/widgets/background_glow.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _selectedRole = 0; // 0 - не выбрано, 1 - заказчик, 2 - инженер

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BackgroundGlow(),
          PageView(
            physics: const ClampingScrollPhysics(),
            controller: _pageController,
            children: [
              _buildFirstPage(),
              _buildSecondPage(),
            ],
          ),
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Center(
              child: SmoothPageIndicator(
                controller: _pageController,
                count: 2,
                effect: const WormEffect(
                  dotHeight: 8,
                  dotWidth: 30,
                  spacing: 12,
                  activeDotColor: kPrimaryPink,
                  dotColor: Colors.white30,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFirstPage() {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
          child: Align(
            alignment: Alignment.topCenter,
            child: Image.asset('assets/images/logo.png', height: 70),
          ),
        ),
        Positioned(
          bottom: 100,
          left: 32,
          right: 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MixMe',
                style: TextStyle(
                  color: kPrimaryPink,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Профессиональное сведение и мастеринг в одном приложении.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.4,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecondPage() {
    return Center(
      child: _GlassmorphicCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', height: 50),
            const SizedBox(height: 16),
            const Text('Вход',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 24),
            _RoleButton(
              isSelected: _selectedRole == 1,
              onTap: () => setState(() => _selectedRole = 1),
              iconPath: 'assets/images/icon_customer.png',
              title: 'Я ищу профессионала',
              subtitle: 'Мне нужно свести трек',
            ),
            const SizedBox(height: 16),
            _RoleButton(
              isSelected: _selectedRole == 2,
              onTap: () => setState(() => _selectedRole = 2),
              iconPath: 'assets/images/icon_engineer.png',
              title: 'Я создаю шедевры',
              subtitle: 'Я mix/master инженер',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ));
                },
                child: const Text('Войти'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_selectedRole == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Пожалуйста, выберите кем вы хотите быть'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  final role = _selectedRole == 1 ? 'customer' : 'engineer';

                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => SignUpScreen(selectedRole: role),
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kLightPink,
                  foregroundColor: kPrimaryPink,
                ),
                child: const Text('Зарегистрироваться'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassmorphicCard extends StatelessWidget {
  final Widget child;
  const _GlassmorphicCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kGlassyColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final String iconPath;
  final String title;
  final String subtitle;

  const _RoleButton({
    required this.isSelected,
    required this.onTap,
    required this.iconPath,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kGlassyColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? kPrimaryPink : Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Image.asset(iconPath, height: 36, color: Colors.white),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 14)),
              ],
            )
          ],
        ),
      ),
    );
  }
}