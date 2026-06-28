import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthShell extends StatefulWidget {
  const AuthShell({super.key});
  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void goToRegister() {
    _pageController.animateToPage(1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic);
  }

  void goToLogin() {
    _pageController.animateToPage(0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // ── Parallax background — extra wide, shifted via AnimatedBuilder ──
          AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double offset = 0.0;
              if (_pageController.hasClients &&
                  _pageController.page != null) {
                offset = _pageController.page! * screenWidth * 0.25;
              }
              return Transform.translate(
                offset: Offset(-offset, 0),
                child: child,
              );
            },
            child: RepaintBoundary(
              child: SizedBox(
                width: screenWidth * 1.5,
                height: double.infinity,
                child: Image.asset(
                  'assets/images/Login.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),

          // ── Cards ──
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              LoginScreen(onGoRegister: goToRegister),
              RegisterScreen(onGoLogin: goToLogin),
            ],
          ),
        ],
      ),
    );
  }
}