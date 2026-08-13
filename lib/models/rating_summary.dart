import 'package:flutter/foundation.dart';

/// T-FD05.2 — a place's rating after new reviews are folded in.
///
/// The backend gives a seeded average over N reviews. Rather than refetching
/// the whole place after every submission, the new rating is folded into that
/// average incrementally:
///
///   newAverage = (oldAverage * oldCount + rating) / (oldCount + 1)
///
/// This is exact, not an approximation, as long as the seed pair is exact.
@immutable
class RatingSummary {
  const RatingSummary({required this.average, required this.count});

  final double average;
  final int count;

  /// Folds one more rating into the average.
  RatingSummary withReview(int rating) {
    assert(rating >= 1 && rating <= 5, 'rating must be 1-5, got $rating');
    final int nextCount = count + 1;
    final double nextAverage = ((average * count) + rating) / nextCount;
    return RatingSummary(average: nextAverage, count: nextCount);
  }

  /// Folds several at once — used when re-deriving from a stored list.
  RatingSummary withReviews(Iterable<int> ratings) {
    RatingSummary summary = this;
    for (final int rating in ratings) {
      summary = summary.withReview(rating);
    }
    return summary;
  }

  /// '4.7' — one decimal, matching the mockup.
  String get displayAverage => average.toStringAsFixed(1);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          (other is RatingSummary &&
              other.average == average &&
              other.count == count);

  @override
  int get hashCode => Object.hash(average, count);

  @override
  String toString() =>
      'RatingSummary(${average.toStringAsFixed(2)} over $count)';
}