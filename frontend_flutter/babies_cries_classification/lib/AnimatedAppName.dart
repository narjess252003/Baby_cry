import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_localizations.dart';

class AnimatedAppElements extends StatefulWidget {
  @override
  _AnimatedAppElementsState createState() => _AnimatedAppElementsState();
}

class _AnimatedAppElementsState extends State<AnimatedAppElements> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _floatingAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatingAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(0, 0.05), // increased movement
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _fadeAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Floating and Glowing App Name (Top)
        FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _floatingAnimation,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  colors: [
                    Colors.deepPurple.shade700, // darker purple
                    Colors.blueAccent.shade400  // darker blue
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds);
              },
              child: Text(
                AppLocalizations.of(context).translate('app_name') ?? 'Baby Cry App',
                style: GoogleFonts.raleway(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(blurRadius: 10, color: Colors.black54, offset: Offset(3, 3)),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),

        SizedBox(height: 24),

        // Floating Glowing Circular Baby Image (Below)
        SlideTransition(
          position: _floatingAnimation,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/baby2.png',
                height: 220,
                width: 220,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
