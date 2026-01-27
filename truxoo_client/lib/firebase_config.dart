import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  // Private constructor (Singleton pattern)
  FirebaseConfig._();
  
  // Single instance
  static final FirebaseConfig instance = FirebaseConfig._();
  
  // The database reference - connects to 'truxoodriver' database
  FirebaseFirestore get db {
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'truxoodriver', // Your database name
    );
  }
}