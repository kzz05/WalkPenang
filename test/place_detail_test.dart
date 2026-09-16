import 'package:flutter_test/flutter_test.dart';

import 'package:walkpenang/models/place.dart';

/// T-FD03.3 — place detail edge cases.
///
/// Real listings are incomplete: no photos, no published hours, no phone
/// number. None of that may crash the detail screen or make it lie.
void main() {
  Place minimal({
    List<String> photos = const <String>[],
    OpeningHours? hours,
    ContactInfo contact = const ContactInfo(),
    PriceRange? priceRange,
    String description = '',
  }) {
    return Place(
      id: 'x',
      name: 'Test Place',
      category: PlaceCategory.food,
      photoUrls: photos,
      priceLevel: PriceLevel.budget,
      distanceKm: 1.0,
      rating: 4.0,
      reviewCount: 10,
      address: 'Somewhere in George Town',
      hours: hours,
      contact: contact,
      priceRange: priceRange,
      description: description,
    );
  }

  group('missing images', () {
    test('a place with no photos reports so', () {
      expect(minimal().hasPhotos, isFalse);
    });

    test('imageUrl is empty rather than null when there are no photos', () {
      // CachedNetworkImage needs a String, not null — an empty one falls
      // through to errorWidget, which is the behaviour we want.
      expect(minimal().imageUrl, '');
    });

    test('imageUrl is the first photo when photos exist', () {
      final Place place = minimal(
        photos: <String>['https://a.jpg', 'https://b.jpg'],
      );
      expect(place.imageUrl, 'https://a.jpg');
      expect(place.hasPhotos, isTrue);
    });
  });

  group('incomplete store hours', () {
    test('a place with no hours is not reported as open', () {
      final Place place = minimal();
      expect(place.hasHours, isFalse);
      expect(place.isOpenAt(DateTime(2026, 8, 7, 12)), isFalse);
    });

    test('normal daytime hours', () {
      final Place place = minimal(
        hours: const OpeningHours(opensAtHour: 8, closesAtHour: 19),
      );
      expect(place.isOpenAt(DateTime(2026, 8, 7, 12)), isTrue);
      expect(place.isOpenAt(DateTime(2026, 8, 7, 22)), isFalse);
      expect(place.isOpenAt(DateTime(2026, 8, 7, 7)), isFalse);
    });

    test('opening hour is inclusive, closing hour is exclusive', () {
      const OpeningHours hours =
      OpeningHours(opensAtHour: 8, closesAtHour: 19);
      expect(hours.isOpenAt(DateTime(2026, 8, 7, 8)), isTrue);
      expect(hours.isOpenAt(DateTime(2026, 8, 7, 19)), isFalse);
    });

    test('hours that wrap past midnight', () {
      // A stall trading 18:00 to 02:00.
      const OpeningHours hours =
      OpeningHours(opensAtHour: 18, closesAtHour: 2);
      expect(hours.isOpenAt(DateTime(2026, 8, 7, 20)), isTrue);
      expect(hours.isOpenAt(DateTime(2026, 8, 7, 1)), isTrue);
      expect(hours.isOpenAt(DateTime(2026, 8, 7, 12)), isFalse);
      expect(hours.isOpenAt(DateTime(2026, 8, 7, 3)), isFalse);
    });

    test('display range renders in 12-hour form', () {
      const OpeningHours day = OpeningHours(opensAtHour: 8, closesAtHour: 19);
      expect(day.displayRange, '8:00 AM - 7:00 PM');

      const OpeningHours midnight =
      OpeningHours(opensAtHour: 0, closesAtHour: 12);
      expect(midnight.displayRange, '12:00 AM - 12:00 PM');
    });
  });

  group('missing details', () {
    test('empty contact info reports itself as empty', () {
      const ContactInfo contact = ContactInfo();
      expect(contact.isEmpty, isTrue);
      expect(contact.hasPhone, isFalse);
      expect(contact.hasWebsite, isFalse);
    });

    test('a blank string counts as missing, not present', () {
      const ContactInfo contact = ContactInfo(phone: '', website: '');
      expect(contact.isEmpty, isTrue);
      expect(contact.hasPhone, isFalse);
    });

    test('partial contact info is not empty', () {
      const ContactInfo contact = ContactInfo(phone: '+60 4-261 4088');
      expect(contact.isEmpty, isFalse);
      expect(contact.hasPhone, isTrue);
      expect(contact.hasWebsite, isFalse);
    });

    test('a missing price range stays null rather than defaulting to zero', () {
      expect(minimal().priceRange, isNull);
    });

    test('a price range renders in ringgit', () {
      final Place place = minimal(
        priceRange: const PriceRange(minRm: 8, maxRm: 25),
      );
      expect(place.priceRange!.display, 'RM 8 - RM 25 per person');
    });

    test('whitespace-only description counts as missing', () {
      expect(minimal(description: '   ').hasDescription, isFalse);
      expect(minimal(description: 'Good food.').hasDescription, isTrue);
    });

    test('a place stripped of everything optional still constructs', () {
      final Place place = minimal();
      expect(place.name, 'Test Place');
      expect(place.hasPhotos, isFalse);
      expect(place.hasHours, isFalse);
      expect(place.contact.isEmpty, isTrue);
      expect(place.priceRange, isNull);
    });
  });

  group('display formatting', () {
    test('review counts get thousands separators', () {
      expect(Place.formatCount(2340), '2,340');
      expect(Place.formatCount(999), '999');
      expect(Place.formatCount(1000000), '1,000,000');
    });

    test('distance shows one decimal place', () {
      expect(minimal().distanceLabel, '1.0 km');
    });
  });
}