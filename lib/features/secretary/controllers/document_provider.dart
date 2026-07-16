import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../repositories/document_repository.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository();
});

final documentControllerProvider = Provider<DocumentController>((ref) {
  return DocumentController(ref.watch(documentRepositoryProvider));
});

class DocumentController {
  final DocumentRepository _repository;
  DocumentController(this._repository);

  Future<String> createDocument(DocumentModel document) {
    return _repository.createDocument(document);
  }

  Future<void> updateDocument(DocumentModel document) {
    return _repository.updateDocument(document);
  }

  Future<void> deleteDocument(String id) {
    return _repository.deleteDocument(id);
  }

  Future<Map<String, String>> uploadFile(String documentId, File file, String fileName) {
    return _repository.uploadFile(documentId, file, fileName);
  }
}
