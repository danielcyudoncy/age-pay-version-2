import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_provider.dart';
import '../models/fiscal_period_model.dart';
import '../repositories/fiscal_period_repository.dart';

final fiscalPeriodRepositoryProvider = Provider<FiscalPeriodRepository>((ref) {
  return FiscalPeriodRepository();
});

final fiscalPeriodsStreamProvider =
    StreamProvider.autoDispose<List<FiscalPeriodModel>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null || user.organizationId.isEmpty) {
    return Stream.value(<FiscalPeriodModel>[]);
  }

  final repo = ref.watch(fiscalPeriodRepositoryProvider);
  return repo.getFiscalPeriods(
    organizationId: user.organizationId,
    branchId: user.branchId,
  );
});

final activeFiscalPeriodProvider =
    FutureProvider.autoDispose<FiscalPeriodModel?>((ref) async {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null || user.organizationId.isEmpty) return null;

  final repo = ref.watch(fiscalPeriodRepositoryProvider);
  return repo.getActiveFiscalPeriod(
    organizationId: user.organizationId,
    branchId: user.branchId,
  );
});

final selectedFiscalPeriodProvider =
    StateProvider<FiscalPeriodModel?>((ref) => null);
