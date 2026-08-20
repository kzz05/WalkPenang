import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:walkpenang/firebase_options.dart';
import 'package:walkpenang/models/place.dart';
import 'package:walkpenang/models/review.dart';

/// One-off tool: pushes the Discovery module's sample places (with real,
/// freely-licensed photo URLs from Wikimedia Commons) and their seed
/// reviews into Firestore.
///
/// Run once against whichever Firebase project firebase_options.dart points
/// at, then re-run any time to overwrite with this same data (doc ids are
/// fixed, so it's idempotent):
///   flutter run -t tool/seed_places.dart -d windows
///
/// Not part of the shipping app — nothing here is imported by lib/.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const _SeedApp());
}

class _SeedApp extends StatefulWidget {
  const _SeedApp();

  @override
  State<_SeedApp> createState() => _SeedAppState();
}

class _SeedAppState extends State<_SeedApp> {
  String _status = 'Seeding...';

  @override
  void initState() {
    super.initState();
    _seed();
  }

  Future<void> _seed() async {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    try {
      // Places are admin content — always safe to overwrite, so this batch
      // can re-run freely to push updated fields (e.g. new photo URLs).
      final WriteBatch placesBatch = db.batch();
      for (final Place place in _seedPlaces) {
        placesBatch.set(db.collection('places').doc(place.id), place.toMap());
      }
      await placesBatch.commit();

      // Reviews are create-only by rule (nobody should be able to overwrite
      // someone else's review), so re-seeding the same review ids after the
      // first successful run is expected to be denied — that's fine, it
      // just means they're already there.
      String reviewsMessage;
      try {
        final WriteBatch reviewsBatch = db.batch();
        for (final Review review in _seedReviews) {
          reviewsBatch.set(db.collection('reviews').doc(review.id), review.toMap());
        }
        await reviewsBatch.commit();
        reviewsMessage = '${_seedReviews.length} reviews';
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        reviewsMessage = 'reviews already present, skipped';
      }

      final String message =
          'Seeded ${_seedPlaces.length} places ($reviewsMessage).';
      debugPrint('SEED_RESULT: $message');
      setState(() => _status = message);
    } catch (e) {
      debugPrint('SEED_RESULT: FAILED: $e');
      setState(() => _status = 'Seed failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_status))),
      ),
    );
  }
}

const OpeningHours _dayHours = OpeningHours(opensAtHour: 8, closesAtHour: 19);
const OpeningHours _lateHours = OpeningHours(opensAtHour: 11, closesAtHour: 23);
const OpeningHours _morningHours = OpeningHours(opensAtHour: 7, closesAtHour: 16);
const OpeningHours _nightHours = OpeningHours(opensAtHour: 18, closesAtHour: 2);

