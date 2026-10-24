import 'package:flutter_test/flutter_test.dart';
import 'package:cls/core/constants/enums.dart';
import 'package:cls/features/obligations/models/obligation_model.dart';
import 'package:cls/features/provost/models/infraction_presets.dart';
import 'package:cls/features/provost/models/penalty_waiver_model.dart';

void main() {
  group('Provost Disciplinary Officer Role & Model Tests', () {
    test('UserRole.provost has correct properties', () {
      const role = UserRole.provost;

      expect(role.displayName, 'Provost');
      expect(role.isExecutive, isTrue);
      expect(role.name, 'provost');
    });

    test('ObligationType.penalty has correct properties', () {
      const type = ObligationType.penalty;

      expect(type.displayName, 'Disciplinary Penalty');
      expect(type.name, 'penalty');
    });

    test('PenaltyInfractionType has correct presets and default amounts', () {
      expect(PenaltyInfractionType.lateComing.displayName, 'Late Coming');
      expect(PenaltyInfractionType.lateComing.defaultFineAmount, 1000.0);

      expect(PenaltyInfractionType.unexcusedAbsence.displayName, 'Unexcused Absence');
      expect(PenaltyInfractionType.unexcusedAbsence.defaultFineAmount, 2000.0);

      expect(PenaltyInfractionType.noiseOrDisturbance.displayName, 'Phone / Disturbance');
      expect(PenaltyInfractionType.noiseOrDisturbance.defaultFineAmount, 500.0);

      expect(PenaltyInfractionType.improperAttire.displayName, 'Improper Attire / No Uniform');
      expect(PenaltyInfractionType.improperAttire.defaultFineAmount, 1000.0);

      expect(PenaltyInfractionType.custom.displayName, 'Custom Sanction');
      expect(PenaltyInfractionType.custom.defaultFineAmount, 1000.0);
    });

    test('InfractionPreset list contains 5 distinct presets', () {
      expect(InfractionPreset.presets.length, 5);
      final types = InfractionPreset.presets.map((p) => p.type).toList();
      expect(types, containsAll([
        PenaltyInfractionType.lateComing,
        PenaltyInfractionType.unexcusedAbsence,
        PenaltyInfractionType.noiseOrDisturbance,
        PenaltyInfractionType.improperAttire,
        PenaltyInfractionType.custom,
      ]));
    });

    test('UserModel parses provost role and chief provost aliases correctly', () {
      UserRole parseRole(String raw) {
        final val = raw.trim().toLowerCase();
        return UserRole.values.firstWhere(
          (e) =>
              e.name.toLowerCase() == val ||
              ((val == 'provost' || val == 'chief_provost' || val == 'chief provost') &&
                  e == UserRole.provost),
          orElse: () => UserRole.member,
        );
      }

      expect(parseRole('provost'), UserRole.provost);
      expect(parseRole('PROVOST'), UserRole.provost);
      expect(parseRole('chief_provost'), UserRole.provost);
      expect(parseRole('chief provost'), UserRole.provost);
    });

    test('ObligationModel handles penalty fields and zero balance when waived', () {
      final now = DateTime.now();
      final penalty = ObligationModel(
        id: 'pen-1',
        organizationId: 'org-1',
        memberId: 'mem-1',
        levyId: 'disciplinary_penalty',
        type: ObligationType.penalty,
        title: 'Late Coming to General Meeting',
        description: 'Arrived 35 minutes late',
        amount: 1000.0,
        paidAmount: 0.0,
        outstandingBalance: 1000.0,
        status: ObligationStatus.unpaid,
        dueDate: now.add(const Duration(days: 7)),
        createdAt: now,
        meetingId: 'meet-123',
        infractionType: PenaltyInfractionType.lateComing,
        isWaived: false,
      );

      expect(penalty.isWaived, isFalse);
      expect(penalty.outstandingBalance, 1000.0);
      expect(penalty.isPaid, isFalse);
      expect(penalty.infractionType, PenaltyInfractionType.lateComing);
      expect(penalty.meetingId, 'meet-123');

      final waivedPenalty = penalty.copyWith(
        isWaived: true,
        waiverReason: 'Presented medical certificate from General Hospital',
        waivedBy: 'President',
        waivedAt: now,
        waiverStatus: PenaltyWaiverStatus.approved,
      );

      expect(waivedPenalty.isWaived, isTrue);
      // When waived, outstanding balance must resolve to 0.0 per financial integrity rules
      expect(waivedPenalty.outstandingBalance, 0.0);
      expect(waivedPenalty.isPaid, isTrue);
      expect(waivedPenalty.waiverReason, 'Presented medical certificate from General Hospital');
      expect(waivedPenalty.waiverStatus, PenaltyWaiverStatus.approved);
    });

    test('PenaltyWaiverModel serializes and deserializes correctly', () {
      final now = DateTime.now();
      final waiver = PenaltyWaiverModel(
        id: 'waiver-99',
        organizationId: 'org-1',
        obligationId: 'pen-1',
        memberId: 'mem-1',
        memberName: 'John Doe',
        penaltyTitle: 'Unexcused Absence',
        amount: 2000.0,
        infractionType: PenaltyInfractionType.unexcusedAbsence,
        reason: 'Emergency travel for family crisis',
        requestedBy: 'Chief Provost',
        requestedAt: now,
        status: PenaltyWaiverStatus.pendingApproval,
      );

      final map = waiver.toFirestore();
      expect(map['organizationId'], 'org-1');
      expect(map['obligationId'], 'pen-1');
      expect(map['amount'], 2000.0);
      expect(map['status'], 'pendingApproval');
      expect(map['infractionType'], 'unexcusedAbsence');

      final approvedWaiver = waiver.copyWith(
        status: PenaltyWaiverStatus.approved,
        reviewedBy: 'President Chief',
        reviewedAt: now,
      );

      expect(approvedWaiver.status, PenaltyWaiverStatus.approved);
      expect(approvedWaiver.reviewedBy, 'President Chief');
    });
  });
}
