import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Raised when an OTP call fails, carrying a message fit to show the user.
class OtpException implements Exception {
  final String message;

  /// True when the failure is "you asked too soon" rather than a real error.
  final bool isCooldown;

  const OtpException(this.message, {this.isCooldown = false});

  @override
  String toString() => message;
}

/// Talks to the `sendEmailOtp` / `verifyEmailOtp` Cloud Functions.
///
/// The code itself is never generated or checked on the device — see
/// `functions/index.js` for why. This class only ferries requests and turns
/// Firebase's error codes into sentences a user can act on.
class OtpService {
  OtpService({FirebaseFunctions? functions, FirebaseAuth? auth})
      : _functions =
      functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  String get currentEmail => _auth.currentUser?.email ?? 'your email';

  /// Asks the server to mail a fresh code.
  ///
  /// Returns true if a code went out, false if the address was already
  /// verified (in which case the caller should just move on).
  Future<bool> sendCode() async {
    try {
      final result = await _functions.httpsCallable('sendEmailOtp').call();
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['alreadyVerified'] != true;
    } on FirebaseFunctionsException catch (e) {
      throw _translate(e);
    } catch (e) {
      throw const OtpException(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  /// Submits a code. Returns normally on success, throws [OtpException] with
  /// the reason on failure.
  Future<void> verifyCode(String code) async {
    try {
      await _functions.httpsCallable('verifyEmailOtp').call({'code': code});

      // The server flipped emailVerified via the Admin SDK; refresh the local
      // token so the rest of the app sees it without a sign-out.
      await _auth.currentUser?.reload();
      await _auth.currentUser?.getIdToken(true);
    } on FirebaseFunctionsException catch (e) {
      throw _translate(e);
    } catch (e) {
      throw const OtpException(
        'Could not reach the server. Check your connection.',
      );
    }
  }

  /// Cloud Functions error codes → something worth showing on screen.
  OtpException _translate(FirebaseFunctionsException e) {
    // The functions supply a specific message for the cases users hit most;
    // prefer it over anything generic invented here.
    final serverMessage = e.message;

    switch (e.code) {
      case 'resource-exhausted':
        return OtpException(
          serverMessage ?? 'Too many attempts. Wait a moment.',
          isCooldown: true,
        );
      case 'permission-denied':
        return OtpException(serverMessage ?? 'Incorrect code.');
      case 'deadline-exceeded':
        return OtpException(
          serverMessage ?? 'That code expired. Request a new one.',
        );
      case 'not-found':
        return OtpException(
          serverMessage ?? 'No code is waiting. Request a new one.',
        );
      case 'invalid-argument':
        return OtpException(serverMessage ?? 'Enter all 6 digits.');
      case 'unauthenticated':
        return const OtpException('Your session expired. Sign in again.');
      case 'unavailable':
      case 'internal':
        return OtpException(
          serverMessage ?? 'Verification service is unavailable right now.',
        );
      case 'not-found-function':
        return const OtpException(
          'Verification service is not deployed yet.',
        );
      default:
        return OtpException(serverMessage ?? 'Verification failed (${e.code}).');
    }
  }
}