/// Real Penang locations, matching MockPlaceRepository's sample set, with
/// real photos in place of the picsum.photos placeholders — mostly
/// Wikimedia Commons, plus two CC-licensed Flickr photos (via Openverse)
/// for the two venues Commons had no coverage of. Both Flickr photos need
/// attribution per their license if this app ever ships publicly:
///   - p01: "line clear nasi kandar plate" by goodiesfirst, CC BY 2.0
///     https://www.flickr.com/photos/49215102@N00/4431261734
///   - p05: "DSC01425" by Tomato Geezer, CC BY-ND 2.0
///     https://www.flickr.com/photos/13453601@N03/13525220213
final List<Place> _seedPlaces = <Place>[
  Place(
    id: 'p01',
    name: 'Nasi Kandar Line Clear',
    category: PlaceCategory.food,
    photoUrls: const <String>[
      'https://live.staticflickr.com/4031/4431261734_87b286712a_b.jpg',
    ],
    priceLevel: PriceLevel.budget,
    distanceKm: 0.3,
    rating: 4.5,
    reviewCount: 1820,
    address: '177 Jalan Penang, George Town, 10000 Penang',
    hours: _nightHours,
    contact: const ContactInfo(phone: '+60 4-261 4849'),
    priceRange: const PriceRange(minRm: 8, maxRm: 20),
    dietaryTags: const <DietaryPreference>{
      DietaryPreference.halal,
      DietaryPreference.noPork,
    },
    description: 'Late-night nasi kandar institution down a narrow alley.',
  ),
  Place(
    id: 'p02',
    name: 'Fort Cornwallis',
    category: PlaceCategory.heritage,
    photoUrls: const <String>[
      'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b2/Fort_Cornwallis%2C_Penang_2023_01.jpg/500px-Fort_Cornwallis%2C_Penang_2023_01.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/7/72/Sri_Rambai_Cannon%2C_Penang_George_Town_Fort_Cornwallis.jpg/500px-Sri_Rambai_Cannon%2C_Penang_George_Town_Fort_Cornwallis.jpg',
    ],
    priceLevel: PriceLevel.budget,
    distanceKm: 0.7,
    rating: 4.7,
    reviewCount: 2340,
    address: 'Jalan Light, George Town, 10200 Penang',
    hours: _dayHours,
    contact: const ContactInfo(
      phone: '+60 4-263 9855',
      website: 'https://www.penangmuseum.gov.my',
    ),
    priceRange: const PriceRange(minRm: 20, maxRm: 40, unit: 'entry'),
    description:
    'Star-shaped colonial fort on the waterfront, the largest intact '
        'fort in Malaysia.',
  ),
  Place(
    id: 'p03',
    name: 'Penang Hill',
    category: PlaceCategory.nature,
    photoUrls: const <String>[
      'https://upload.wikimedia.org/wikipedia/commons/thumb/8/82/Penang_Hil%2C_George_Town%2C_Penang_2023.jpg/500px-Penang_Hil%2C_George_Town%2C_Penang_2023.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/Penang_Hill_funicular_railway.jpg/500px-Penang_Hill_funicular_railway.jpg',
    ],
    priceLevel: PriceLevel.moderate,
    distanceKm: 1.2,
    rating: 4.6,
    reviewCount: 3105,
    address: 'Jalan Stesen Bukit Bendera, Air Itam, 11300 Penang',
    hours: _morningHours,
    contact: const ContactInfo(
      phone: '+60 4-828 8880',
      website: 'https://www.penanghill.gov.my',
    ),
    priceRange: const PriceRange(minRm: 30, maxRm: 80, unit: 'return ticket'),
    description: 'Funicular railway up to cooler air and a view of the strait.',
  ),
  Place(
    id: 'p04',
    name: 'Kek Lok Si Temple',
    category: PlaceCategory.heritage,
    photoUrls: const <String>[
      'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Kek_Lok_Si_at_dusk.jpg/500px-Kek_Lok_Si_at_dusk.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1f/Kek_Lok_Si_Temple_%28I%29.jpg/500px-Kek_Lok_Si_Temple_%28I%29.jpg',
    ],
    priceLevel: PriceLevel.budget,
    distanceKm: 2.1,
    rating: 4.8,
    reviewCount: 4210,
    address: 'Jalan Balik Pulau, Air Itam, 11500 Penang',
    hours: _dayHours,
    contact: const ContactInfo(phone: '+60 4-828 3317'),
    dietaryTags: const <DietaryPreference>{DietaryPreference.vegetarian},
    description: 'Hillside temple complex with a towering Guanyin statue.',
  ),
  Place(
    id: 'p05',
    name: 'China House',
    category: PlaceCategory.food,
    photoUrls: const <String>[
      'https://live.staticflickr.com/2926/13525220213_ddea75a03e_b.jpg',
    ],
    priceLevel: PriceLevel.moderate,
    distanceKm: 0.9,
    rating: 4.4,
    reviewCount: 1560,
    address: '153 Lebuh Pantai, George Town, 10300 Penang',
    hours: _lateHours,
    contact: const ContactInfo(
      phone: '+60 4-263 7299',
      website: 'https://www.chinahouse.com.my',
    ),
    priceRange: const PriceRange(minRm: 25, maxRm: 70),
    dietaryTags: const <DietaryPreference>{DietaryPreference.vegetarian},
    description: 'Long shophouse cafe known for its cake counter.',
  ),
  Place(
    id: 'p06',
    name: 'Pinang Peranakan Mansion',
    category: PlaceCategory.museum,
    photoUrls: const <String>[
      'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/Pinang_Peranakan_Mansion_%28I%29.jpg/500px-Pinang_Peranakan_Mansion_%28I%29.jpg',
    ],
    priceLevel: PriceLevel.moderate,
    distanceKm: 1.0,
    rating: 4.5,
    reviewCount: 1980,
    address: '29 Church Street, George Town, 10200 Penang',
    hours: _dayHours,
    contact: const ContactInfo(phone: '+60 4-264 2929'),
    priceRange: const PriceRange(minRm: 25, maxRm: 25, unit: 'entry'),
    description: 'Baba-Nyonya antiques inside a restored emerald mansion.',
  ),
  Place(
    id: 'p07',
    name: 'Gurney Plaza',
    category: PlaceCategory.shopping,
    photoUrls: const <String>[
      'https://upload.wikimedia.org/wikipedia/commons/thumb/3/32/Gurney_Plaza_at_night.jpg/500px-Gurney_Plaza_at_night.jpg',
    ],
    priceLevel: PriceLevel.moderate,
    distanceKm: 3.9,
    rating: 4.2,
    reviewCount: 2870,
    address: '170 Persiaran Gurney, 10250 Penang',
    hours: _lateHours,
    contact: const ContactInfo(website: 'https://www.gurneyplaza.com.my'),
    dietaryTags: const <DietaryPreference>{DietaryPreference.halal},
    description: 'Seafront mall with a food court on the top floor.',
  ),
  Place(
    id: 'p08',
    name: 'Chulia Street Night Hawkers',
    category: PlaceCategory.food,
    photoUrls: const <String>[
      'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5b/Chulia_Street_in_George_Town%2C_Penang.jpg/500px-Chulia_Street_in_George_Town%2C_Penang.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/b/be/Lebuh_Chulia%2C_George_Town_20250915_150409.jpg/500px-Lebuh_Chulia%2C_George_Town_20250915_150409.jpg',
    ],
    priceLevel: PriceLevel.budget,
    distanceKm: 0.6,
    rating: 4.3,
    reviewCount: 940,
    address: 'Lebuh Chulia, George Town, 10200 Penang',
    dietaryTags: const <DietaryPreference>{DietaryPreference.noBeef},
    description: 'Char kway teow and wan tan mee from dusk onwards.',
  ),
  Place(
    id: 'p09',
    name: 'Khoo Kongsi Clan House',
    category: PlaceCategory.heritage,
    photoUrls: const <String>[
      'https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/Khoo_Kongsi_%28I%29.jpg/500px-Khoo_Kongsi_%28I%29.jpg',
    ],
    priceLevel: PriceLevel.budget,
    distanceKm: 1.4,
    rating: 4.6,
    reviewCount: 1730,
    address: '18 Cannon Square, George Town, 10200 Penang',
    hours: _dayHours,
    contact: const ContactInfo(phone: '+60 4-261 4609'),
    priceRange: const PriceRange(minRm: 15, maxRm: 15, unit: 'entry'),
    description: 'Ornate clan temple at the heart of the George Town core.',
  ),
  Place(
    id: 'p10',
    name: 'Tropical Spice Garden',
    category: PlaceCategory.nature,
    photoUrls: const <String>[
      'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/Tropical_Spice_Garden_trail%2C_Penang_island_in_Malaysia.jpg/500px-Tropical_Spice_Garden_trail%2C_Penang_island_in_Malaysia.jpg',
    ],
    priceLevel: PriceLevel.moderate,
    distanceKm: 11.2,
    rating: 4.4,
    reviewCount: 1120,
    address: 'Lot 595 Jalan Teluk Bahang, 11100 Penang',
    hours: _dayHours,
    contact: const ContactInfo(
      phone: '+60 4-881 1797',
      website: 'https://tropicalspicegarden.com',
    ),
    priceRange: const PriceRange(minRm: 28, maxRm: 28, unit: 'entry'),
    dietaryTags: const <DietaryPreference>{
      DietaryPreference.vegetarian,
      DietaryPreference.vegan,
    },
    description: 'Terraced jungle garden with a cooking school.',
  ),
  Place(
    id: 'p11',
    name: 'Penang State Museum',
    category: PlaceCategory.museum,
    photoUrls: const <String>[
      'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/Penang_State_Museum%2C_Georgetown%2C_Penang%2C_Malaysia.JPG/500px-Penang_State_Museum%2C_Georgetown%2C_Penang%2C_Malaysia.JPG',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Farquhar_Street%2C_George_Town%2C_Penang.jpg/500px-Farquhar_Street%2C_George_Town%2C_Penang.jpg',
    ],
    priceLevel: PriceLevel.budget,
    distanceKm: 1.3,
    rating: 4.0,
    reviewCount: 680,
    address: 'Lebuh Farquhar, George Town, 10200 Penang',
    hours: _dayHours,
    contact: const ContactInfo(phone: '+60 4-226 1461'),
    priceRange: const PriceRange(minRm: 1, maxRm: 1, unit: 'entry'),
    description: 'Colonial-era building tracing the island settlement story.',
  ),
  Place(
    id: 'p12',
    name: 'Hin Bus Depot',
    category: PlaceCategory.shopping,
    photoUrls: const <String>[
      'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Cmglee_Penang_Hin_Bus_Depot_entrance.jpg/500px-Cmglee_Penang_Hin_Bus_Depot_entrance.jpg',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/4/40/Cmglee_Penang_Hin_Bus_Depot_interior.jpg/500px-Cmglee_Penang_Hin_Bus_Depot_interior.jpg',
    ],
    priceLevel: PriceLevel.moderate,
    distanceKm: 1.7,
    rating: 4.3,
    reviewCount: 1440,
    address: '31A Jalan Gurdwara, George Town, 10300 Penang',
    hours: _dayHours,
    dietaryTags: const <DietaryPreference>{DietaryPreference.vegetarian},
    description: 'Former bus depot turned art space and Sunday market.',
  ),
];

