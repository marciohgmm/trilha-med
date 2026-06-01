import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/osce_models.dart';

void main() {
  group('OsceRoomStatus', () {
    test('fromValue parseia estados da sala', () {
      expect(OsceRoomStatus.fromValue('running'), OsceRoomStatus.running);
      expect(OsceRoomStatus.fromValue('evaluating'), OsceRoomStatus.evaluating);
      expect(OsceRoomStatus.fromValue(null), OsceRoomStatus.waiting);
    });
  });

  group('OsceParticipantRole', () {
    test('fromValue mapeia aliases legados', () {
      expect(OsceParticipantRole.fromValue('actor'), OsceParticipantRole.evaluator);
      expect(OsceParticipantRole.fromValue('doctor'), OsceParticipantRole.evaluated);
      expect(OsceParticipantRole.fromValue('observer'), OsceParticipantRole.spectator);
    });

    test('labels em português', () {
      expect(OsceParticipantRole.evaluator.label, 'Avaliador');
      expect(OsceParticipantRole.evaluated.label, 'Médico avaliado');
    });
  });
}
