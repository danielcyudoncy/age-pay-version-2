import 'package:flutter_test/flutter_test.dart';
import 'package:cls/features/meetings/models/meeting_model.dart';
import 'package:cls/features/meetings/models/meeting_resolution_model.dart';

void main() {
  group('MeetingResolutionModel & Adoption Protocol Tests', () {
    test('MeetingResolutionModel serializes to and from map cleanly', () {
      final dueDate = DateTime(2026, 12, 1);
      final completedAt = DateTime(2026, 12, 2);

      final resolution = MeetingResolutionModel(
        id: 'res_1',
        title: 'Draft welfare condolence letter',
        assigneeName: 'Chidi Secretary',
        dueDate: dueDate,
        isCompleted: true,
        completedAt: completedAt,
        completedBy: 'Amara President',
      );

      final map = resolution.toMap();
      expect(map['id'], 'res_1');
      expect(map['title'], 'Draft welfare condolence letter');
      expect(map['assigneeName'], 'Chidi Secretary');
      expect(map['isCompleted'], true);
      expect(map['completedBy'], 'Amara President');

      final deserialized = MeetingResolutionModel.fromMap(map);
      expect(deserialized.id, 'res_1');
      expect(deserialized.title, 'Draft welfare condolence letter');
      expect(deserialized.assigneeName, 'Chidi Secretary');
      expect(deserialized.isCompleted, true);
      expect(deserialized.completedBy, 'Amara President');
      expect(deserialized.dueDate, dueDate);
      expect(deserialized.completedAt, completedAt);
    });

    test('MeetingResolutionModel copyWith toggles completion state', () {
      final res = MeetingResolutionModel(
        id: 'res_2',
        title: 'Audit catering invoice',
        assigneeName: 'Emeka Auditor',
      );

      expect(res.isCompleted, false);
      expect(res.completedAt, isNull);

      final completedNow = DateTime.now();
      final toggled = res.copyWith(
        isCompleted: true,
        completedAt: completedNow,
        completedBy: 'Secretary',
      );

      expect(toggled.isCompleted, true);
      expect(toggled.completedAt, completedNow);
      expect(toggled.completedBy, 'Secretary');
    });

    test('MeetingModel correctly handles adoption protocol serialization', () {
      final meetingDate = DateTime(2026, 8, 10, 14, 0);
      final adoptedDate = DateTime(2026, 9, 14, 15, 30);

      final res1 = MeetingResolutionModel(
        id: 'r1',
        title: 'Procure canopy',
        assigneeName: 'Provost',
      );

      final meeting = MeetingModel(
        id: 'meet_aug_2026',
        title: 'August General Meeting',
        venue: 'Branch Town Hall',
        meetingDate: meetingDate,
        createdAt: meetingDate,
        updatedAt: meetingDate,
        createdBy: 'sec_1',
        isAdopted: true,
        adoptedAt: adoptedDate,
        movedBy: 'Elder John Okeke',
        secondedBy: 'Chief Ozoemena',
        adoptionNotes: 'Adopted unanimously without corrections.',
        resolutions: [res1],
      );

      final map = meeting.toFirestore();
      expect(map['isAdopted'], true);
      expect(map['movedBy'], 'Elder John Okeke');
      expect(map['secondedBy'], 'Chief Ozoemena');
      expect(map['adoptionNotes'], 'Adopted unanimously without corrections.');
      expect(map['resolutions'], isA<List>());
      expect((map['resolutions'] as List).length, 1);

      // Verify copyWith works with adoption and resolutions
      final updated = meeting.copyWith(
        adoptionNotes: 'Adopted with amendment to dues',
        resolutions: [
          res1,
          MeetingResolutionModel(id: 'r2', title: 'Collect outstanding levy'),
        ],
      );
      expect(updated.adoptionNotes, 'Adopted with amendment to dues');
      expect(updated.resolutions.length, 2);
      expect(updated.isAdopted, true);
      expect(updated.movedBy, 'Elder John Okeke');
    });

    test('MeetingModel copyWith preserves and updates adoption fields', () {
      final initial = MeetingModel(
        id: 'meet_1',
        title: 'General Meeting',
        venue: 'Hall',
        meetingDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'sec_1',
      );

      expect(initial.isAdopted, false);
      expect(initial.movedBy, isNull);

      final adopted = initial.copyWith(
        isAdopted: true,
        movedBy: 'Amara Okonkwo',
        secondedBy: 'Chidi Nnamdi',
        adoptionNotes: 'Confirmed with minor amendment to minute 4.',
      );

      expect(adopted.isAdopted, true);
      expect(adopted.movedBy, 'Amara Okonkwo');
      expect(adopted.secondedBy, 'Chidi Nnamdi');
      expect(adopted.adoptionNotes, 'Confirmed with minor amendment to minute 4.');
    });
  });
}