final List<Review> _seedReviews = <Review>[
  Review(
    id: 'rv01',
    placeId: 'p02',
    authorName: 'Maya R',
    rating: 5,
    body: 'Beautiful historic fort with amazing sea views. A must visit in '
        'George Town.',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
  Review(
    id: 'rv02',
    placeId: 'p02',
    authorName: 'Tan K',
    rating: 4,
    body: 'Great spot for photos at sunset. Can get crowded on weekends.',
    createdAt: DateTime.now().subtract(const Duration(days: 9)),
  ),
  Review(
    id: 'rv03',
    placeId: 'p02',
    authorName: 'Arif H',
    rating: 5,
    body: 'The cannon and the lighthouse are worth the entry fee. Bring water, '
        'there is very little shade.',
    createdAt: DateTime.now().subtract(const Duration(days: 21)),
  ),
  Review(
    id: 'rv04',
    placeId: 'p01',
    authorName: 'Siti N',
    rating: 5,
    body: 'Best nasi kandar on the island. Go late and order the ayam goreng.',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  Review(
    id: 'rv05',
    placeId: 'p01',
    authorName: 'James L',
    rating: 4,
    body: 'Queue moves fast even when it looks long. Cash only.',
    createdAt: DateTime.now().subtract(const Duration(days: 12)),
  ),
  Review(
    id: 'rv06',
    placeId: 'p03',
    authorName: 'Wei Ming',
    rating: 5,
    body: 'Take the funicular early to skip the queue. Much cooler at the top.',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
  Review(
    id: 'rv07',
    placeId: 'p04',
    authorName: 'Priya S',
    rating: 5,
    body: 'Stunning during Chinese New Year when the whole temple is lit up.',
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
  ),
];
