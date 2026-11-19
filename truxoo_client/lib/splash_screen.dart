import 'package:flutter/material.dart';
import 'dart:async'; // Required for Future.wait

class TypingSplashScreen extends StatefulWidget {
  final Future<void> Function() initializationTask;
  final VoidCallback onReady;

  const TypingSplashScreen({
    super.key,
    required this.initializationTask,
    required this.onReady,
  });

  @override
  State<TypingSplashScreen> createState() => _TypingSplashScreenState();
}

class _TypingSplashScreenState extends State<TypingSplashScreen>
    with TickerProviderStateMixin {
  static const String _fullText = "Unload";
  
  // Timers
  static const Duration _imageAnimationDuration = Duration(milliseconds: 1000);
  static const Duration _textAnimationDuration = Duration(milliseconds: 600);
  static const Duration _typingDelay = Duration(milliseconds: 150);
  static const Duration _initialDelay = Duration(milliseconds: 400);

  late AnimationController _imageAnimationController;
  late AnimationController _textAnimationController;
  late Animation<double> _imageAnimation;
  late Animation<double> _textAnimation;

  String _visibleText = "";
  bool _showImage = false;
  bool _isTypingComplete = false; 

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLoadingProcess();
    });
  }

  void _initializeAnimations() {
    _imageAnimationController = AnimationController(
      duration: _imageAnimationDuration,
      vsync: this,
    );
    _textAnimationController = AnimationController(
      duration: _textAnimationDuration,
      vsync: this,
    );

    _imageAnimation = CurvedAnimation(
      parent: _imageAnimationController,
      curve: Curves.easeInOut,
    );

    _textAnimation = CurvedAnimation(
      parent: _textAnimationController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/logo.png'), context);
  }

  // 🚀 THE "SWEET SPOT" LOGIC 🚀
  Future<void> _startLoadingProcess() async {
    // 1. Start the Visual Animation Sequence
    Future<void> animationFuture = _playVisualSequence();

    // 2. Start your Backend/Firebase Initialization
    Future<void> backendFuture = widget.initializationTask();

    // 3. Wait for BOTH to completely finish
    await Future.wait([animationFuture, backendFuture]);

    // 4. Both are done -> Trigger Navigation safely!
    if (mounted) {
      // ✅ ADDED WRAPPER: Waits for the screen to finish drawing before routing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onReady();
        }
      });
    }
  }

  // The visual animation separated into its own Future
  Future<void> _playVisualSequence() async {
    if (!mounted) return;
    setState(() => _showImage = true);
    _imageAnimationController.forward();

    await Future.delayed(_initialDelay);
    if (!mounted) return;

    // Typing effect
    for (int i = 0; i < _fullText.length; i++) {
      await Future.delayed(_typingDelay);
      if (!mounted) return;
      setState(() => _visibleText = _fullText.substring(0, i + 1));
    }

    if (!mounted) return;
    _textAnimationController.forward();

    // Show the loader now that typing is done (in case backend is still loading)
    setState(() => _isTypingComplete = true);

    // Add a tiny 400ms buffer so it doesn't snap away instantly if the backend was super fast
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _imageAnimationController.dispose();
    _textAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final imageSize = isTablet ? 200.0 : 150.0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_imageAnimation, _textAnimation]),
              builder: (context, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: _imageAnimation.value,
                      child: Opacity(
                        opacity: _showImage ? _imageAnimation.value : 0.0,
                        child: _buildImageContainer(imageSize),
                      ),
                    ),
                    SizedBox(height: isTablet ? 40 : 30),
                    Transform.scale(
                      scale: 0.8 + (_textAnimation.value * 0.2),
                      child: _buildTextWidget(isTablet),
                    ),
                    // Display loader ONLY after the typing is finished
                    if (_isTypingComplete)
                      Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: SizedBox.square(
                          dimension: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey[400]!,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageContainer(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/logo.png', 
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: Icon(
                Icons.image_not_supported,
                size: size * 0.5,
                color: Colors.grey[600],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextWidget(bool isTablet) {
    return Text(
      _visibleText,
      style: TextStyle(
        fontSize: isTablet ? 50 : 40,
        color: Colors.black,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}