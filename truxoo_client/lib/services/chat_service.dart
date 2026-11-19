import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class ChatService {
  static const String _dbName = 'truxoodriver';

  static FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: _dbName,
      );

  // Helper to ensure phone numbers match perfectly (removes +91, spaces, etc.)
  static String _cleanId(String id) {
    String clean = id.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
    if (clean.length > 10 && clean.startsWith('91') && RegExp(r'^[0-9]+$').hasMatch(clean)) {
      return clean.substring(2);
    }
    return clean;
  }

  // Automatically routes the client to the correct person (Owner vs Individual)
  static Map<String, String> resolveChatDetails(String currentClientId, Map<String, dynamic> bookingData) {
    String targetReceiverId;

    if (bookingData['assignedByOwner'] != null && bookingData['owner_ph'] != null) {
      targetReceiverId = bookingData['owner_ph']; 
    } else {
      targetReceiverId = bookingData['driverPhone'] ?? 'unknown_driver'; 
    }

    // Generate a consistent, alphabetical Chat Room ID using CLEANED phone numbers
    List<String> ids = [_cleanId(currentClientId), _cleanId(targetReceiverId)];
    ids.sort();
    String chatRoomId = ids.join("_");

    return {
      'receiverId': targetReceiverId,
      'chatRoomId': chatRoomId,
    };
  }

  static Future<void> sendMessage(String chatRoomId, String senderId, String receiverId, String text) async {
    try {
      final timestamp = FieldValue.serverTimestamp();
      final messageData = {
        'text': text,
        'senderId': senderId,
        'timestamp': timestamp,
        'type': 'text',
      };

      await _db.collection('chats').doc(chatRoomId).collection('messages').add(messageData);

      await _db.collection('chats').doc(chatRoomId).set({
        'lastMessage': text,
        'lastTimestamp': timestamp,
        'participants': [senderId, receiverId],
      }, SetOptions(merge: true));
    } catch (e) {
      print("Client Chat Error: $e");
    }
  }

  static Stream<QuerySnapshot> getMessages(String chatRoomId) {
    return _db
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .orderBy('senderId', descending: false)
        .snapshots();
  }

  static Future<void> deleteMessage(String chatRoomId, String messageId) async {
    await _db.collection('chats').doc(chatRoomId).collection('messages').doc(messageId).delete();
  }
}