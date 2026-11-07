import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_provider.dart';
import '../models/cash_handover_model.dart';
import '../repositories/cash_handover_repository.dart';

final cashHandoverRepositoryProvider = Provider<CashHandoverRepository>((ref) {
  return CashHandoverRepository();
});

final cashHandoversStreamProvider =
    StreamProvider.autoDispose<List<CashHandoverModel>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null || user.organizationId.isEmpty) {
    return Stream.value(<CashHandoverModel>[]);
  }

  final repo = ref.watch(cashHandoverRepositoryProvider);
  return repo.getHandovers(
    organizationId: user.organizationId,
    branchId: user.branchId,
  );
});

final pendingCashHandoversStreamProvider =
    StreamProvider.autoDispose<List<CashHandoverModel>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null || user.organizationId.isEmpty) {
    return Stream.value(<CashHandoverModel>[]);
  }

  final repo = ref.watch(cashHandoverRepositoryProvider);
  return repo.getPendingHandovers(
    organizationId: user.organizationId,
    branchId: user.branchId,
  );
});
