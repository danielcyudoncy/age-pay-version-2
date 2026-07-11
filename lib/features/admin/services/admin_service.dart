import '../models/organization_model.dart';
import '../repositories/organization_repository.dart';

class AdminService {
  final OrganizationRepository _organizationRepository;

  AdminService({OrganizationRepository? organizationRepository})
    : _organizationRepository = organizationRepository ?? OrganizationRepository();

  Stream<List<OrganizationModel>> getActiveOrganizations() {
    return _organizationRepository.getOrganizations().map(
      (list) => list.where((org) => org.isActive).toList(),
    );
  }
}
