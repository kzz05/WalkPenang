/**
 * WalkPenang — server-side profanity filter.
 *
 * A mirror of lib/utils/profanity_filter.dart and
 * lib/constants/profanity_wordlist.dart. It has to be a copy rather than an
 * import because this runs on Node and that runs on Dart.
 *
 * THAT COPY IS THE RISK THIS FILE CARRIES. Rename or add a term on one side
 * and the two drift, and the server stops agreeing with the form the user
 * filled in. test/utils/profanity_parity_test.dart reads THIS file and asserts
 * the two lists still match, so a drift fails the Flutter test suite rather
 * than failing silently in production. If you edit the list here, edit
 * lib/constants/profanity_wordlist.dart the same way.
 *
 * Why a server copy exists at all: the client check in Validators is for
 * immediate feedback in the form and is trivially bypassed by anyone calling
 * Firestore directly. This one is the enforcement.
 */

// ── Keep in sync with lib/constants/profanity_wordlist.dart ────────────────
const PROFANITY_WORDLIST = new Set([
  // English
  "fuck", "fucker", "fucking", "fucked", "motherfucker",
  "shit", "shitty", "bullshit",
  "bitch", "bitches",
  "cunt",
  "asshole", "arsehole",
  "bastard",
  "dick", "dickhead",
  "cock",
  "pussy",
  "whore", "slut",
  "wanker",
  "twat",
  "prick",
  "nigger", "nigga",
  "faggot", "fag",
  "retard", "retarded",
  "rape", "rapist",

  // Malay / Malaysian
  "babi",
  "anjing",
  "sial", "celaka",
  "bangsat",
  "bodoh", "tolol", "bangang", "goblok",
  "pukimak", "pukima", "puki", "kimak",
  "lancau", "lanciao",
  "cibai", "cbai",
  "pantat",
  "konek",
  "jubur",
  "keparat",
  "haramjadah",
  "pelacur", "sundal", "lonte",
  "kanina", "knnccb", "ccb",
  "setan", "syaitan",
  "bengap",
  "sundel",
]);

// ── Keep in sync with profanityStrongTerms in the same Dart file ───────────
//
// Matched INSIDE a longer word, not only as a whole word — whole-word matching
// alone let "WhiteFuck" through, because that is one token and `whitefuck` is
// not in the list. Only terms that appear inside no legitimate word are here;
// `rape` (grape), `cock` (cockatoo), `dick` (Dickinson), `retard`
// (fire-retardant), `sial`, `setan`, `babi`, `konek` and `prick` are
// deliberately excluded and stay whole-word-only. See the Dart file.
const PROFANITY_STRONG_TERMS = new Set([
  "fuck", "shit", "bitch", "cunt",
  "asshole", "arsehole", "bastard", "dickhead",
  "pussy", "whore", "wanker",
  "nigger", "nigga", "faggot",

  "bodoh", "tolol", "bangang", "goblok",
  "pukimak", "pukima", "kimak",
  "cibai",
  "lancau", "lanciao",
  "bangsat",
  "celaka",
  "keparat",
  "haramjadah",
  "pelacur", "sundal", "lonte",
  "pantat",
  "jubur",
  "anjing",
  "bengap",
]);

// ── Keep in sync with profanityAllowlist in the same Dart file ─────────────
const PROFANITY_ALLOWLIST = new Set([
  "assalamualaikum",
  "analysis", "analyse", "analyst", "analytics",
  "classic", "class", "pass", "grass", "bass", "mass", "assam",
  "cocktail", "peacock", "shuttlecock", "cockle",
  "dickens",
  "scunthorpe",
  "sussex", "essex", "middlesex",
  "titan", "titanium",
  "constitution",
  "sialang",
  "panta", "pantai",
  "setanggi",
  "kanin",
]);

const LEET_MAP = {
  "0": "o", "1": "i", "3": "e", "4": "a", "5": "s",
  "7": "t", "8": "b", "@": "a", "$": "s", "!": "i",
};

const NON_LETTERS = /[^a-z]+/g;
const REPEATS = /(.)\1+/g;
// Both boundary assertions matter: without the lookbehind the match starts
// mid-word and drags the previous word's last letter in, and without the
// lookahead the greedy repetition takes the next word's first letter. Either
// way the joined run matches nothing. See profanity_filter.dart.
const SPACED_OUT = /(?<![a-z])(?:[a-z][^a-z]+){3,}[a-z](?![a-z])/g;

/** Maps leetspeak substitutions back to letters. */
function applyLeet(value) {
  let out = "";
  for (const char of value) out += LEET_MAP[char] || char;
  return out;
}

/** `fuuuck` → `fuck`. */
function collapseRepeats(value) {
  return value.replace(REPEATS, "$1");
}

/**
 * The first blocked term in `input`, or null when it is clean.
 *
 * Whole-word matching only — never substrings. `assalamualaikum` contains
 * "ass" and `Scunthorpe` contains "cunt"; rejecting a real name is a worse
 * failure than missing a swear word.
 *
 * @param {string|null|undefined} input text to check
 * @return {string|null} the matched term, or null
 */
function firstMatch(input) {
  if (!input || !String(input).trim()) return null;

  const normalised = applyLeet(String(input).toLowerCase());

  for (const token of normalised.split(NON_LETTERS)) {
    const hit = checkToken(token);
    if (hit) return hit;
  }

  // Letters deliberately spaced apart — only the spaced run is joined, never
  // the whole string, so ordinary prose cannot be welded into a match.
  const runs = normalised.match(SPACED_OUT) || [];
  for (const run of runs) {
    const hit = checkToken(run.replace(NON_LETTERS, ""));
    if (hit) return hit;
  }

  return null;
}

/**
 * Tests one word against the lists, allowlist first so `Scunthorpe` survives
 * `cunt` being a strong term.
 *
 * @param {string} token a single word, already normalised
 * @return {string|null} the matched term, or null
 */
function checkToken(token) {
  if (!token) return null;
  if (PROFANITY_ALLOWLIST.has(token)) return null;
  if (PROFANITY_WORDLIST.has(token)) return token;

  for (const term of PROFANITY_STRONG_TERMS) {
    if (token.includes(term)) return term;
  }

  const collapsed = collapseRepeats(token);
  if (collapsed === token || PROFANITY_ALLOWLIST.has(collapsed)) return null;
  if (PROFANITY_WORDLIST.has(collapsed)) return collapsed;
  for (const term of PROFANITY_STRONG_TERMS) {
    if (collapsed.includes(term)) return term;
  }

  return null;
}

/**
 * Whether `input` is free of blocked terms.
 *
 * @param {string|null|undefined} input text to check
 * @return {boolean} true when clean
 */
function isClean(input) {
  return firstMatch(input) === null;
}

module.exports = {
  PROFANITY_WORDLIST,
  PROFANITY_STRONG_TERMS,
  PROFANITY_ALLOWLIST,
  firstMatch,
  isClean,
};
