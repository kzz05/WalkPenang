import 'package:flutter/foundation.dart';

/// The publicly visible part of a tourist's profile: their display name and
/// their photo, and deliberately nothing else.
///
/// ## Why this exists as its own collection
///
/// A review has to show its author's *current* name and picture, not the ones
/// they had when they wrote it. The obvious source, `users/{uid}`, cannot be
/// used: firestore.rules restricts it to its owner, and it holds `email`,
/// `phoneNumber`, `weightKg` and `heightCm`. Opening that rule to resolve a
/// nickname would publish every tourist's phone number and body metrics.
///
/// `leaderboard/{uid}` is not a substitute either — FirestoreLeaderboardDao
/// skips anyone with zero points, so a tourist who reviewed a place but never
/// walked has no row there, and it needs sign-in to read while reviews are
/// world-readable.
///
/// So `public_profiles/{uid}` is a projection carrying exactly the two fields a
/// stranger is allowed to see. Keeping it to two is the point: anything added
/// here becomes world-readable, so a new field is a privacy decision, not a
/// convenience.
///
/// Written only by the `syncPublicProfile` Cloud Function — clients cannot
/// write it, so a display name cannot be forged.
@immutable
class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.displayName,
    this.photoUrl,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;

  /// Matches `kDefaultWalkerName` in leaderboard_entry_model.dart and the
  /// fallback the Cloud Function writes, so a blank nickname reads the same
  /// everywhere.
  static const String defaultName = 'Walker';

  /// 'OW' — the circle avatar when there is no photo. Same derivation as
  /// [Review.initials], so a reviewer's fallback avatar does not change
  /// character when their projection appears.
  String get initials {
    final List<String> parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory PublicProfile.fromMap(String id, Map<String, dynamic> map) {
    final String name = (map['displayName'] as String? ?? '').trim();
    final String photo = (map['photoUrl'] as String? ?? '').trim();

    return PublicProfile(
      userId: id,
      displayName: name.isEmpty ? defaultName : name,
      photoUrl: photo.isEmpty ? null : photo,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PublicProfile &&
          other.userId == userId &&
          other.displayName == displayName &&
          other.photoUrl == photoUrl);

  @override
  int get hashCode => Object.hash(userId, displayName, photoUrl);

  @override
  String toString() => 'PublicProfile($userId, $displayName)';
}
