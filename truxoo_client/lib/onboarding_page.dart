import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _preloadAssets();
  }

  Future<void> _preloadAssets() async {
    try {
      final futures = <Future>[
        precacheImage(const AssetImage('assets/logo.png'), context)
            .catchError((e) => debugPrint('Logo not found: $e')),
        precacheImage(const AssetImage('assets/onboarding_main.png'), context)
            .catchError((e) => debugPrint('Main image not found: $e')),
      ];
      await Future.wait(futures);
      debugPrint('✅ Assets preloaded successfully');
    } catch (e) {
      debugPrint('Asset preloading failed: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
            child: CircularProgressIndicator(
                color: Colors.black, strokeWidth: 2)),
      );
    }
    return const _OnboardingScaffoldWrapper();
  }
}

class _OnboardingScaffoldWrapper extends StatelessWidget {
  const _OnboardingScaffoldWrapper({super.key});

  static const double _largeScreenBreakpoint = 600;
  static const double _buttonWidthRatio = 0.8;
  static const double _horizontalPaddingRatio = 0.08;
  static const double _imageAspectRatio = 0.6;

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenWidth > _largeScreenBreakpoint;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isLargeScreen ? 100 : 80),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          automaticallyImplyLeading: false,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: isLargeScreen ? 20 : 10),
              Flexible(
                child: Text(
                  'Welcome To',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 40 : 36,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: isLargeScreen ? 24 : 16),
              _buildLogo(isLargeScreen),
            ],
          ),
          toolbarHeight: isLargeScreen ? 100 : 80,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMainImage(screenWidth),
              _buildContent(context, screenWidth, screenHeight, isLargeScreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isLargeScreen) {
    return Semantics(
      label: 'Truxoo logo',
      child: Image.asset(
        'assets/logo.png',
        height: isLargeScreen ? 45 : 35,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: isLargeScreen ? 45 : 35,
            height: isLargeScreen ? 45 : 35,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.business,
              size: isLargeScreen ? 20 : 15,
              color: Colors.grey[600],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainImage(double screenWidth) {
    return SizedBox(
      width: screenWidth,
      child: Image.asset(
        'assets/onboarding_main.png',
        fit: BoxFit.fitWidth,
        semanticLabel: 'Onboarding illustration',
        errorBuilder: (context, error, stackTrace) {
          return _buildImagePlaceholder(screenWidth);
        },
      ),
    );
  }

  Widget _buildImagePlaceholder(double screenWidth) {
    return Container(
      width: screenWidth,
      height: screenWidth * _imageAspectRatio,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[50]!,
            Colors.blue[100]!,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping, size: 80, color: Colors.blue[400]),
          const SizedBox(height: 16),
          Text(
            'Truxoo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Logistics Made Simple',
            style: TextStyle(fontSize: 16, color: Colors.blue[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, double screenWidth,
      double screenHeight, bool isLargeScreen) {
    final verticalSpacing = isLargeScreen ? 50.0 : 30.0;
    final buttonSpacing =
        isLargeScreen ? screenHeight * 0.1 : screenHeight * 0.06;
    final bottomSpacing = isLargeScreen ? 40.0 : 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: verticalSpacing),
        _buildTagline(screenWidth, isLargeScreen),
        SizedBox(height: buttonSpacing),
        _buildContinueButton(screenWidth, isLargeScreen, context),
        SizedBox(height: isLargeScreen ? 20 : 12),
        _buildTermsText(screenWidth, isLargeScreen, context),
        SizedBox(height: bottomSpacing),
      ],
    );
  }

  Widget _buildTagline(double screenWidth, bool isLargeScreen) {
    return Padding(
      padding: EdgeInsets.only(left: screenWidth * _horizontalPaddingRatio),
      child: Text(
        'Logistics Made Simple',
        style: TextStyle(
          fontSize: isLargeScreen ? 40 : 36,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildContinueButton(
      double screenWidth, bool isLargeScreen, BuildContext context) {
    final buttonWidth = screenWidth * _buttonWidthRatio;

    return Center(
      child: SizedBox(
        width: buttonWidth,
        child: Material(
          color: Colors.black,
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              HapticFeedback.lightImpact();
              _showConsentPopup(context);
            },
            child: Container(
              constraints: BoxConstraints(
                minHeight: isLargeScreen ? 65 : 50,
                minWidth: buttonWidth,
              ),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 18 : 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue with Phone Number',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isLargeScreen ? 18 : 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: isLargeScreen ? 12 : 8),
                  Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: isLargeScreen ? 24 : 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showConsentPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool isChecked = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Legal Agreement',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: isChecked,
                                  activeColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (bool? value) {
                                    setModalState(() {
                                      isChecked = value ?? false;
                                    });
                                    if (isChecked) {
                                      HapticFeedback.selectionClick();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          isChecked = !isChecked;
                                        });
                                      },
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[800],
                                            height: 1.5,
                                          ),
                                          children: [
                                            const TextSpan(
                                                text:
                                                    'I confirm that I have read, understood, and agree to be legally bound by the '),
                                            TextSpan(
                                              text: 'Terms & Conditions',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () => _launchURL(
                                                    'https://unloadweb.com/tc.html'),
                                            ),
                                            const TextSpan(text: ', '),
                                            TextSpan(
                                              text: 'Privacy Policy',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () => _launchURL(
                                                    'https://unloadweb.com/privacy.html'),
                                            ),
                                            const TextSpan(
                                                text:
                                                    ', Insurance Policy, and all applicable policies of Unload. I expressly acknowledge that Unload is only an intermediary technology platform connecting users with independent drivers, truck owners, and transporters, and does not own, operate, or control any vehicle or transportation service, nor does it take custody of goods. I agree that all risks relating to transportation, including but not limited to delay, damage, loss, theft, accident, or misconduct, shall be solely borne between the contracting parties, and Unload shall not be liable in any manner. I declare that the goods being transported are lawful, properly declared, and do not include any prohibited, hazardous, or illegal substances under applicable Indian laws, including the Motor Vehicles Act, 1988 (as amended in 2019) and other applicable regulations. I agree to pay all applicable charges, including platform fees and commissions, and acknowledge that Unload shall not be responsible for any payment gateway, banking, or transaction failures. I hereby provide my free, informed, and explicit consent for the collection, use, storage, and processing of my personal data, including location data, in accordance with the Privacy Policy and applicable data protection laws. I further agree to indemnify and hold harmless Unload, its owners, officers, and affiliates from any claims, damages, losses, liabilities, or legal proceedings arising out of my use of the platform or violation of these terms. I agree that any disputes arising out of or in connection with the use of this platform shall be subject to the exclusive jurisdiction of the competent courts at Cuttack, Odisha.'),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      '“By proceeding, you are entering into a legally binding electronic agreement under applicable Indian laws.”',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red[700],
                                        fontStyle: FontStyle.italic,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: ElevatedButton(
                          onPressed: isChecked
                              ? () {
                                  Navigator.pop(context); // Close bottom sheet
                                  _navigateToLogin(context); // Navigate
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[300],
                            disabledForegroundColor: Colors.grey[500],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: isChecked ? 2 : 0,
                          ),
                          child: const Text(
                            'Accept & Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTermsText(
      double screenWidth, bool isLargeScreen, BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: isLargeScreen ? 12 : 10,
      color: Colors.grey[600],
      height: 1.4,
    );
    final linkStyle = TextStyle(
      fontSize: isLargeScreen ? 12 : 10,
      color: Colors.black87,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
      decorationColor: Colors.black87,
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: screenWidth * _horizontalPaddingRatio),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: baseStyle,
            children: [
              const TextSpan(
                  text: 'By continuing, you agree that you have read and accept our '),
              TextSpan(
                text: 'Terms & Conditions',
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    HapticFeedback.selectionClick();
                    _launchURL('https://unloadweb.com/tc.html');
                  },
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: linkStyle,
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    HapticFeedback.selectionClick();
                    _launchURL('https://unloadweb.com/privacy.html');
                  },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context) {
    if (!context.mounted) return;

    // Proceed directly to login screen
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const Login(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.1, 0), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }
}