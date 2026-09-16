import 'package:cloud_functions/cloud_functions.dart';

import '../constants/validation_messages.dart';

/// Raised when a display name cannot be claimed, carrying a message fit to
/// show the user.
class NicknameException implements Exception {
  const NicknameException(this.message, {this.isTaken = false});

  final String message;

  /// True when another account holds the name, as opposed to a network or
  /// server failure. Lets a caller decide whether to blame the field or the
  /// connection.
  final bool isTaken;

  @override
  String toString() => message;
}

/// Reserves a tourist's display name so two accounts cannot share one.
///
/// ## Why this is a server call and not a validator
///
/// [Validators.nickname] is synchronous, because `TextFormField.validator` is.
/// Uniqueness needs a round trip, so it cannot live there and instead runs at
/// submit, after the synchronous rules have passed.
///
/// ## Why the claim happens on the server
///
/// A client that checked `nicknames/{name}` and then wrote it would race any
/// other client doing the same, and two simultaneous registrations could both
/// believe they won. `claimNickname` does the read and the write inside one
/// Firestore transaction with the Admin SDK, so exactly one wins. The
/// collection is `allow read, write: if false`, so the claim cannot be
/// bypassed or a name squatted by writing it directly.
///
/// ## Case sensitivity
///
/// Deliberately case-SENSITIVE: the document id is the name exactly as typed,
/// and Firestore ids are case-sensitive, so `Ianwong` and `IANwong` are
/// different names and may both exist. Only an exact clash is refused.
class NicknameService {
  NicknameService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  /// Claims [nickname] for the signed-in tourist, releasing whichever name
  /// they held before.
  ///
  /// Returns normally on success. Throws [NicknameException] with
  /// [NicknameException.isTaken] set when somebody else holds it.
  Future<void> claim(String nickname) async {
    try {
      await _functions
          .httpsCallable('claimNickname')
          .call<void>({'nickname': nickname});
    } on FirebaseFunctionsException catch (e) {
      throw _translate(e);
    } catch (_) {
      throw const NicknameException(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  /// Whether [nickname] is free for the signed-in tourist.
  ///
  /// Feeds the inline message under the field while they type. A name reserved
  /// to them already counts as available, so opening your own profile does not
  /// report your own name as taken.
  ///
  /// **Fails open** — any error returns true. This is the deliberate opposite
  /// of [claim], which fails closed, and the asymmetry is the point: this call
  /// only decides whether to show a warning, so a dropped connection saying
  /// "already taken" would block a perfectly good name with no way for the user
  /// to understand why. [claim] on save is what actually enforces uniqueness,
  /// and it refuses on any doubt.
  Future<bool> isAvailable(String nickname) async {
    try {
      final result = await _functions
          .httpsCallable('checkNicknameAvailable')
          .call<Map<String, dynamic>>({'nickname': nickname});
      return result.data['available'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  NicknameException _translate(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'already-exists':
        return const NicknameException(
          ValidationMessages.nicknameTaken,
          isTaken: true,
        );
      case 'invalid-argument':
        // The server re-runs the same shape and profanity checks the form did.
        // Reaching here means the two disagreed, so show what the server said.
        return NicknameException(
          e.message ?? ValidationMessages.nicknameInvalid,
        );
      case 'unauthenticated':
        return const NicknameException('Sign in first.');
      default:
        return const NicknameException(
          'Could not save that name right now. Please try again.',
        );
    }
  }
}
