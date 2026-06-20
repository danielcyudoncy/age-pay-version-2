import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/data/models/levy_model.dart';
import 'package:cls/data/repositories/levy_repository.dart';
import 'package:cls/data/repositories/obligation_repository.dart';

final levyRepositoryProvider = Provider<LevyRepository>((ref) {
  return LevyRepository();
});

final levyListProvider = StreamProvider.autoDispose<List<LevyModel>>((ref) {
  final repo = ref.watch(levyRepositoryProvider);
  return repo.getAllLevies();
});

final activeLeviesProvider = StreamProvider.autoDispose<List<LevyModel>>((ref) {
  final repo = ref.watch(levyRepositoryProvider);
  return repo.getActiveLevies();
});

/// State for levy creation form
class LevyCreationState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final String? createdLevyId;

  const LevyCreationState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.createdLevyId,
  });

  LevyCreationState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    String? createdLevyId,
  }) {
    return LevyCreationState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
      createdLevyId: createdLevyId ?? this.createdLevyId,
    );
  }
}

class LevyCreationNotifier extends StateNotifier<LevyCreationState> {
  final LevyRepository _levyRepository;
  final ObligationRepository _obligationRepository;

  LevyCreationNotifier({
    required LevyRepository levyRepository,
    required ObligationRepository obligationRepository,
  })  : _levyRepository = levyRepository,
        _obligationRepository = obligationRepository,
        super(const LevyCreationState());

  Future<void> createLevy({
    required String title,
    required String description,
    required ObligationType type,
    required double amountPerMember,
    required DateTime dueDate,
    required String createdBy,
    String? targetGroup,
    List<String> memberIds = const [],
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final levy = LevyModel(
        id: '',
        title: title,
        description: description,
        type: type,
        amountPerMember: amountPerMember,
        dueDate: dueDate,
        createdBy: createdBy,
        targetGroup: targetGroup,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final levyId = await _levyRepository.createLevy(levy);

      // Auto-generate obligations for each member
      final createdAt = Timestamp.now();
      final obligations = memberIds.map((memberId) {
        return {
          'memberId': memberId,
          'levyId': levyId,
          'type': type.name,
          'title': title,
          'description': description,
          'amount': amountPerMember,
          'paidAmount': 0.0,
          'outstandingBalance': amountPerMember,
          'status': 'unpaid',
          'dueDate': Timestamp.fromDate(dueDate),
          'createdAt': createdAt,
          'updatedAt': createdAt,
        };
      }).toList();

      if (obligations.isNotEmpty) {
        await _obligationRepository.batchCreateFromMaps(obligations);
      }

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        createdLevyId: levyId,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const LevyCreationState();
  }
}

final levyCreationProvider =
    StateNotifierProvider.autoDispose<LevyCreationNotifier, LevyCreationState>(
  (ref) {
    return LevyCreationNotifier(
      levyRepository: ref.watch(levyRepositoryProvider),
      obligationRepository: ref.watch(obligationRepositoryProvider),
    );
  },
);

final obligationRepositoryProvider = Provider<ObligationRepository>((ref) {
  return ObligationRepository();
});
