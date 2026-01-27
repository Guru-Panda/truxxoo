import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:truxoo_client_new/onboarding_page.dart';

class TypingSplashScreen extends StatefulWidget {
  const TypingSplashScreen({super.key});

  @override
  _TypingSplashScreenState createState() => _TypingSplashScreenState();
}

class _TypingSplashScreenState extends State<TypingSplashScreen>
    with TickerProviderStateMixin {
  static const String _fullText = "Truxoo";

  late final AnimationController _imageController;
  late final Animation<double> _imageScale;
  late final Animation<double> _imageFade;

  // small pop for the text when typing completes (or forced complete)
  late final AnimationController _textPopController;
  late final Animation<double> _textPopScale;

  // fade-out controller for the entire screen before navigation
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  bool _typingFinished = false; // true when typing (or forced complete) finished
  bool _forcedComplete = false; // user tapped to force immediate completion
  bool _navigated = false;      // prevent double navigation

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _imageController.forward();
  }

  void _initAnimations() {
    _imageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _imageScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _imageController, curve: Curves.easeOut),
    );
    _imageFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _imageController, curve: Curves.easeOut),
    );

    _textPopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textPopScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _textPopController, curve: Curves.elasticOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/loading_image.png'), context);
  }

  // Called automatically when AnimatedTextKit finishes typing
  void _onTypingFinishedByKit() {
    if (!mounted) return;
    setState(() {
      _typingFinished = true;
    });
    _textPopController.forward();
    // small pause to show pop + progress, then fade & navigate
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _startFadeAndNavigate();
    });
  }

  // Called when user taps to force immediate completion or to skip
  void _onUserTap() {
    if (_navigated) return;

    if (!_typingFinished && !_forcedComplete) {
      // Force show full text immediately (replace AnimatedTextKit with plain Text)
      setState(() {
        _forcedComplete = true;
        _typingFinished = true;
      });

      // play pop
      _textPopController.forward();

      // small delay so user sees full text + pop, then fade & navigate
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        _startFadeAndNavigate();
      });

      return;
    }

    // If typing already finished (or forced), tapping will start fade & navigate now
    if (_typingFinished && !_navigated) {
      _startFadeAndNavigate();
    }
  }

  void _startFadeAndNavigate() {
    if (_navigated) return;
    _navigated = true;

    _fadeController.forward().whenComplete(() {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    });
  }

  @override
  void dispose() {
    _imageController.dispose();
    _textPopController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onUserTap,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            // Wrap content in FadeTransition so the whole screen fades out gracefully
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Image with scale + fade
                  ScaleTransition(
                    scale: _imageScale,
                    child: FadeTransition(
                      opacity: _imageFade,
                      child: Container(
                        width: isTablet ? 200 : 150,
                        height: isTablet ? 200 : 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/loading_image.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: isTablet ? 80 : 60,
                                  color: Colors.grey[600],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isTablet ? 40 : 30),

                  // Typing text area:
                  ScaleTransition(
                    scale: _textPopScale,
                    child: _forcedComplete
                        // If forced complete, show the final full text immediately
                        ? Text(
                            _fullText,
                            style: TextStyle(
                              fontSize: isTablet ? 50 : 40,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.08),
                                  offset: const Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          )
                        // Otherwise, show AnimatedTextKit for the typing effect
                        : AnimatedTextKit(
                            isRepeatingAnimation: false,
                            totalRepeatCount: 1,
                            onFinished: _onTypingFinishedByKit,
                            animatedTexts: [
                              TypewriterAnimatedText(
                                _fullText,
                                textStyle: TextStyle(
                                  fontSize: isTablet ? 50 : 40,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.08),
                                      offset: const Offset(2, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                speed: const Duration(milliseconds: 120),
                                cursor: '|',
                              ),
                            ],
                          ),
                  ),

                  // Progress indicator when typing finished (or forced)
                  if (_typingFinished)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),
                  Text(
                    'Tap anywhere to skip',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.grey[500],
                    ),
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
