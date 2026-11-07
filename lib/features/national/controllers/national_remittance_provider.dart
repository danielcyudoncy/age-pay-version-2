import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_provider.dart';
import '../models/national_remittance_model.dart';
import '../repositories/national_remittance_repository.dart';

final nationalRemittanceRepositoryProvider =
    Provider<NationalRemittanceRepository>((ref) {
  return NationalRemittanceRepository();
});

final nationalRemittancesStreamProvider =
    StreamProvider.autoDispose<List<NationalRemittanceModel>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null || user.organizationId.isEmpty) {
    return Stream.value(<NationalRemittanceModel>[]);
  }

  final repo = ref.watch(nationalRemittanceRepositoryProvider);
  return repo.getRemittances(
    organizationId: user.organizationId,
    branchId: user.branchId,
  );
});
