/// A language MyMemory can translate to/from, identified by its plain
/// ISO 639-1 code (`'yo'`, `'fr'`, ...) — confirmed directly against the
/// live API (`langpair=en|yo`, `langpair=en|ig`, etc. all return real
/// translations) rather than sourced from the `mymemory_translate` pub.dev
/// package's own bundled language table, which is missing Yoruba and Igbo
/// entirely despite MyMemory itself supporting both. See CLAUDE.md Phase 5
/// batch 2 for why this project doesn't depend on that package at all.
class TranslationLanguage {
  const TranslationLanguage({required this.code, required this.englishName, required this.nativeName});

  final String code;
  final String englishName;
  final String nativeName;
}

/// Curated, not exhaustive — MyMemory's own docs describe support as
/// "almost all languages" via plain ISO 639-1 codes with no fixed,
/// programmatically-fetchable list to draw from (there's no dedicated
/// supported-languages endpoint). Alphabetical by English name.
const List<TranslationLanguage> supportedTranslationLanguages = [
  TranslationLanguage(code: 'af', englishName: 'Afrikaans', nativeName: 'Afrikaans'),
  TranslationLanguage(code: 'sq', englishName: 'Albanian', nativeName: 'Shqip'),
  TranslationLanguage(code: 'am', englishName: 'Amharic', nativeName: 'አማርኛ'),
  TranslationLanguage(code: 'ar', englishName: 'Arabic', nativeName: 'العربية'),
  TranslationLanguage(code: 'hy', englishName: 'Armenian', nativeName: 'Հայերեն'),
  TranslationLanguage(code: 'az', englishName: 'Azerbaijani', nativeName: 'Azərbaycanca'),
  TranslationLanguage(code: 'eu', englishName: 'Basque', nativeName: 'Euskara'),
  TranslationLanguage(code: 'be', englishName: 'Belarusian', nativeName: 'Беларуская'),
  TranslationLanguage(code: 'bn', englishName: 'Bengali', nativeName: 'বাংলা'),
  TranslationLanguage(code: 'bs', englishName: 'Bosnian', nativeName: 'Bosanski'),
  TranslationLanguage(code: 'bg', englishName: 'Bulgarian', nativeName: 'Български'),
  TranslationLanguage(code: 'my', englishName: 'Burmese', nativeName: 'မြန်မာဘာသာ'),
  TranslationLanguage(code: 'ca', englishName: 'Catalan', nativeName: 'Català'),
  TranslationLanguage(code: 'ceb', englishName: 'Cebuano', nativeName: 'Cebuano'),
  TranslationLanguage(code: 'ny', englishName: 'Chichewa', nativeName: 'Chichewa'),
  TranslationLanguage(code: 'zh-CN', englishName: 'Chinese (Simplified)', nativeName: '简体中文'),
  TranslationLanguage(code: 'zh-TW', englishName: 'Chinese (Traditional)', nativeName: '繁體中文'),
  TranslationLanguage(code: 'co', englishName: 'Corsican', nativeName: 'Corsu'),
  TranslationLanguage(code: 'hr', englishName: 'Croatian', nativeName: 'Hrvatski'),
  TranslationLanguage(code: 'cs', englishName: 'Czech', nativeName: 'Čeština'),
  TranslationLanguage(code: 'da', englishName: 'Danish', nativeName: 'Dansk'),
  TranslationLanguage(code: 'nl', englishName: 'Dutch', nativeName: 'Nederlands'),
  TranslationLanguage(code: 'en', englishName: 'English', nativeName: 'English'),
  TranslationLanguage(code: 'eo', englishName: 'Esperanto', nativeName: 'Esperanto'),
  TranslationLanguage(code: 'et', englishName: 'Estonian', nativeName: 'Eesti'),
  TranslationLanguage(code: 'fi', englishName: 'Finnish', nativeName: 'Suomi'),
  TranslationLanguage(code: 'fr', englishName: 'French', nativeName: 'Français'),
  TranslationLanguage(code: 'fy', englishName: 'Frisian', nativeName: 'Frysk'),
  TranslationLanguage(code: 'gl', englishName: 'Galician', nativeName: 'Galego'),
  TranslationLanguage(code: 'ka', englishName: 'Georgian', nativeName: 'ქართული'),
  TranslationLanguage(code: 'de', englishName: 'German', nativeName: 'Deutsch'),
  TranslationLanguage(code: 'el', englishName: 'Greek', nativeName: 'Ελληνικά'),
  TranslationLanguage(code: 'gu', englishName: 'Gujarati', nativeName: 'ગુજરાતી'),
  TranslationLanguage(code: 'ht', englishName: 'Haitian Creole', nativeName: 'Kreyòl Ayisyen'),
  TranslationLanguage(code: 'ha', englishName: 'Hausa', nativeName: 'Harshen Hausa'),
  TranslationLanguage(code: 'haw', englishName: 'Hawaiian', nativeName: 'ʻŌlelo Hawaiʻi'),
  TranslationLanguage(code: 'he', englishName: 'Hebrew', nativeName: 'עברית'),
  TranslationLanguage(code: 'hi', englishName: 'Hindi', nativeName: 'हिन्दी'),
  TranslationLanguage(code: 'hmn', englishName: 'Hmong', nativeName: 'Hmoob'),
  TranslationLanguage(code: 'hu', englishName: 'Hungarian', nativeName: 'Magyar'),
  TranslationLanguage(code: 'is', englishName: 'Icelandic', nativeName: 'Íslenska'),
  TranslationLanguage(code: 'ig', englishName: 'Igbo', nativeName: 'Asụsụ Igbo'),
  TranslationLanguage(code: 'id', englishName: 'Indonesian', nativeName: 'Bahasa Indonesia'),
  TranslationLanguage(code: 'ga', englishName: 'Irish', nativeName: 'Gaeilge'),
  TranslationLanguage(code: 'it', englishName: 'Italian', nativeName: 'Italiano'),
  TranslationLanguage(code: 'ja', englishName: 'Japanese', nativeName: '日本語'),
  TranslationLanguage(code: 'jw', englishName: 'Javanese', nativeName: 'Basa Jawa'),
  TranslationLanguage(code: 'kn', englishName: 'Kannada', nativeName: 'ಕನ್ನಡ'),
  TranslationLanguage(code: 'kk', englishName: 'Kazakh', nativeName: 'Қазақ тілі'),
  TranslationLanguage(code: 'km', englishName: 'Khmer', nativeName: 'ខ្មែរ'),
  TranslationLanguage(code: 'rw', englishName: 'Kinyarwanda', nativeName: 'Ikinyarwanda'),
  TranslationLanguage(code: 'ko', englishName: 'Korean', nativeName: '한국어'),
  TranslationLanguage(code: 'ku', englishName: 'Kurdish', nativeName: 'Kurdî'),
  TranslationLanguage(code: 'ky', englishName: 'Kyrgyz', nativeName: 'Кыргызча'),
  TranslationLanguage(code: 'lo', englishName: 'Lao', nativeName: 'ລາວ'),
  TranslationLanguage(code: 'la', englishName: 'Latin', nativeName: 'Latina'),
  TranslationLanguage(code: 'lv', englishName: 'Latvian', nativeName: 'Latviešu'),
  TranslationLanguage(code: 'lt', englishName: 'Lithuanian', nativeName: 'Lietuvių'),
  TranslationLanguage(code: 'lb', englishName: 'Luxembourgish', nativeName: 'Lëtzebuergesch'),
  TranslationLanguage(code: 'mk', englishName: 'Macedonian', nativeName: 'Македонски'),
  TranslationLanguage(code: 'mg', englishName: 'Malagasy', nativeName: 'Malagasy'),
  TranslationLanguage(code: 'ms', englishName: 'Malay', nativeName: 'Bahasa Melayu'),
  TranslationLanguage(code: 'ml', englishName: 'Malayalam', nativeName: 'മലയാളം'),
  TranslationLanguage(code: 'mt', englishName: 'Maltese', nativeName: 'Malti'),
  TranslationLanguage(code: 'mi', englishName: 'Maori', nativeName: 'Te Reo Māori'),
  TranslationLanguage(code: 'mr', englishName: 'Marathi', nativeName: 'मराठी'),
  TranslationLanguage(code: 'mn', englishName: 'Mongolian', nativeName: 'Монгол'),
  TranslationLanguage(code: 'ne', englishName: 'Nepali', nativeName: 'नेपाली'),
  TranslationLanguage(code: 'no', englishName: 'Norwegian', nativeName: 'Norsk'),
  TranslationLanguage(code: 'or', englishName: 'Odia', nativeName: 'ଓଡ଼ିଆ'),
  TranslationLanguage(code: 'ps', englishName: 'Pashto', nativeName: 'پښتو'),
  TranslationLanguage(code: 'fa', englishName: 'Persian', nativeName: 'فارسی'),
  TranslationLanguage(code: 'pl', englishName: 'Polish', nativeName: 'Polski'),
  TranslationLanguage(code: 'pt', englishName: 'Portuguese', nativeName: 'Português'),
  TranslationLanguage(code: 'pa', englishName: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ'),
  TranslationLanguage(code: 'ro', englishName: 'Romanian', nativeName: 'Română'),
  TranslationLanguage(code: 'ru', englishName: 'Russian', nativeName: 'Русский'),
  TranslationLanguage(code: 'sm', englishName: 'Samoan', nativeName: 'Gagana Sāmoa'),
  TranslationLanguage(code: 'gd', englishName: 'Scots Gaelic', nativeName: 'Gàidhlig'),
  TranslationLanguage(code: 'sr', englishName: 'Serbian', nativeName: 'Српски'),
  TranslationLanguage(code: 'st', englishName: 'Sesotho', nativeName: 'Sesotho'),
  TranslationLanguage(code: 'sn', englishName: 'Shona', nativeName: 'ChiShona'),
  TranslationLanguage(code: 'sd', englishName: 'Sindhi', nativeName: 'سنڌي'),
  TranslationLanguage(code: 'si', englishName: 'Sinhala', nativeName: 'සිංහල'),
  TranslationLanguage(code: 'sk', englishName: 'Slovak', nativeName: 'Slovenčina'),
  TranslationLanguage(code: 'sl', englishName: 'Slovenian', nativeName: 'Slovenščina'),
  TranslationLanguage(code: 'so', englishName: 'Somali', nativeName: 'Soomaali'),
  TranslationLanguage(code: 'es', englishName: 'Spanish', nativeName: 'Español'),
  TranslationLanguage(code: 'su', englishName: 'Sundanese', nativeName: 'Basa Sunda'),
  TranslationLanguage(code: 'sw', englishName: 'Swahili', nativeName: 'Kiswahili'),
  TranslationLanguage(code: 'sv', englishName: 'Swedish', nativeName: 'Svenska'),
  TranslationLanguage(code: 'tl', englishName: 'Tagalog', nativeName: 'Tagalog'),
  TranslationLanguage(code: 'tg', englishName: 'Tajik', nativeName: 'Тоҷикӣ'),
  TranslationLanguage(code: 'ta', englishName: 'Tamil', nativeName: 'தமிழ்'),
  TranslationLanguage(code: 'tt', englishName: 'Tatar', nativeName: 'Татар'),
  TranslationLanguage(code: 'te', englishName: 'Telugu', nativeName: 'తెలుగు'),
  TranslationLanguage(code: 'th', englishName: 'Thai', nativeName: 'ไทย'),
  TranslationLanguage(code: 'tr', englishName: 'Turkish', nativeName: 'Türkçe'),
  TranslationLanguage(code: 'tk', englishName: 'Turkmen', nativeName: 'Türkmençe'),
  TranslationLanguage(code: 'uk', englishName: 'Ukrainian', nativeName: 'Українська'),
  TranslationLanguage(code: 'ur', englishName: 'Urdu', nativeName: 'اردو'),
  TranslationLanguage(code: 'ug', englishName: 'Uyghur', nativeName: 'ئۇيغۇرچە'),
  TranslationLanguage(code: 'uz', englishName: 'Uzbek', nativeName: "O'zbekcha"),
  TranslationLanguage(code: 'vi', englishName: 'Vietnamese', nativeName: 'Tiếng Việt'),
  TranslationLanguage(code: 'cy', englishName: 'Welsh', nativeName: 'Cymraeg'),
  TranslationLanguage(code: 'xh', englishName: 'Xhosa', nativeName: 'IsiXhosa'),
  TranslationLanguage(code: 'yi', englishName: 'Yiddish', nativeName: 'ייִדיש'),
  TranslationLanguage(code: 'yo', englishName: 'Yoruba', nativeName: 'Èdè Yorùbá'),
  TranslationLanguage(code: 'zu', englishName: 'Zulu', nativeName: 'IsiZulu'),
];

/// Case-insensitive substring match against English name, native name, or an
/// exact code match — empty [query] returns every language unfiltered. Pure
/// function so the search behavior is unit-testable without a widget.
List<TranslationLanguage> filterTranslationLanguages(
  String query, [
  List<TranslationLanguage> languages = supportedTranslationLanguages,
]) {
  final trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) return languages;
  return languages
      .where(
        (lang) =>
            lang.englishName.toLowerCase().contains(trimmed) ||
            lang.nativeName.toLowerCase().contains(trimmed) ||
            lang.code.toLowerCase() == trimmed,
      )
      .toList();
}

/// Looks up a language by its code — used to render a stored target-language
/// code (e.g. from Settings) as a display name. Returns null for a code not
/// in [supportedTranslationLanguages] (falls back to showing the raw code).
TranslationLanguage? translationLanguageForCode(String code) {
  for (final lang in supportedTranslationLanguages) {
    if (lang.code == code) return lang;
  }
  return null;
}
