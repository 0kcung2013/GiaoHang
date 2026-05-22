import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _glowController;
  int _currentPage = 0;
  bool _buttonPressed = false;

  static const _gradients = [
    [Color(0xFF6C3CCF), Color(0xFF9B59B6), Color(0xFFC77DFF)],
    [Color(0xFF1A73E8), Color(0xFF2B8CED), Color(0xFF74D4FA)],
    [Color(0xFFFF5E62), Color(0xFFFF7E5F), Color(0xFFFFB88C)],
  ];

  static const _pages = [
    _OnboardingPageData(
      title: 'Đặt hàng dễ dàng',
      description: 'Chọn địa chỉ giao hàng chỉ với vài chạm',
      emoji: '📦',
    ),
    _OnboardingPageData(
      title: 'Tài xế gần bạn nhất',
      description: 'Hệ thống tự động tìm tài xế gần bạn để giao hàng nhanh nhất',
      emoji: '📍',
    ),
    _OnboardingPageData(
      title: 'Giao hàng an toàn',
      description: 'Cam kết giao hàng đúng hẹn, an toàn và nguyên vẹn',
      emoji: '🚀',
    ),
  ];

  List<Color> get _currentGradient => _gradients[_currentPage];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    context.go('/login');
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      _done();
    } else {
      setState(() => _currentPage++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final cardH = screenH * 0.38;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _currentGradient,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) => LayoutBuilder(
                builder: (context, constraints) => CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _BackgroundPainter(
                    currentPage: _currentPage,
                    tick: _glowController.value,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: cardH,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 50,
                    spreadRadius: 2,
                    offset: const Offset(0, -10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 100,
                    spreadRadius: 1,
                    offset: const Offset(0, -30),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                ),
                child: _buildCard(),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentPage < _pages.length - 1)
                    GestureDetector(
                      onTap: _done,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'Bỏ qua',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: cardH + 90,
            child: _buildIllustration(),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    final page = _pages[_currentPage];
    return AnimatedBuilder(
      animation: _floatController,
      builder: (_, child) {
        final floatY = math.sin(_floatController.value * 2 * math.pi) * 10;
        return Transform.translate(
          offset: Offset(0, floatY),
          child: child,
        );
      },
      child: Transform.scale(
        scale: 1.15,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.20),
                  width: 1.0,
                ),
              ),
            ),
            Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _currentGradient.last.withValues(alpha: 0.25),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(105),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    child: Text(
                      page.emoji,
                      style: const TextStyle(fontSize: 64),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 36,
              right: 12,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.30),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    final p = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < -50 && _currentPage < _pages.length - 1) {
          setState(() => _currentPage++);
        } else if (details.primaryVelocity! > 50 && _currentPage > 0) {
          setState(() => _currentPage--);
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSlideNumber(_currentPage),
            const SizedBox(height: 12),
            Text(
              p.title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF15172A),
                height: 1.2,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                p.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF15172A),
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            _buildPageIndicator(),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _done,
              child: Text(
                'Bỏ qua',
                style: TextStyle(
                  color: const Color(0xFF15172A).withValues(alpha: 0.35),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildButton(isLast),
          ],
        ),
      ),
    );
  }

  Widget _buildSlideNumber(int index) {
    final label = index == 0 ? '01' : index == 1 ? '02' : '03';
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: _gradients[index],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _gradients[index].first.withValues(alpha: 0.30),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: isActive
                ? LinearGradient(
                    colors: _gradients[_currentPage],
                    stops: const [0.0, 0.5, 1.0],
                  )
                : null,
            color: isActive
                ? null
                : const Color(0xFF15172A).withValues(alpha: 0.12),
          ),
        );
      }),
    );
  }

  Widget _buildButton(bool isLast) {
    return AnimatedScale(
      scale: _buttonPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: _currentGradient,
            stops: const [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: _currentGradient.first.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _next,
            onTapDown: (_) => setState(() => _buttonPressed = true),
            onTapUp: (_) => setState(() => _buttonPressed = false),
            onTapCancel: () => setState(() => _buttonPressed = false),
            splashColor: Colors.white.withValues(alpha: 0.15),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLast ? 'Bắt đầu ngay' : 'Tiếp theo',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isLast ? Icons.rocket_launch : Icons.arrow_forward,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String description;
  final String emoji;

  const _OnboardingPageData({
    required this.title,
    required this.description,
    required this.emoji,
  });
}

class _BackgroundPainter extends CustomPainter {
  final int currentPage;
  final double tick;

  _BackgroundPainter({
    required this.currentPage,
    required this.tick,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawAbstractBlobs(canvas, size);
    _drawCurvedLines(canvas, size);
    _drawGlowParticles(canvas, size);
  }

  void _drawAbstractBlobs(Canvas canvas, Size size) {
    final seeds = [
      Offset(size.width * 0.15, size.height * 0.1),
      Offset(size.width * 0.85, size.height * 0.15),
      Offset(size.width * 0.5, size.height * 0.85),
      Offset(size.width * 0.1, size.height * 0.7),
      Offset(size.width * 0.9, size.height * 0.5),
    ];

    for (int i = 0; i < seeds.length; i++) {
      final phase = tick * 2 * math.pi + i * 1.3;
      final dx = seeds[i].dx + math.sin(phase) * 20;
      final dy = seeds[i].dy + math.cos(phase * 0.8) * 25;
      final radius = 80 + math.sin(phase * 0.6) * 15 + i * 20;

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(dx, dy),
          radius,
          [
            Colors.white.withValues(alpha: 0.05 + i * 0.005),
            Colors.white.withValues(alpha: 0.01),
            Colors.transparent,
          ],
          [0.0, 0.4, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  void _drawCurvedLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (int i = 0; i < 3; i++) {
      final phase = tick * 2 * math.pi + i * 2.0;
      final path = Path();
      final startX = size.width * (0.1 + i * 0.3);
      final startY = size.height * (0.3 + i * 0.2);

      path.moveTo(startX, startY);
      for (double t = 0; t <= 1; t += 0.05) {
        final x = startX + t * 120 + math.sin(phase + t * 3) * 30;
        final y = startY + t * 80 + math.cos(phase * 0.7 + t * 2) * 20;
        path.lineTo(x, y);
      }

      paint.color = Colors.white.withValues(alpha: 0.08 + i * 0.02);
      canvas.drawPath(path, paint);
    }
  }

  void _drawGlowParticles(Canvas canvas, Size size) {
    final seed = currentPage * 137;

    for (int i = 0; i < 8; i++) {
      final phase = tick * 2 * math.pi + i * 2.1 + seed;
      final x = (math.sin(phase * 0.8) * 0.35 + 0.5) * size.width;
      final y = (math.cos(phase * 0.6 + i * 0.5) * 0.35 + 0.5) * size.height;
      final radius = 2.5 + math.sin(phase) * 1.5;

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(x, y),
          radius * 4,
          [
            Colors.white.withValues(alpha: 0.3 + math.sin(phase) * 0.1),
            Colors.white.withValues(alpha: 0.03),
            Colors.transparent,
          ],
          [0.0, 0.3, 1.0],
        );

      canvas.drawCircle(Offset(x, y), radius * 4, paint);

      canvas.drawCircle(
        Offset(x, y),
        radius * 0.4,
        Paint()
          ..color =
              Colors.white.withValues(alpha: 0.5 + math.sin(phase) * 0.15),
      );
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) =>
      oldDelegate.currentPage != currentPage ||
      oldDelegate.tick != tick;
}
