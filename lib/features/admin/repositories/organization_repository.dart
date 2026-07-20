import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/organization_model.dart';

class OrganizationRepository {
  final FirebaseFirestore _firestore;
  final String collection = 'organizations';

  OrganizationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _collection => _firestore.collection(collection);

  Stream<List<OrganizationModel>> getOrganizations() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => OrganizationModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// Public org list used by the register / org-picker screens, which run
  /// before the user is authenticated. The query is filtered to active,
  /// joinable orgs so it matches the Firestore read rule for anonymous users.
  Stream<List<OrganizationModel>> getPublicOrganizations() {
    return _collection
        .where('isActive', isEqualTo: true)
        .where('openForJoin', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => OrganizationModel.fromFirestore(doc))
                  .toList(),
        );
  }

  Future<OrganizationModel?> getOrganizationById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists) {
      return OrganizationModel.fromFirestore(doc);
    }
    return null;
  }

  Future<String> createOrganization(OrganizationModel organization) async {
    final docRef = _collection.doc();
    final newOrg = organization.copyWith(id: docRef.id);
    await docRef.set(newOrg.toFirestore());
    return docRef.id;
  }

  Future<void> updateOrganization(OrganizationModel organization) async {
    await _collection
        .doc(organization.id)
        .update(
          organization.copyWith(updatedAt: DateTime.now()).toFirestore(),
        );
  }

  Future<void> activateOrganization(String id) async {
    await _collection.doc(id).update({
      'isActive': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deactivateOrganization(String id) async {
    await _collection.doc(id).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> setOpenForJoin(String id, bool openForJoin) async {
    await _collection.doc(id).update({
      'openForJoin': openForJoin,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
