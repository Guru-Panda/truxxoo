import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'client_side_home.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart'; 

class ShipmentHistory {
  final String orderId;
  final String date;
  final String source;
  final String destination;
  final String truckType;
  final String status;
  final String amount;

  ShipmentHistory({
    required this.orderId,
    required this.date,
    required this.source,
    required this.destination,
    required this.truckType,
    required this.status,
    required this.amount,
  });

  // ✅ FIXED: Safe type-checking for Timestamps
  factory ShipmentHistory.fromFirestore(Map<String, dynamic> data) {
    String formattedDate = "N/A";
    if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
      DateTime dateTime = (data['createdAt'] as Timestamp).toDate();
      formattedDate = DateFormat('dd MMM yyyy').format(dateTime);
    } else if (data['date'] != null) {
      formattedDate = data['date'];
    }

    String displayAmount = "0";
    if (data['finalFare'] != null && (data['finalFare'] is num) && data['finalFare'] > 0) {
      displayAmount = "₹${data['finalFare']}";
    } else if (data['estimatedFare'] != null) {
      displayAmount = "₹${data['estimatedFare']}";
    }

    return ShipmentHistory(
      orderId: data['trackingId'] ?? 'Unknown',
      date: formattedDate,
      source: data['pickupAddress'] ?? data['pickupLocation'] ?? 'N/A',
      destination: data['dropAddress'] ?? data['dropLocation'] ?? 'N/A',
      truckType: data['vehicleType'] ?? data['truckType'] ?? 'Truck',
      status: data['status'] ?? 'Pending',
      amount: displayAmount,
    );
  }
}

class ClientHistory extends StatefulWidget {
  final String? displayName;
  final String? displayProfilePicture;
  final bool isUsingLocalImage;

  const ClientHistory({
    super.key,
    this.displayName,
    this.displayProfilePicture,
    this.isUsingLocalImage = false,
  });

  @override
  State<ClientHistory> createState() => _ClientHistoryState();
}

class _ClientHistoryState extends State<ClientHistory> {
  final WidgetsToImageController controller = WidgetsToImageController();

  FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'truxoodriver',
  );

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_backButtonInterceptor);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    super.dispose();
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (Navigator.of(context).canPop() && ModalRoute.of(context)?.isCurrent != true) {
      return false;
    }
    _navigateToHome();
    return true;
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ClientSideHome(
          displayName: widget.displayName ?? 'Guest',
          displayProfilePicture: widget.displayProfilePicture ?? 'assets/client_imag_high.jpg',
          isUsingLocalImage: widget.isUsingLocalImage,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed': return Colors.green;
      case 'in_transit':
      case 'accepted': return Colors.blue;
      case 'cancelled': return Colors.red;
      case 'pending': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').split(' ').map((str) => 
      str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1)}' : ''
    ).join(' ');
  }

  void _showOptions(BuildContext context, ShipmentHistory shipment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.blue),
              title: const Text('Get Receipt'),
              onTap: () { Navigator.pop(context); _getReceipt(shipment); },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text('Share Shipment'),
              onTap: () { Navigator.pop(context); _shareShipment(shipment); },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ FIXED: Better Async flow for Sharing (Pop dialog before share sheet)
  Future<void> _showReceiptDialog(ShipmentHistory shipment, {required bool isForSharing}) async {
    final WidgetsToImageController dialogController = WidgetsToImageController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WidgetsToImage(
              controller: dialogController,
              child: _buildReceiptWidget(shipment),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final bytes = await dialogController.capture();
                        if (bytes != null) {
                          final directory = await getTemporaryDirectory();
                          final imagePath = '${directory.path}/${isForSharing ? 'shipment' : 'receipt'}_${shipment.orderId}.png';
                          final imageFile = File(imagePath);
                          await imageFile.writeAsBytes(bytes);

                          if (mounted) Navigator.pop(context); // Pop first!

                          if (isForSharing) {
                            await Share.shareXFiles([XFile(imagePath)], text: 'Shipment Details #${shipment.orderId}');
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt saved to device'), backgroundColor: Colors.green));
                          }
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                      }
                    },
                    icon: Icon(isForSharing ? Icons.share : Icons.download),
                    label: Text(isForSharing ? 'Share' : 'Save'),
                  ),
                  OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for UI
  Future<void> _getReceipt(ShipmentHistory shipment) async => await _showReceiptDialog(shipment, isForSharing: false);
  Future<void> _shareShipment(ShipmentHistory shipment) async => await _showReceiptDialog(shipment, isForSharing: true);

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipment History', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _navigateToHome),
      ),
      body: user == null 
        ? const Center(child: Text("Please log in to view history"))
        : StreamBuilder<QuerySnapshot>(
            // ✅ FIXED: Added .limit(50) for performance
            stream: _firestore
                .collection('booking_requests')
                .where('clientId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No shipment history available', style: TextStyle(color: Colors.grey)));
              }

              final shipments = snapshot.data!.docs.map((doc) => ShipmentHistory.fromFirestore(doc.data() as Map<String, dynamic>)).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: shipments.length,
                itemBuilder: (context, index) {
                  final shipment = shipments[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      onTap: () => _showOptions(context, shipment),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text('Order #${shipment.orderId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: _getStatusColor(shipment.status).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Text(_formatStatus(shipment.status), style: TextStyle(color: _getStatusColor(shipment.status), fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(shipment.date, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildRouteRow(shipment),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(shipment.truckType, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text(shipment.amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
    );
  }

  Widget _buildRouteRow(ShipmentHistory shipment) {
    return Row(
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('From', style: TextStyle(color: Colors.grey, fontSize: 10)),
          Text(shipment.source, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        ])),
        const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('To', style: TextStyle(color: Colors.grey, fontSize: 10)),
          Text(shipment.destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13), textAlign: TextAlign.end),
        ])),
      ],
    );
  }

  // --- Receipt UI Builder (Unchanged) ---
  Widget _buildReceiptWidget(ShipmentHistory shipment) {
     return Container(
      width: 350,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('RECEIPT', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
              Icon(Icons.local_shipping, color: _getStatusColor(shipment.status), size: 30),
            ],
          ),
          const Divider(thickness: 2, color: Colors.black),
          const SizedBox(height: 16),
          Text('Order ID: ${shipment.orderId}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Date: ${shipment.date}'),
          const SizedBox(height: 20),
          _buildReceiptRow('Source', shipment.source),
          _buildReceiptRow('Destination', shipment.destination),
          _buildReceiptRow('Vehicle', shipment.truckType),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL AMOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(shipment.amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 24),
          const Center(child: Text('Thank you for using Unload!', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}