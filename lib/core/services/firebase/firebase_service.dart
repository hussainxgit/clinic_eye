// services/firebase/firebase_service.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  // Firebase instances
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  // Firestore operations
  Future<DocumentSnapshot> getDocument(String collection, String id) {
    return firestore.collection(collection).doc(id).get();
  }

  Future<QuerySnapshot> getCollection(String collection) {
    return firestore.collection(collection).get();
  }

  Future<QuerySnapshot> queryCollection(
    String collection,
    List<QueryFilter> filters, {
    String? orderBy,
    bool descending = false,
  }) {
    Query query = firestore.collection(collection);

    for (final filter in filters) {
      query = query.where(
        filter.field,
        isEqualTo: filter.isEqualTo,
        isGreaterThan: filter.isGreaterThan,
        isLessThan: filter.isLessThan,
        isGreaterThanOrEqualTo: filter.isGreaterThanOrEqualTo,
        isLessThanOrEqualTo: filter.isLessThanOrEqualTo,
        arrayContains: filter.arrayContains,
      );
    }

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    return query.get();
  }

  Future<DocumentReference> addDocument(
    String collection,
    Map<String, dynamic> data,
  ) {
    return firestore.collection(collection).add(data);
  }

  Future<void> setDocument(
    String collection,
    String id,
    Map<String, dynamic> data, {
    bool merge = false,
  }) {
    return firestore
        .collection(collection)
        .doc(id)
        .set(data, SetOptions(merge: merge));
  }

  Future<void> updateDocument(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) {
    return firestore.collection(collection).doc(id).update(data);
  }

  Future<void> deleteDocument(String collection, String id) {
    return firestore.collection(collection).doc(id).delete();
  }

  // Transactions
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) transactionHandler,
  ) {
    return firestore.runTransaction(transactionHandler);
  }

  // Batch operations
  WriteBatch getBatch() {
    return firestore.batch();
  }

  // Auth operations
  Future<UserCredential> signIn(String email, String password) {
    return auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return auth.signOut();
  }

  User? get currentUser => auth.currentUser;

  Stream<User?> get authStateChanges => auth.authStateChanges();

  // Storage operations
  Future<String> uploadFile(String path, Uint8List bytes) async {
    final ref = storage.ref().child(path);
    await ref.putData(bytes);
    return await ref.getDownloadURL();
  }

  Future<void> deleteFile(String path) {
    return storage.ref().child(path).delete();
  }
}

class QueryFilter {
  final String field;
  final dynamic isEqualTo;
  final dynamic isGreaterThan;
  final dynamic isLessThan;
  final dynamic isGreaterThanOrEqualTo;
  final dynamic isLessThanOrEqualTo;
  final dynamic arrayContains;

  QueryFilter({
    required this.field,
    this.isEqualTo,
    this.isGreaterThan,
    this.isLessThan,
    this.isGreaterThanOrEqualTo,
    this.isLessThanOrEqualTo,
    this.arrayContains,
  });
}
