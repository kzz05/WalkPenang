import '../constants/profanity_wordlist.dart';

/// Blocks profanity in nicknames and review text.
///
/// Pure Dart with no Flutter dependency, like [Validators], so it plugs
/// straight into a `TextFormField.validator` and is unit-testable without a
/// widget binding.
///
/// ## Why a wordlist and not a model
///
/// The inputs this guards are a 2–30 character display name and a short
/// review. A toxicity model needs surrounding context to be better than a
/// list, and a nickname has none — so a curated list with normalisation is
/// both more accurate here and explainable, which a model's score is not.
///
/// ## What it defends against
///
/// Normalisation covers the three evasions people actually use:
///
/// | Input        | Normalised |
/// |--------------|------------|
/// | `Fuuuuck`    | `fuck`     |
/// | `f0ck`, `$hit` | `fock`, `shit` |
/// | `f.u.c.k`, `f u c k` | `fuck` |
///
/// ## What it deliberately does not do
///
/// **It never matches substrings.** `assalamualaikum` contains `ass`,
/// `analysis` contains `anal`, `Scunthorpe` contains `cunt`. A filter that
/// rejects a tourist's real name is a worse failure than one that lets a rude
/// word through, so matching is whole-word only and [profanityAllowlist] wins
/// over [profanityWordlist]. The false-positive suite in
/// test/utils/profanity_filter_test.dart is the guard on that promise.
///
/// It is also not a security boundary on its own — a client check is
/// bypassable. The Cloud Functions in functions/moderation.js re-run the same
/// list server-side; this class exists to give immediate feedback in the form.
class ProfanityFilter {
  const ProfanityFilter._();

  /// Characters people substitute for letters, mapped back before matching.
  static const Map<String, String> _leetMap = <String, String>{
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '8': 'b',
    '@': 'a',
    r'$': 's',
    '!': 'i',
  };

  static final RegExp _nonLetters = RegExp(r'[^a-z]+');
  static final RegExp _repeats = RegExp(r'(.)\1+');

  /// A run of single letters held apart by punctuation or spaces —
  /// `f.u.c.k`, `f u c k`. Four or more characters so ordinary prose such as
  /// "a b" is not folded together.
  ///
  /// Both boundary assertions are load-bearing, and the bug each prevents
  /// only appears once the text is a sentence rather than a bare word:
  ///
  /// - without `(?<![a-z])` the match starts mid-word and drags the previous
  ///   word's last letter in — "this is f.u.c.k.i.n.g awful" joined as
  ///   `sfucking`, taking the `s` from "is";
  /// - without `(?![a-z])` the greedy repetition runs past the end and takes
  ///   the next word's first letter — joining `fuckingt` from "… awful".
  ///
  /// Either way the result matches nothing, so the evasion succeeds in prose
  /// while still looking blocked when tested on its own.
  static final RegExp _spacedOut =
      RegExp(r'(?<![a-z])(?:[a-z][^a-z]+){3,}[a-z](?![a-z])');

  /// Whether [input] is free of blocked terms.
  static bool isClean(String? input) => firstMatch(input) == null;

  /// The first blocked term found in [input], or null when it is clean.
  ///
  /// Returns the matched term rather than a bool so a caller can log what
  /// tripped — the user-facing message deliberately never repeats it back.
  static String? firstMatch(String? input) {
    if (input == null || input.trim().isEmpty) return null;

    final String normalised = _applyLeet(input.toLowerCase());

    // 1. Whole-word matches, with and without runs of repeated letters.
    for (final String token in normalised.split(_nonLetters)) {
      if (token.isEmpty) continue;

      final String? hit = _checkToken(token);
      if (hit != null) return hit;
    }

    // 2. Letters deliberately spaced apart. Only the spaced run is joined —
    //    never the whole string — so "a bad classic pass" cannot be welded
    //    into a false positive.
    for (final RegExpMatch match in _spacedOut.allMatches(normalised)) {
      final String joined = match.group(0)!.replaceAll(_nonLetters, '');
      final String? hit = _checkToken(joined);
      if (hit != null) return hit;
    }

    return null;
  }

  /// Tests one word against the lists, in the order that keeps real names safe.
  ///
  /// The allowlist is consulted first and wins outright — that is what lets
  /// `cunt` sit in [profanityStrongTerms] without `Scunthorpe` being rejected.
  static String? _checkToken(String token) {
    if (token.isEmpty) return null;
    if (profanityAllowlist.contains(token)) return null;

    if (profanityWordlist.contains(token)) return token;

    // Concatenations: "WhiteFuck", "fuckyou", "xXbodohXx". Only the curated
    // strong subset is matched this way — see profanity_wordlist.dart for why
    // `rape`, `cock`, `dick` and friends are excluded.
    for (final String term in profanityStrongTerms) {
      if (token.contains(term)) return term;
    }

    final String collapsed = _collapseRepeats(token);
    if (collapsed == token || profanityAllowlist.contains(collapsed)) {
      return null;
    }
    if (profanityWordlist.contains(collapsed)) return collapsed;
    for (final String term in profanityStrongTerms) {
      if (collapsed.contains(term)) return term;
    }

    return null;
  }

  static String _applyLeet(String value) {
    final StringBuffer buffer = StringBuffer();
    for (final String char in value.split('')) {
      buffer.write(_leetMap[char] ?? char);
    }
    return buffer.toString();
  }

  /// `fuuuck` → `fuck`. Collapses every run to a single character, which also
  /// turns legitimate doubles (`pass` → `pas`) — harmless, because the result
  /// is only ever compared against the wordlist, never shown to anyone.
  static String _collapseRepeats(String value) =>
      value.replaceAllMapped(_repeats, (Match m) => m.group(1)!);
}
