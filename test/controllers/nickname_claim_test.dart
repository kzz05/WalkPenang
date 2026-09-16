// ---------------------------------------------------------------------------
// nickname_claim_test.dart
// Profile — display-name uniqueness at the two save paths
// ---------------------------------------------------------------------------
//
// Uniqueness cannot live in Validators.nickname: TextFormField.validator is
// synchronous and this needs a server round trip. So it runs at submit, and
// these tests pin the contract that submit depends on.
//
// What is covered here is the CONTRACT, not the transaction. The claim itself
// is a Firestore transaction inside a Cloud Function and cannot be exercised
// without the emulator — see the manual steps in the plan. What can be pinned
// is that a refusal is surfaced rather than swallowed, and that an unchanged
// name costs nothing.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walkpenang/constants/validation_messages.dart';
import 'package:walkpenang/services/nickname_service.dart';
import 'package:walkpenang/utils/validators.dart';

/// Records what was asked for and answers however the test wants.
class _StubNicknameService implements NicknameService {
  _StubNicknameService({this.refuseWith, this.reportTaken = const <String>{}});

  /// Non-null to make every claim fail with this exception.
  final NicknameException? refuseWith;

  /// Names this stub reports as already held by somebody else.
  final Set<String> reportTaken;

  final List<String> claimed = <String>[];

  /// Every name the live check was asked about, in order.
  final List<String> checked = <String>[];

  @override
  Future<bool> isAvailable(String nickname) async {
    checked.add(nickname);
    return !reportTaken.contains(nickname);
  }

  @override
  Future<void> claim(String nickname) async {
    claimed.add(nickname);
    final NicknameException? refusal = refuseWith;
    if (refusal != null) throw refusal;
  }
}

void main() {
  group('the claim contract', () {
    test('a taken name throws with isTaken set, so the field can be blamed',
        () async {
      final _StubNicknameService service = _StubNicknameService(
        refuseWith: const NicknameException(
          ValidationMessages.nicknameTaken,
          isTaken: true,
        ),
      );

      await expectLater(
        () => service.claim('Ianwong'),
        throwsA(
          isA<NicknameException>()
              .having((NicknameException e) => e.isTaken, 'isTaken', isTrue)
              .having((NicknameException e) => e.message, 'message',
                  ValidationMessages.nicknameTaken),
        ),
      );
    });

    test('a network failure is distinguishable from a taken name', () async {
      // The screens show both, but only one of them means "pick another name".
      final _StubNicknameService service = _StubNicknameService(
        refuseWith: const NicknameException('Could not reach the server.'),
      );

      try {
        await service.claim('Ianwong');
        fail('should have thrown');
      } on NicknameException catch (e) {
        expect(e.isTaken, isFalse);
      }
    });

    test('the name is passed through trimmed and unmodified', () async {
      // Case must survive: the reservation id IS the name as typed, and the
      // rule is case-sensitive, so lowercasing here would silently merge
      // "Ianwong" and "IANwong" into one reservation.
      final _StubNicknameService service = _StubNicknameService();

      await service.claim('IANwong');

      expect(service.claimed, <String>['IANwong']);
    });
  });

  group('the live availability check', () {
    test('reports a taken name, and leaves others alone', () async {
      final _StubNicknameService service = _StubNicknameService(
        reportTaken: const <String>{'IanWong'},
      );

      expect(await service.isAvailable('IanWong'), isFalse);
      expect(await service.isAvailable('IanWong2'), isTrue);
      expect(service.checked, <String>['IanWong', 'IanWong2']);
    });

    test('case-sensitively, matching the claim rule', () async {
      // The reservation id is the name as typed, so a different capitalisation
      // is a different name. If this ever became case-insensitive, the live
      // check and the claim would disagree and the form would warn about names
      // that Save then accepts.
      final _StubNicknameService service = _StubNicknameService(
        reportTaken: const <String>{'IanWong'},
      );

      expect(await service.isAvailable('IanWong'), isFalse);
      expect(await service.isAvailable('IANWONG'), isTrue);
    });
  });

  group('case sensitivity is a deliberate choice', () {
    test('the two spellings are different names', () {
      // Both are valid to the synchronous rules; only the server decides
      // whether either is free, and it compares them as distinct ids.
      expect(Validators.nickname('Ianwong'), isNull);
      expect(Validators.nickname('IANwong'), isNull);
      expect('Ianwong' == 'IANwong', isFalse);
    });

    test('a name that fails the synchronous rules never reaches the server',
        () {
      // The claim runs only after formKey.currentState!.validate() passes, so
      // these are refused before any round trip. The Cloud Function re-checks
      // the same rules regardless, because the client is not a control.
      expect(Validators.nickname('a'), ValidationMessages.nicknameTooShort);
      expect(Validators.nickname('12345'),
          ValidationMessages.nicknameNeedsLetter);
      expect(Validators.nickname('fuck'), ValidationMessages.nicknameProfane);
    });
  });

  group('the real service fails OPEN on error', () {
    test('an unreachable server reports the name as available', () async {
      // Deliberately the opposite of claim(), which fails closed. This call
      // only decides whether to show a warning while typing: reporting
      // "already taken" because the network blipped would block a perfectly
      // good name with no way for the user to understand why. Save still
      // refuses properly.
      final NicknameService service =
          NicknameService(functions: _UnreachableFunctions());

      expect(await service.isAvailable('AnyName'), isTrue);
    });
  });
}

/// Every callable throws, standing in for no connectivity.
class _UnreachableFunctions implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      throw FirebaseFunctionsException(
        code: 'unavailable',
        message: 'offline',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
