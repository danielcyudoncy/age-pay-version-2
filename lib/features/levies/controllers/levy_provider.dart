import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/levies/models/levy_model.dart';
import 'package:cls/features/levies/repositories/levy_repository.dart';
import 'package:cls/features/obligations/repositories/obligation_repository.dart';
import 'package:cls/features/auth/controllers/auth_provider.dart';
import 'package:cls/features/secretary/models/announcement_model.dart';
import 'package:cls/features/secretary/repositories/announcement_repository.dart';
import 'package:cls/features/secretary/controllers/announcement_provider.dart';
import 'package:cls/features/notifications/models/notification_model.dart';
import 'package:cls/features/notifications/repositories/notification_repository.dart';
import 'package:cls/features/notifications/controllers/notification_provider.dart';
import 'package:cls/features/national/controllers/national_provider.dart';

final levyRepositoryProvider = Provider<LevyRepository>((ref) {
  return LevyRepository();
});

final levyListProvider = StreamProvider.autoDispose<List<LevyModel>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) return const Stream.empty();

  final activeScope = ref.watch(activeExecutiveScopeProvider);
  final isNationalScope = activeScope == ExecutiveScope.national &&
      (user.nationalRole != null || user.role == UserRole.superAdmin);

  final repo = ref.watch(levyRepositoryProvider);
  return repo.getAllLevies().map((levies) {
    if (isNationalScope || user.role == UserRole.superAdmin) {
      return levies;
    }
    if (user.branchId != null && user.branchId!.isNotEmpty) {
      return levies.where((l) {
        return l.scope == 'national' || l.branchId == user.branchId;
      }).toList();
    }
    return levies;
  });
});

