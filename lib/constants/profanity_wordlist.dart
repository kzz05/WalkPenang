/// The terms [ProfanityFilter] blocks in nicknames and review text.
///
/// English and Malay, because the app is a Penang tourism app and an
/// English-only list would leave the likeliest local abuse completely
/// unfiltered.
///
/// ## Rules for editing this file
///
/// **Entries are matched as whole words, never as substrings.** That is not an
/// implementation detail you may ignore when adding a term — it is what keeps
/// `assalamualaikum`, `analysis`, `classic` and `Scunthorpe` from being
/// rejected. Adding a short fragment here in the hope of catching more is how
/// a filter starts refusing people's real names, which is worse than letting a
/// swear word through. See [profanityAllowlist] and the false-positive suite
/// in test/utils/profanity_filter_test.dart.
///
/// **Keep entries lowercase and letters-only.** The filter normalises input
/// (leetspeak, repeated letters, letters spaced apart) before matching, so
/// `fuck` here already catches `Fuuuck`, `f0ck` and `f.u.c.k`. Adding those
/// variants by hand is redundant.
///
/// **Ambiguity is a reason to leave a word out.** Several Malay words are
/// vulgar in one register and ordinary in another — `butuh` is crude in Malay
/// but simply means "need" in Indonesian, so it is deliberately absent.
library;

/// Blocked terms. Lowercase, letters only, matched on word boundaries.
const Set<String> profanityWordlist = <String>{
  // ── English ───────────────────────────────────────────────────────────────
  'fuck', 'fucker', 'fucking', 'fucked', 'motherfucker',
  'shit', 'shitty', 'bullshit',
  'bitch', 'bitches',
  'cunt',
  'asshole', 'arsehole',
  'bastard',
  'dick', 'dickhead',
  'cock',
  'pussy',
  'whore', 'slut',
  'wanker',
  'twat',
  'prick',
  'nigger', 'nigga',
  'faggot', 'fag',
  'retard', 'retarded',
  'rape', 'rapist',

  // ── Malay / Malaysian ─────────────────────────────────────────────────────
  // Vulgar and abusive terms in common local use. Some are animal names used
  // as insults (babi, anjing) — they are here because the insulting use is
  // overwhelmingly what appears in a display name, not the zoological one.
  'babi',
  'anjing',
  'sial', 'celaka',
  'bangsat',
  'bodoh', 'tolol', 'bangang', 'goblok',
  'pukimak', 'pukima', 'puki', 'kimak',
  'lancau', 'lanciao',
  'cibai', 'cbai',
  'pantat',
  'konek',
  'jubur',
  'keparat',
  'haramjadah',
  'pelacur', 'sundal', 'lonte',
  'kanina', 'knnccb', 'ccb',
  'setan', 'syaitan',
  'bengap',
  'sundel',
};

/// Terms also matched *inside* a longer word, not only as a whole word.
///
/// Whole-word matching alone let `WhiteFuck` through: it is a single token,
/// and `whitefuck` is not in [profanityWordlist]. Anyone can defeat a
/// word-boundary filter by deleting a space, so the common evasion was also
/// the easiest one.
///
/// The reason this is a *subset* rather than the whole list is that substring
/// matching is where false positives come from, and they are not symmetrical
/// in cost — missing a rude username is an annoyance, rejecting someone's real
/// name is a product failure. So a term earns a place here only if it appears
/// inside essentially no legitimate word.
///
/// Deliberately excluded, with the word that excludes them:
///
/// | Term     | Would break        |
/// |----------|--------------------|
/// | `rape`   | g**rape**, d**rape**, sc**rape** |
/// | `cock`   | **cock**atoo, **cock**pit |
/// | `dick`   | **Dick**inson      |
/// | `retard` | fire-**retard**ant |
/// | `sial`   | Mar**sial**, **sial**ang |
/// | `setan`  | **setan**ggi       |
/// | `babi`   | Ba**bi**ta and similar names |
/// | `konek`  | **konek**tor (Indonesian: connector) |
/// | `prick`  | **prick**ed my finger — ordinary English |
///
/// Those stay whole-word-only via [profanityWordlist]. [profanityAllowlist] is
/// still checked first and still wins, which is what keeps `Scunthorpe`
/// working despite `cunt` being here.
const Set<String> profanityStrongTerms = <String>{
  // English — each contains no innocent word as a substring.
  'fuck', // covers fucking, motherfucker, WhiteFuck, fuckyou
  'shit', // covers shitty, bullshit, shitface
  'bitch',
  'cunt',
  'asshole', 'arsehole',
  'bastard',
  'dickhead',
  'pussy',
  'whore',
  'wanker',
  'nigger', 'nigga',
  'faggot',

  // Malay / Malaysian
  'bodoh', 'tolol', 'bangang', 'goblok',
  'pukimak', 'pukima', 'kimak',
  'cibai',
  'lancau', 'lanciao',
  'bangsat',
  'celaka',
  'keparat',
  'haramjadah',
  'pelacur', 'sundal', 'lonte',
  'pantat',
  'jubur',
  'anjing',
  'bengap',
};

/// Legitimate words that must never be rejected.
///
/// Word-boundary matching already prevents most false positives, so this is a
/// second line of defence for the cases normalisation could still mangle —
/// and a place to record, in code, the specific words this filter has been
/// checked against.
///
/// Anything here wins over [profanityWordlist].
const Set<String> profanityAllowlist = <String>{
  // Contain a blocked term as a substring. Listed so the intent is explicit
  // even though boundary matching handles them.
  'assalamualaikum',
  'analysis', 'analyse', 'analyst', 'analytics',
  'classic', 'class', 'pass', 'grass', 'bass', 'mass', 'assam',
  'cocktail', 'peacock', 'shuttlecock', 'cockle',
  'dickens',
  'scunthorpe',
  'sussex', 'essex', 'middlesex',
  'titan', 'titanium',
  'constitution',

  // Malay/Malaysian words and place names that brush against the list.
  'sialang',
  'panta', 'pantai', // 'Pantai' — beach; in half of Penang's place names.
  'setanggi',
  'kanin',
};
