import 'dart:async'; // For StreamSubscription
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; 

// ✅ IMPORT OTP PAGE 
import 'otp.dart'; 

class DriverSearchingPage extends StatefulWidget {
  final String bookingId;
  final String trackingId;

  const DriverSearchingPage({
    super.key,
    required this.bookingId,
    required this.trackingId,
  });

  @override
  State<DriverSearchingPage> createState() => _DriverSearchingPageState();
}

class _DriverSearchingPageState extends State<DriverSearchingPage>
    with TickerProviderStateMixin {
  late AnimationController _dotController;
  int _dotCount = 0;
  
  // Stream to listen for driver acceptance
  StreamSubscription<DocumentSnapshot>? _bookingStream;

  @override
  void initState() {
    super.initState();
    _startDotAnimation();
    _listenForDriverAcceptance(); 
  }

  void _startDotAnimation() {
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _dotCount = (_dotCount + 1) % 4;
          });
          _dotController.reset();
          _dotController.forward();
        }
      });
    _dotController.forward();
  }

  // ✅ LISTEN TO FIRESTORE CHANGES
  void _listenForDriverAcceptance() {
    try {
      // Connect to the specific driver database
      FirebaseFirestore db;
      try {
        db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'truxoodriver');
      } catch (e) {
        // Fallback to default if named instance fails
        db = FirebaseFirestore.instance;
      }

      // Listen to the specific booking document
      _bookingStream = db.collection('booking_requests').doc(widget.bookingId).snapshots().listen((snapshot) {
        // If document is deleted (e.g. by cancel), snapshot.exists becomes false
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data() as Map<String, dynamic>;
          final status = data['status'];

          // ✅ CHECK STATUS: If driver accepted, go to OTP Page
          if (status == 'accepted') {
            if (mounted) {
              _bookingStream?.cancel(); // Stop listening to avoid memory leaks
              
              // Navigate to OTP Page (otp.dart)
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => OTPPage(
                    bookingId: widget.bookingId,
                    trackingId: widget.trackingId,
                  ),
                ),
              );
            }
          }
        }
      });
    } catch (e) {
      debugPrint("Error listening to booking: $e");
    }
  }

  @override
  void dispose() {
    _dotController.dispose();
    _bookingStream?.cancel(); // Clean up stream
    super.dispose();
  }

  String get _dots => '.' * _dotCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 1),
              
              // Lottie Animation
              SizedBox(
                height: 280,
                width: 280,
                child: Lottie.asset(
                  'assets/driver_search.json',
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: true,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.radar, size: 100, color: Colors.white);
                  },
                ),
              ),

              const SizedBox(height: 40),
              const Text(
                'Finding Your Ride',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 20),
              
              // Tracking ID
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    Text(
                    'ID: ${widget.trackingId}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              // "Searching..." Text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Searching for drivers',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    child: Text(
                      _dots,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),
              const PulsingIndicator(),
              const SizedBox(height: 50),
              
              // Cancel Button
              TextButton(
                onPressed: () => _showCancelDialog(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  'Cancel Request',
                  style: TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 45, 45, 60),
        title: const Text('Cancel Ride?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to cancel your ride request?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Connect to correct DB to cancel
                FirebaseFirestore db;
                try {
                  db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'truxoodriver');
                } catch (e) {
                  db = FirebaseFirestore.instance;
                }

                // ✅ 1. Stop the listener so it doesn't try to read a deleted doc
                _bookingStream?.cancel();

                // ✅ 2. DELETE the document from Firestore
                await db.collection('booking_requests')
                    .doc(widget.bookingId)
                    .delete();
                
                if (context.mounted) {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to Booking Page
                }
              } catch (e) {
                debugPrint("Error deleting request: $e");
                if(context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class PulsingIndicator extends StatefulWidget {
  const PulsingIndicator({super.key});

  @override
  State<PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<PulsingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 60, height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6C63FF).withOpacity(_animation.value),
                const Color(0xFF4ECDC4).withOpacity(_animation.value),
              ],
            ),
          ),
        );
      },
    );
  }
}