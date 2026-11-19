import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone dialer')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], 
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text("Support Chat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.forum_outlined, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 24),
              const Text(
                "Welcome to Unload",
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "We are currently optimizing our live chat for a better experience.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16, 
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "For urgent queries, please call us at:",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _makePhoneCall(context, "9438166637"),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.call, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "9438166637",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}