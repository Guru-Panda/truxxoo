import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'client_side_home.dart';

class ShipmentHistory {
  final String orderId;
  final String date;
  final String source;
  final String destination;
  final String truckType;
  final String status;
  final double amount;

  ShipmentHistory({
    required this.orderId,
    required this.date,
    required this.source,
    required this.destination,
    required this.truckType,
    required this.status,
    required this.amount,
  });
}

class ClientHistory extends StatefulWidget {
  // Add these parameters to preserve profile data
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

  final List<ShipmentHistory> _shipments = [
    ShipmentHistory(
      orderId: 'ORD001',
      date: '25 Jun 2024',
      source: 'Bhubaneswar',
      destination: 'Rourkela',
      truckType: 'Open Truck',
      status: 'Completed',
      amount: 5000.00,
    ),
    ShipmentHistory(
      orderId: 'ORD002',
      date: '22 Jun 2024',
      source: 'Cuttack',
      destination: 'Sambalpur',
      truckType: 'Container',
      status: 'In Transit',
      amount: 8000.00,
    ),
    ShipmentHistory(
      orderId: 'ORD003',
      date: '20 Jun 2024',
      source: 'Puri',
      destination: 'Berhampur',
      truckType: 'MCV',
      status: 'Cancelled',
      amount: 6500.00,
    ),
  ];

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

  // Updated back button interceptor
  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    // Check if there's a dialog or bottom sheet open
    if (Navigator.of(context).canPop() && ModalRoute.of(context)?.isCurrent != true) {
      return false; // Let the default behavior close the dialog/bottom sheet
    }

    // Navigate to home with profile data
    _navigateToHome();
    return true;
  }

  // Updated navigation method to preserve profile data
  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ClientSideHome(
          displayName: widget.displayName ?? 'Guru Prasad Panda',
          displayProfilePicture: widget.displayProfilePicture ?? 'assets/client_image.webp',
          isUsingLocalImage: widget.isUsingLocalImage,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in transit':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showOptions(BuildContext context, ShipmentHistory shipment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.blue),
              title: const Text('Get Receipt'),
              onTap: () {
                Navigator.pop(context);
                _getReceipt(shipment);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _shareShipment(shipment);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptWidget(ShipmentHistory shipment) {
    return Container(
      width: 400,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Text(
                      'TRUXOO',
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.withOpacity(0.1),
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #${shipment.orderId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(shipment.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          shipment.status,
                          style: TextStyle(
                            color: _getStatusColor(shipment.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                      const SizedBox(width: 8),
                      Text(
                        shipment.date,
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Shipment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('From', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  Text(shipment.source, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black)),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(Icons.arrow_forward, color: Colors.grey),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('To', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  Text(shipment.destination, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Truck Type', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(shipment.truckType, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Amount', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text('₹${shipment.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('TRUXOO', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.local_shipping, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Future<void> _getReceipt(ShipmentHistory shipment) async {
    try {
      await _showReceiptDialog(shipment, isForSharing: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareShipment(ShipmentHistory shipment) async {
    try {
      await _showReceiptDialog(shipment, isForSharing: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share shipment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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

                          if (isForSharing) {
                            await Share.shareXFiles(
                              [XFile(imagePath)],
                              text: 'Shipment Details #${shipment.orderId}',
                            );
                          }

                          if (mounted) {
                            Navigator.pop(context);
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to ${isForSharing ? 'share' : 'save'}: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(isForSharing ? Icons.share : Icons.download),
                    label: Text(isForSharing ? 'Share' : 'Save'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shipment History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateToHome, // Updated to use _navigateToHome
        ),
      ),
      body: _shipments.isEmpty
          ? const Center(
              child: Text(
                'No shipment history available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _shipments.length,
              itemBuilder: (context, index) {
                final shipment = _shipments[index];
                return InkWell(
                  onTap: () => _showOptions(context, shipment),
                  child: Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Order #${shipment.orderId}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(shipment.status)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      shipment.status,
                                      style: TextStyle(
                                        color: _getStatusColor(shipment.status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    shipment.date,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'From',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          shipment.source,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward,
                                    color: Colors.grey,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'To',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          shipment.destination,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Truck Type',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        shipment.truckType,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Amount',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '₹${shipment.amount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Icon(
                            Icons.more_vert,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}