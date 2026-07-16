import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/document_model.dart';

class DocumentRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final String collection = 'documents';

  DocumentRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<DocumentModel>> getDocuments(String organizationId) {
    return _collection
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => DocumentModel.fromFirestore(doc))
                  .toList(),
        );
  }

  Future<String> createDocument(DocumentModel document) async {
    final docRef = _collection.doc();
    await docRef.set(document.toFirestore());
    return docRef.id;
  }

  Future<void> updateDocument(DocumentModel document) async {
    await _collection
        .doc(document.id)
        .update(document.copyWith(updatedAt: DateTime.now()).toFirestore());
  }

  Future<void> deleteDocument(String id) async {
    await _collection.doc(id).delete();
  }

  Future<Map<String, String>> uploadFile(
    String documentId,
    File file,
    String fileName,
  ) async {
    final ref = _storage.ref().child('documents/$documentId/$fileName');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    return {'url': url, 'name': fileName};
  }
}