final activeLeviesProvider = StreamProvider.autoDispose<List<LevyModel>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) return const Stream.empty();

  final activeScope = ref.watch(activeExecutiveScopeProvider);
  final isNationalScope = activeScope == ExecutiveScope.national &&
      (user.nationalRole != null || user.role == UserRole.superAdmin);

  final repo = ref.watch(levyRepositoryProvider);
  return repo.getActiveLevies().map((levies) {
    if (isNationalScope || user.role == UserRole.superAdmin) {
      return levies;
    }
    if (user.branchId != null && user.branchId!.isNotEmpty) {
      return levies.where((l) {
        return l.scope == 'national' || l.branchId == user.branchId;
      }).toList();
    }
    return levies;
  });
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
  final NotificationRepository? _notificationRepository;
  final AnnouncementRepository? _announcementRepository;

  LevyCreationNotifier({
    required LevyRepository levyRepository,
    required ObligationRepository obligationRepository,
    NotificationRepository? notificationRepository,
    AnnouncementRepository? announcementRepository,
  }) : _levyRepository = levyRepository,
       _obligationRepository = obligationRepository,
       _notificationRepository = notificationRepository,
       _announcementRepository = announcementRepository,
       super(const LevyCreationState());

  Future<void> createLevy({
    required String title,
    required String description,
    required ObligationType type,
    required double amountPerMember,
    required DateTime dueDate,
    required String createdBy,
    String? targetGroup,
    String? organizationId,
    String scope = 'branch',
    String? branchId,
    String? branchName,
    List<String> memberIds = const [],
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final levy = LevyModel(
        id: '',
        organizationId: organizationId ?? '',
        title: title,
        description: description,
        type: type,
        amountPerMember: amountPerMember,
        dueDate: dueDate,
        createdBy: createdBy,
        targetGroup: targetGroup,
        scope: scope,
        branchId: branchId,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final levyId = await _levyRepository.createLevy(levy);

      // Auto-generate obligations: national levies apply to all branch members nationwide
      List<String> targetMemberIds = memberIds;
      if (scope.toLowerCase() == 'national') {
        try {
          final membersSnap = await FirebaseFirestore.instance
              .collection('members')
              .where('isActive', isEqualTo: true)
              .get();
          final allActiveMemberIds = membersSnap.docs
              .where((doc) {
                if (organizationId != null && organizationId.isNotEmpty) {
                  final data = doc.data();
                  final org = data['organizationId'];
                  if (org != null && org != organizationId) return false;
                }
                return true;
              })
              .map((d) => d.id)
              .toList();

          if (allActiveMemberIds.isNotEmpty) {
            targetMemberIds = allActiveMemberIds;
          }
        } catch (_) {}
      }

      final createdAt = Timestamp.now();
      final obligations = targetMemberIds.map((memberId) {
        return {
          'organizationId': organizationId ?? '',
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
          'scope': scope,
          // ignore: use_null_aware_elements
          if (branchId != null) 'branchId': branchId,
        };
      }).toList();

      if (obligations.isNotEmpty) {
        await _obligationRepository.batchCreateFromMaps(obligations);
      }

      // Automated broadcast announcements & in-app notifications
      final orgId = organizationId ?? '';
      if (orgId.isNotEmpty) {
        final formattedDueDate = DateFormat('EEEE, MMM dd, yyyy').format(dueDate);
        final formattedAmount = '₦${NumberFormat('#,##0.00').format(amountPerMember)}';
        final isNational = scope.toLowerCase() == 'national';
        final isEmergency = type == ObligationType.emergencyContribution;

        // 1. Post to Announcements
        if (_announcementRepository != null) {
          try {
            final announcement = AnnouncementModel(
              id: '',
              organizationId: orgId,
              title: isNational
                  ? '🏛️ National Decree: $title'
                  : (isEmergency
                      ? '🚨 Emergency Contribution: $title'
                      : '💳 New Financial Obligation: $title'),
              body: isNational
                  ? 'The National Financial Directorate has decreed a nationwide financial obligation for all members.\n\n'
                      '💰 Amount: $formattedAmount per member\n'
                      '📅 Due Date: $formattedDueDate\n'
                      '📌 Scope: National (All Branches)\n'
                      '📝 Description: $description\n\n'
                      'Please ensure timely compliance and remittance via the AgePay app.'
                  : 'A new financial obligation has been issued for ${branchName != null && branchName.isNotEmpty ? branchName : "your branch"}.\n\n'
                      '💰 Amount: $formattedAmount per member\n'
                      '📅 Due Date: $formattedDueDate\n'
                      '📝 Description: $description\n\n'
                      'Please settle your dues on or before the due date via the AgePay app.',
              category: isEmergency
                  ? AnnouncementCategory.emergency
                  : AnnouncementCategory.contribution,
              isPinned: isEmergency || isNational,
              announcementDate: dueDate,
              createdBy: createdBy,
              targetAudience: isNational ? 'all' : 'branch',
              targetBranchId: isNational ? null : branchId,
              targetBranchName: isNational ? null : branchName,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await _announcementRepository.createAnnouncement(announcement);
          } catch (_) {}
        }

        // 2. Dispatch In-App Notifications
        if (_notificationRepository != null) {
          try {
            // General member notification
            final memberNotification = NotificationModel(
              id: 'levy_${DateTime.now().millisecondsSinceEpoch}',
              organizationId: orgId,
              title: isNational
                  ? '🏛️ National Obligation: $title'
                  : (isEmergency
                      ? '🚨 Emergency Contribution: $title'
                      : '💳 New Due / Levy: $title'),
              body: '$formattedAmount due by $formattedDueDate. Tap to view and pay.',
              type: 'levy',
              targetBranchId: isNational ? null : branchId,
              payload: levyId,
              receivedAt: DateTime.now(),
            );
            await _notificationRepository.sendNotification(memberNotification);

            // If National scope, dispatch executive alert to Branch Executives & Treasurers
            if (isNational) {
              final executiveNotification = NotificationModel(
                id: 'exec_levy_${DateTime.now().millisecondsSinceEpoch}',
                organizationId: orgId,
                title: '📢 Executive Notice: National Levy Declared',
                body: 'National Financial Directorate announced "$title" ($formattedAmount). Please monitor branch member compliance.',
                type: 'levy',
                targetRole: 'executives',
                payload: levyId,
                receivedAt: DateTime.now(),
              );
              await _notificationRepository.sendNotification(executiveNotification);
            }
          } catch (_) {}
        }
      }

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        createdLevyId: levyId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = const LevyCreationState();
  }
}

final levyCreationProvider =
    StateNotifierProvider.autoDispose<LevyCreationNotifier, LevyCreationState>((
      ref,
    ) {
      return LevyCreationNotifier(
        levyRepository: ref.watch(levyRepositoryProvider),
        obligationRepository: ref.watch(obligationRepositoryProvider),
        notificationRepository: ref.watch(notificationRepositoryProvider),
        announcementRepository: ref.watch(announcementRepositoryProvider),
      );
    });

final obligationRepositoryProvider = Provider<ObligationRepository>((ref) {
  return ObligationRepository();
});
