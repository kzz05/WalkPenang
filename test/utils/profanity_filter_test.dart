// ---------------------------------------------------------------------------
// profanity_filter_test.dart
// Content moderation — nickname and review text
// ---------------------------------------------------------------------------
//
// Two halves, and the second matters more than the first.
//
// Catching swear words is easy. The hard part — and the one that decides
// whether this filter is an asset or a liability — is NOT rejecting
// `assalamualaikum`, `Pantai Kerachut`, or somebody's actual name. A filter
// that blocks a tourist from registering under their own name is a worse
// product failure than one that lets a rude word through, so the
// false-positive group below is the real specification.

import 'package:test/test.dart';
import 'package:walkpenang/constants/profanity_wordlist.dart';
import 'package:walkpenang/utils/profanity_filter.dart';

void main() {
  group('catches profanity', () {
    test('plain English terms', () {
      expect(ProfanityFilter.isClean('fuck'), isFalse);
      expect(ProfanityFilter.isClean('what the shit'), isFalse);
      expect(ProfanityFilter.isClean('Bitch'), isFalse);
      expect(ProfanityFilter.isClean('you BASTARD'), isFalse);
    });

    test('Malay terms', () {
      expect(ProfanityFilter.isClean('babi'), isFalse);
      expect(ProfanityFilter.isClean('kau bodoh'), isFalse);
      expect(ProfanityFilter.isClean('Sial betul'), isFalse);
      expect(ProfanityFilter.isClean('pukimak'), isFalse);
    });

    test('regardless of surrounding punctuation', () {
      expect(ProfanityFilter.isClean('great place, shit service!'), isFalse);
      expect(ProfanityFilter.isClean('(fuck)'), isFalse);
      expect(ProfanityFilter.isClean('"babi"'), isFalse);
    });

    test('reports which term tripped, for logging', () {
      expect(ProfanityFilter.firstMatch('what the shit'), 'shit');
      expect(ProfanityFilter.firstMatch('perfectly nice review'), isNull);
    });
  });

  group('defeats the usual evasions', () {
    test('repeated letters', () {
      expect(ProfanityFilter.isClean('fuuuuck'), isFalse);
      expect(ProfanityFilter.isClean('shiiiit'), isFalse);
      expect(ProfanityFilter.isClean('baaabi'), isFalse);
    });

    test('leetspeak', () {
      expect(ProfanityFilter.isClean('sh1t'), isFalse);
      expect(ProfanityFilter.isClean(r'$hit'), isFalse);
      expect(ProfanityFilter.isClean('b1tch'), isFalse);
      expect(ProfanityFilter.isClean('b0doh'), isFalse);
    });

    test('letters spaced apart', () {
      expect(ProfanityFilter.isClean('f u c k'), isFalse);
      expect(ProfanityFilter.isClean('f.u.c.k'), isFalse);
      expect(ProfanityFilter.isClean('s-h-i-t'), isFalse);
      expect(ProfanityFilter.isClean('b a b i'), isFalse);
    });

    test('combinations of the above', () {
      expect(ProfanityFilter.isClean('F.U.C.K'), isFalse);
      expect(ProfanityFilter.isClean('b0d0h'), isFalse);
    });
  });

  group('catches profanity welded into a longer word', () {
    // The hole that shipped: whole-word matching alone passed "WhiteFuck",
    // because it is one token and `whitefuck` is in no list. Deleting a space
    // is the easiest evasion there is, so it has to be the best covered.
    test('concatenated with an ordinary word', () {
      expect(ProfanityFilter.isClean('WhiteFuck'), isFalse);
      expect(ProfanityFilter.isClean('fuckyou'), isFalse);
      expect(ProfanityFilter.isClean('shitface'), isFalse);
      expect(ProfanityFilter.isClean('xXbodohXx'), isFalse);
      expect(ProfanityFilter.isClean('SuperBitch99'), isFalse);
    });

    test('the innocent half of the word is still fine on its own', () {
      expect(ProfanityFilter.isClean('WhiteShark'), isTrue);
      expect(ProfanityFilter.isClean('SuperWalker'), isTrue);
    });

    test('reports the embedded term, not the whole token', () {
      expect(ProfanityFilter.firstMatch('WhiteFuck'), 'fuck');
    });
  });

  group('substring matching does not catch innocent words', () {
    // Every one of these contains a wordlist entry. They pass because those
    // entries are deliberately NOT in profanityStrongTerms — the table in
    // profanity_wordlist.dart names the word that excludes each one.
    test('terms excluded from the strong subset stay whole-word only', () {
      const Map<String, String> excludedBy = <String, String>{
        'grape': 'rape',
        'drape': 'rape',
        'scrape': 'rape',
        'cockatoo': 'cock',
        'cockpit': 'cock',
        'Dickinson': 'dick',
        'fire-retardant': 'retard',
        'konektor': 'konek',
      };

      excludedBy.forEach((String word, String term) {
        expect(ProfanityFilter.isClean(word), isTrue,
            reason: '"$word" contains "$term", which must stay whole-word '
                'only — see the exclusion table in profanity_wordlist.dart');
      });
    });

    test('the allowlist still beats a strong term', () {
      // `cunt` IS a strong term, so this only passes because the allowlist is
      // consulted first.
      expect(ProfanityFilter.isClean('Scunthorpe'), isTrue);
    });

    test('an ordinary sentence using an ambiguous word', () {
      expect(ProfanityFilter.isClean('I pricked my finger on the gate'),
          isTrue);
      expect(ProfanityFilter.isClean('We had a cocktail by the beach'),
          isTrue);
    });
  });

  group('does NOT reject legitimate text', () {
    test('words that contain a blocked term as a substring', () {
      // Each of these would be rejected by a naive `contains` check.
      const List<String> innocent = <String>[
        'Assalamualaikum',      // contains "ass"
        'analysis',             // contains "anal"
        'analyst',
        'classic',              // contains "ass"
        'class',
        'pass the salt',
        'grass',
        'Scunthorpe',           // contains "cunt" — the canonical example
        'cocktail',             // contains "cock"
        'peacock',
        'shuttlecock',
        'Sussex',
        'Dickens',
        'constitution',         // contains "tit"
        'titanium',
      ];

      for (final String value in innocent) {
        expect(ProfanityFilter.isClean(value), isTrue,
            reason: '"$value" is a legitimate word and must be accepted');
      }
    });

    test('Penang place names and Malay words', () {
      const List<String> local = <String>[
        'Pantai Kerachut',
        'Pantai Acheh',
        'Assam Laksa',
        'Kek Lok Si',
        'Batu Ferringhi',
        'Teluk Bahang',
        'Sungai Pinang',
        'Gurney Drive',
        'Setanggi',
      ];

      for (final String value in local) {
        expect(ProfanityFilter.isClean(value), isTrue,
            reason: '"$value" is a real Penang name and must be accepted');
      }
    });

    test('ordinary names', () {
      const List<String> names = <String>[
        'Tang Yue Hann',
        'Ong Song Wei',
        'Muhammad Irsyad',
        'Siti Nurhaliza',
        'Wei Seng',
        'Ian Wong',
        'Anjali',            // begins like "anjing" but is a real name
        'Cassandra',         // contains "ass"
        'Bassam',
      ];

      for (final String value in names) {
        expect(ProfanityFilter.isClean(value), isTrue,
            reason: '"$value" is a real name and must be accepted');
      }
    });

    test('ordinary review prose', () {
      const List<String> reviews = <String>[
        'Great food, friendly staff, would come again.',
        'A bit of a pass for me, but the view is lovely.',
        'The class of service here is excellent.',
        'Busy at night but worth the wait.',
      ];

      for (final String value in reviews) {
        expect(ProfanityFilter.isClean(value), isTrue, reason: value);
      }
    });

    test('empty and whitespace input is clean, not an error', () {
      expect(ProfanityFilter.isClean(null), isTrue);
      expect(ProfanityFilter.isClean(''), isTrue);
      expect(ProfanityFilter.isClean('   '), isTrue);
    });
  });

  group('the wordlist itself stays well-formed', () {
    test('entries are lowercase and letters-only', () {
      final RegExp lettersOnly = RegExp(r'^[a-z]+$');
      for (final String word in profanityWordlist) {
        expect(lettersOnly.hasMatch(word), isTrue,
            reason: '"$word" must be lowercase letters only — the filter '
                'normalises input before matching, so variants are redundant');
      }
    });

    test('no entry is so short it would be noise', () {
      // A two-letter entry would fire constantly once repeats are collapsed.
      for (final String word in profanityWordlist) {
        expect(word.length, greaterThanOrEqualTo(3), reason: word);
      }
    });

    test('the allowlist and the wordlist do not overlap', () {
      expect(profanityWordlist.intersection(profanityAllowlist), isEmpty);
    });
  });
}
