// ---------------------------------------------------------------------------
// profanity_parity_test.dart
// Content moderation — Dart/JS wordlist parity
// ---------------------------------------------------------------------------
//
// The filter exists twice: lib/utils/profanity_filter.dart runs in the app for
// instant feedback, and functions/profanity.js runs on the server as the
// actual enforcement. They have to be separate copies — one is Dart, one is
// Node — and that copy is the risk.
//
// If the two lists drift, the server stops agreeing with the form the user
// filled in: either a name the form accepted gets reverted seconds later, or a
// term the form blocks sails through when someone bypasses the client. Neither
// failure is visible until it happens to a real user.
//
// So this test reads the JavaScript file as text and checks the two lists
// still match, exactly as leaderboard_backfill_parity_test.dart does for the
// backfill script's hardcoded field names.

import 'dart:io';

import 'package:test/test.dart';
import 'package:walkpenang/constants/profanity_wordlist.dart';

/// Pulls a `const NAME = new Set([...])` block out of functions/profanity.js
/// and returns the quoted entries.
Set<String> _jsSet(String source, String constName) {
  final int start = source.indexOf('const $constName = new Set([');
  if (start < 0) {
    fail('functions/profanity.js no longer declares $constName — if it was '
        'renamed, update this test as well as the Dart list.');
  }
  final int end = source.indexOf(']);', start);
  final String body = source.substring(start, end);

  return RegExp('"([a-z]+)"')
      .allMatches(body)
      .map((RegExpMatch m) => m.group(1)!)
      .toSet();
}

void main() {
  late Set<String> jsWordlist;
  late Set<String> jsStrongTerms;
  late Set<String> jsAllowlist;

  setUpAll(() {
    final File file = File('functions/profanity.js');
    if (!file.existsSync()) {
      fail('functions/profanity.js is missing. The server-side filter is the '
          'enforcement half of this feature — the client check alone is '
          'bypassable.');
    }
    final String source = file.readAsStringSync();
    jsWordlist = _jsSet(source, 'PROFANITY_WORDLIST');
    jsStrongTerms = _jsSet(source, 'PROFANITY_STRONG_TERMS');
    jsAllowlist = _jsSet(source, 'PROFANITY_ALLOWLIST');
  });

  group('the server filter matches the client filter', () {
    test('wordlists are identical', () {
      expect(jsWordlist.difference(profanityWordlist), isEmpty,
          reason: 'these terms are blocked on the server but not in the app, '
              'so the form would accept text the server then removes');
      expect(profanityWordlist.difference(jsWordlist), isEmpty,
          reason: 'these terms are blocked in the app but not on the server, '
              'so bypassing the client would get them published');
    });

    test('strong-term lists are identical', () {
      // Drift here is the nastiest of the three: a term strong on one side and
      // not the other means "WhiteFuck" is blocked in the form but published
      // on bypass, or vice versa.
      expect(jsStrongTerms.difference(profanityStrongTerms), isEmpty);
      expect(profanityStrongTerms.difference(jsStrongTerms), isEmpty);
    });

    test('every strong term is also in the wordlist', () {
      // A strong term not in the wordlist would be matched inside words but
      // not as a word on its own, which is incoherent.
      expect(profanityStrongTerms.difference(profanityWordlist), isEmpty);
    });

    test('no strong term is also allowlisted', () {
      expect(profanityStrongTerms.intersection(profanityAllowlist), isEmpty);
    });

    test('allowlists are identical', () {
      expect(jsAllowlist.difference(profanityAllowlist), isEmpty);
      expect(profanityAllowlist.difference(jsAllowlist), isEmpty,
          reason: 'a word allowed in the app but not on the server means a '
              'legitimate name is accepted at signup and reverted moments '
              'later — the worst failure mode this feature has');
    });

    test('neither list is accidentally empty', () {
      // A parse that silently returned nothing would make both checks above
      // pass while proving nothing.
      expect(jsWordlist.length, greaterThan(20));
      expect(jsStrongTerms.length, greaterThan(10));
      expect(jsAllowlist.length, greaterThan(5));
    });
  });
}
