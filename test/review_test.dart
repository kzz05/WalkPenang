import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/models/rating_summary.dart';
import 'package:walkpenang/models/review.dart';
import 'package:walkpenang/views/widgets/review_submission_modal.dart';

/// T-FD05.3 — comment character limits, blank submission prevention,
/// and average-rating updates.
void main() {
  String repeat(int count) => 'a' * count;

  group('blank submission prevention', () {
    test('no rating is rejected', () {
      final String? error = ReviewSubmissionModal.validate(
        rating: 0,
        body: 'This place was genuinely excellent.',
      );
      expect(error, isNotNull);
      expect(error, contains('star rating'));
    });

    test('empty body is rejected', () {
      final String? error =
      ReviewSubmissionModal.validate(rating: 5, body: '');
      expect(error, isNotNull);
    });

    test('whitespace-only body is rejected', () {
      final String? error =
      ReviewSubmissionModal.validate(rating: 5, body: '        ');
      expect(error, isNotNull);
    });

    test('neither rating nor body reports the rating first', () {
      final String? error =
      ReviewSubmissionModal.validate(rating: 0, body: '');
      expect(error, contains('star rating'));
    });

    test('a complete review passes', () {
      final String? error = ReviewSubmissionModal.validate(
        rating: 4,
        body: 'Great spot for photos at sunset.',
      );
      expect(error, isNull);
    });
  });

  group('character limits', () {
    test('below the minimum is rejected', () {
      final String? error = ReviewSubmissionModal.validate(
        rating: 4,
        body: repeat(ReviewSubmissionModal.minBodyLength - 1),
      );
      expect(error, isNotNull);
      expect(error, contains('${ReviewSubmissionModal.minBodyLength}'));
    });

    test('exactly the minimum is accepted', () {
      final String? error = ReviewSubmissionModal.validate(
        rating: 4,
        body: repeat(ReviewSubmissionModal.minBodyLength),
      );
      expect(error, isNull);
    });

    test('exactly the maximum is accepted', () {
      final String? error = ReviewSubmissionModal.validate(
        rating: 4,
        body: repeat(ReviewSubmissionModal.maxBodyLength),
      );
      expect(error, isNull);
    });

    test('above the maximum is rejected', () {
      final String? error = ReviewSubmissionModal.validate(
        rating: 4,
        body: repeat(ReviewSubmissionModal.maxBodyLength + 1),
      );
      expect(error, isNotNull);
      expect(error, contains('${ReviewSubmissionModal.maxBodyLength}'));
    });

    test('length is measured after trimming', () {
      // Padding a too-short review with spaces must not sneak past.
      final String padded = '   ${repeat(5)}   ';
      expect(
        ReviewSubmissionModal.validate(rating: 4, body: padded),
        isNotNull,
      );
    });

    test('ratings outside 1-5 are rejected', () {
      expect(
        ReviewSubmissionModal.validate(rating: 6, body: repeat(20)),
        isNotNull,
      );
      expect(
        ReviewSubmissionModal.validate(rating: -1, body: repeat(20)),
        isNotNull,
      );
    });
  });

  group('average rating recalculation', () {
    test('one review folded into an existing average', () {
      // 4.0 over 10 reviews, plus a 5 → 45/11 = 4.09...
      const RatingSummary before = RatingSummary(average: 4.0, count: 10);
      final RatingSummary after = before.withReview(5);

      expect(after.count, 11);
      expect(after.average, closeTo(4.0909, 0.0001));
      expect(after.displayAverage, '4.1');
    });

    test('a low review pulls the average down', () {
      const RatingSummary before = RatingSummary(average: 4.5, count: 4);
      final RatingSummary after = before.withReview(1);

      // (4.5*4 + 1) / 5 = 19/5 = 3.8
      expect(after.average, closeTo(3.8, 0.0001));
      expect(after.count, 5);
    });

    test('the first review on an unrated place becomes the average', () {
      const RatingSummary empty = RatingSummary(average: 0, count: 0);
      final RatingSummary after = empty.withReview(4);

      expect(after.average, 4.0);
      expect(after.count, 1);
    });

    test('a matching review leaves the average unchanged', () {
      const RatingSummary before = RatingSummary(average: 4.0, count: 20);
      final RatingSummary after = before.withReview(4);

      expect(after.average, closeTo(4.0, 0.0001));
      expect(after.count, 21);
    });

    test('folding several one at a time matches folding them together', () {
      const RatingSummary start = RatingSummary(average: 3.0, count: 2);

      final RatingSummary stepwise =
      start.withReview(5).withReview(4).withReview(2);
      final RatingSummary batched = start.withReviews(<int>[5, 4, 2]);

      expect(stepwise.average, closeTo(batched.average, 0.0000001));
      expect(stepwise.count, batched.count);
    });

    test('order does not affect the result', () {
      const RatingSummary start = RatingSummary(average: 4.0, count: 5);

      final RatingSummary forward = start.withReviews(<int>[1, 3, 5]);
      final RatingSummary reverse = start.withReviews(<int>[5, 3, 1]);

      expect(forward.average, closeTo(reverse.average, 0.0000001));
    });

    test('a large existing count barely moves', () {
      const RatingSummary popular = RatingSummary(average: 4.7, count: 2340);
      final RatingSummary after = popular.withReview(1);

      expect(after.count, 2341);
      // Still rounds to 4.7 on screen.
      expect(after.displayAverage, '4.7');
    });

    test('display average is always one decimal place', () {
      expect(const RatingSummary(average: 4.0, count: 1).displayAverage, '4.0');
      expect(
        const RatingSummary(average: 3.96, count: 1).displayAverage,
        '4.0',
      );
      expect(
        const RatingSummary(average: 4.44, count: 1).displayAverage,
        '4.4',
      );
    });
  });

  group('review model', () {
    test('initials come from the author name', () {
      final Review review = Review(
        id: 'r1',
        placeId: 'p1',
        authorName: 'Ong Song Wei',
        rating: 5,
        body: 'Excellent.',
        createdAt: DateTime.now(),
      );
      expect(review.initials, 'OW');
    });

    test('a single-word name yields one initial', () {
      final Review review = Review(
        id: 'r1',
        placeId: 'p1',
        authorName: 'Maya',
        rating: 5,
        body: 'Nice.',
        createdAt: DateTime.now(),
      );
      expect(review.initials, 'M');
    });

    test('rating captions match the mockup', () {
      expect(ratingCaption(4), 'Very good');
      expect(ratingCaption(5), 'Excellent');
      expect(ratingCaption(0), 'Tap to rate');
    });

    test('relative timestamps read naturally', () {
      final DateTime now = DateTime(2026, 8, 7, 12);

      Review at(Duration ago) => Review(
        id: 'r',
        placeId: 'p',
        authorName: 'A B',
        rating: 5,
        body: '',
        createdAt: now.subtract(ago),
      );

      expect(at(Duration.zero).relativeTime(now), 'Just now');
      expect(at(const Duration(days: 2)).relativeTime(now), '2 days ago');
      expect(at(const Duration(days: 1)).relativeTime(now), '1 day ago');
      expect(at(const Duration(days: 14)).relativeTime(now), '2 weeks ago');
    });
  });
}