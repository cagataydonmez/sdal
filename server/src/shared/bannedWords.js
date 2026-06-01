// Content-moderation denylist for user-generated content (App Store 1.2).
//
// Source words are written in natural Turkish/English. They are normalized to a
// canonical match form (see normalizeForMatch) and matching is done in that
// same space, so a single root also catches inflected and lightly-obfuscated
// variants (e.g. "siktir" covers "siktirrr", "s1ktir", "siktirme").
//
// Admins can extend the list at runtime via the `filtre` table; this baseline
// is always-on so coverage does not depend on database seeding.

// Leetspeak / look-alike characters mapped to letters before matching.
const LEET_MAP = {
  '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's',
  '7': 't', '8': 'b', '9': 'g', '@': 'a', '$': 's',
  '£': 'l', '€': 'e', '!': 'i', '|': 'i',
};

// Turkish consonant diacritics folded to ASCII. NOTE: we deliberately do NOT
// fold "ı"->"i" so that the common word "sık" (often) never collides with the
// profanity "sik".
const TR_FOLD = { 'ş': 's', 'ç': 'c', 'ö': 'o', 'ü': 'u', 'ğ': 'g' };

/// Normalizes a token/word for denylist matching:
/// Turkish lowercase -> consonant fold -> leet substitution -> letters-only ->
/// collapse repeated letters.
export function normalizeForMatch(value) {
  const lower = String(value || '').toLocaleLowerCase('tr-TR');
  let out = '';
  for (const ch of lower) {
    if (Object.prototype.hasOwnProperty.call(TR_FOLD, ch)) out += TR_FOLD[ch];
    else if (Object.prototype.hasOwnProperty.call(LEET_MAP, ch)) out += LEET_MAP[ch];
    else out += ch;
  }
  out = out.replace(/[^\p{L}]+/gu, '');         // letters only
  out = out.replace(/(.)\1+/gu, '$1');          // collapse repeats
  return out;
}

// Turkish profanity, insults and slurs (natural spelling).
// Short roots that collide with everyday words (e.g. "göt"->"got" vs English
// "got", "döl"->"dol") are intentionally represented by safer compounds only.
const TR = [
  'amcık', 'amcuk', 'amınakoyayım', 'amınakoyim', 'amk', 'amq', 'aq',
  'sik', 'sikiş', 'sikik', 'sikim', 'sikici', 'sikko', 'siktir', 'sikeyim',
  'sikerim', 'siktirgit', 'sikimde', 'sikinde',
  'yarak', 'yarrak', 'yaraksız',
  'götveren', 'götoğlan', 'götlek', 'götlük', 'göto',
  'piç', 'piçkurusu', 'piçlik',
  'orospu', 'oruspu', 'orospuçocuğu',
  'kahpe', 'kahbe',
  'pezevenk', 'pezo',
  'gavat', 'kavat',
  'yavşak',
  'ibne', 'ipne',
  'boktan', 'boklu', 'bokumsu',
  'salak', 'aptal', 'gerizekalı', 'avanak', 'ahmak', 'dangalak', 'embesil',
  'beyinsiz', 'gerzek', 'mankafa', 'budala', 'şerefsiz', 'namussuz',
  'haysiyetsiz', 'onursuz', 'soysuz',
  'puşt', 'kaltak', 'sürtük', 'fahişe',
  'zürriyetsiz', 'zıkkım', 'taşşak', 'taşak',
  'kancık', 'godoş', 'pezevenklik',
];

// English profanity and slurs.
const EN = [
  'fuck', 'fuk', 'fck', 'fucker', 'fucking', 'motherfucker', 'muthafucka',
  'shit', 'shitty', 'bullshit', 'dipshit',
  'bitch', 'biatch',
  'asshole', 'dumbass', 'jackass',
  'cunt',
  'dickhead', 'dildo',
  'pussy',
  'bastard',
  'whore', 'slut', 'hooker',
  'nigger', 'nigga',
  'faggot', 'fagget',
  'retard', 'retarded',
  'cocksucker', 'cock',
  'wanker',
  'porn', 'porno', 'pornography',
  'rapist', 'molest', 'pedophile',
  'blowjob', 'handjob',
];

// Pre-normalized, de-duplicated baseline denylist.
export const DEFAULT_BANNED_WORDS = Array.from(
  new Set([...TR, ...EN].map(normalizeForMatch).filter((w) => w.length >= 2)),
);
