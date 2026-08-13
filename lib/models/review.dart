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
  });

  final String id;
  final String placeId;
  final String authorName;

  /// 1–5 whole stars, as the mockup's picker only offers whole values.
  final int rating;
  final String body;
  final DateTime createdAt;
  final int photoCount;

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
