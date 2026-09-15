import 'package:flutter/foundation.dart';

/// A single user review (screens 03 and 05).
@immutable
class Review {
  const Review({
    required this.id,
    required this.placeId,
    required this.authorName,
    required this.rating,
    required this.body,
    required this.createdAt,
    this.photoCount = 0,
    this.userId = '',
    this.authorPhotoUrl,
  });

  final String id;
  final String placeId;
  final String authorName;

  /// Firebase uid of the tourist who wrote this, or '' when nobody in this app
  /// owns it — a Google-sourced review, or a document written before reviews
  /// carried an owner at all. Reviews are public, so this is not a filter: it
  /// is what lets the UI tell *your* review apart from everyone else's.
  final String userId;

  /// The author's picture, for Google-sourced reviews only.
  ///
  /// App reviews leave this null on purpose: their author's photo is resolved
  /// live from `public_profiles/{uid}` so that changing your picture updates
  /// reviews you wrote months ago. Freezing a URL here would reintroduce
  /// exactly the staleness this collection exists to fix.
  ///
  /// Never written to Firestore — see [toMap].
  final String? authorPhotoUrl;

  /// 1–5 whole stars, as the mockup's picker only offers whole values.
  final int rating;
  final String body;
  final DateTime createdAt;
  final int photoCount;

  /// Whether [uid] wrote this review — drives the "You" badge in the reviews
  /// list. A signed-out reader ([uid] == '') owns nothing, so an unowned
  /// legacy review never reads as theirs.
  bool isMine(String uid) => uid.isNotEmpty && userId == uid;

  /// 'MR' — the circle avatar in the reviews list.
  String get initials {
    final List<String> parts = authorName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// 'Just now', '2 days ago' — matches the mockup's relative timestamps.
  String relativeTime(DateTime now) {
    final Duration delta = now.difference(createdAt);
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) {
      return '${delta.inHours} hour${delta.inHours == 1 ? '' : 's'} ago';
    }
    if (delta.inDays < 7) {
      return '${delta.inDays} day${delta.inDays == 1 ? '' : 's'} ago';
    }
    final int weeks = delta.inDays ~/ 7;
    if (weeks < 5) return '$weeks week${weeks == 1 ? '' : 's'} ago';
    final int months = delta.inDays ~/ 30;
    return '$months month${months == 1 ? '' : 's'} ago';
  }

  /// Firestore document fields for the 'reviews' collection. The doc id
  /// carries [id], so it isn't repeated in the map.
  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'authorName': authorName,
      'rating': rating,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'photoCount': photoCount,
      'userId': userId,
    };
  }

  factory Review.fromMap(String id, Map<String, dynamic> map) {
    final String owner = map['userId'] as String? ?? '';
    final String storedName = map['authorName'] as String? ?? 'Anonymous';

    return Review(
      id: id,
      placeId: map['placeId'] as String? ?? '',
      authorName: _displayName(storedName, owner),
      rating: (map['rating'] as num?)?.toInt() ?? 5,
      body: map['body'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      photoCount: (map['photoCount'] as num?)?.toInt() ?? 0,
      userId: owner,
    );
  }

  /// Every review written before reviews carried an owner was stored with the
  /// literal author name 'You' — the submission modal hardcoded it — so those
  /// documents read as "You" to whoever opens the place, which is the bug that
  /// made reviews look like they followed the device. An unowned 'You' is
  /// nobody's, so show it as Anonymous rather than backfilling every old row.
  static String _displayName(String storedName, String owner) {
    if (owner.isEmpty && storedName.trim() == 'You') return 'Anonymous';
    return storedName;
  }

  /// Maps one of Google's own reviews (from Place Details (New)) into a
  /// [Review], so they can sit alongside app-submitted ones in the same
  /// list. Google reviews aren't writable by the app — [id] is just their
  /// resource name, unused for anything but the list key.
  factory Review.fromGooglePlace(String placeId, Map<String, dynamic> json) {
    final Map<String, dynamic>? text = json['text'] as Map<String, dynamic>?;
    final Map<String, dynamic>? originalText =
        json['originalText'] as Map<String, dynamic>?;
    final Map<String, dynamic>? author =
        json['authorAttribution'] as Map<String, dynamic>?;

    return Review(
      id: json['name'] as String? ?? 'google-${json.hashCode}',
      placeId: placeId,
      authorName: author?['displayName'] as String? ?? 'Google user',
      // Google gives us the reviewer's picture and the app used to throw it
      // away, so Google reviews sat next to app ones showing only initials.
      authorPhotoUrl: author?['photoUri'] as String?,
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      body: text?['text'] as String? ?? originalText?['text'] as String? ?? '',
      createdAt: DateTime.tryParse(json['publishTime'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Review && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Star-rating captions from the mockup ("Very good" under 4 stars).
String ratingCaption(int stars) {
  return switch (stars) {
    1 => 'Poor',
    2 => 'Fair',
    3 => 'Good',
    4 => 'Very good',
    5 => 'Excellent',
    _ => 'Tap to rate',
  };
}
