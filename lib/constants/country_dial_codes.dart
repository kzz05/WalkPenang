/// ISO-3166 countries with their international dialling codes.
///
/// Hand-held data rather than a package: WalkPenang has no `intl` dependency
/// and a third-party picker would not match the app's own field styling. A
/// country table is just data, and it never needs to go over the network.
///
/// The tourist picks their country and types only the national number, so
/// `users/{uid}.phoneNumber` holds bare digits and the dial code is derived
/// from [Country.dialCode] at display time.
class Country {
  /// ISO-3166-1 alpha-2, e.g. `MY`. This — not the dial code — is what is
  /// persisted, because `+1` alone covers the US, Canada and most of the
  /// Caribbean and so cannot restore which country the tourist picked.
  final String isoCode;
  final String name;

  /// Dialling prefix without the leading `+`, e.g. `60`.
  final String dialCode;

  const Country({
    required this.isoCode,
    required this.name,
    required this.dialCode,
  });

  /// `+60`, for display beside the field.
  String get displayDialCode => '+$dialCode';

  /// The flag as a regional-indicator pair, built from the ISO code so no
  /// image assets are needed. Android 8.0 — the app's minimum, per NFR-06 —
  /// ships Noto Color Emoji, which renders these.
  String get flagEmoji {
    const base = 0x1F1E6; // REGIONAL INDICATOR SYMBOL LETTER A
    final upper = isoCode.toUpperCase();
    if (upper.length != 2) return '';
    return String.fromCharCodes(
      upper.codeUnits.map((c) => base + (c - 0x41)),
    );
  }

  @override
  String toString() => '$isoCode $displayDialCode';
}

/// The country assumed for a profile saved before the picker existed, and the
/// default selection for a new one. WalkPenang is a Penang tourism app, so
/// Malaysia is the sensible default even though the audience is international.
const String kDefaultCountryIso = 'MY';

/// Every country, sorted by name.
const List<Country> kCountries = <Country>[
  Country(isoCode: 'AF', name: 'Afghanistan', dialCode: '93'),
  Country(isoCode: 'AX', name: 'Åland Islands', dialCode: '358'),
  Country(isoCode: 'AL', name: 'Albania', dialCode: '355'),
  Country(isoCode: 'DZ', name: 'Algeria', dialCode: '213'),
  Country(isoCode: 'AS', name: 'American Samoa', dialCode: '1'),
  Country(isoCode: 'AD', name: 'Andorra', dialCode: '376'),
  Country(isoCode: 'AO', name: 'Angola', dialCode: '244'),
  Country(isoCode: 'AI', name: 'Anguilla', dialCode: '1'),
  Country(isoCode: 'AG', name: 'Antigua and Barbuda', dialCode: '1'),
  Country(isoCode: 'AR', name: 'Argentina', dialCode: '54'),
  Country(isoCode: 'AM', name: 'Armenia', dialCode: '374'),
  Country(isoCode: 'AW', name: 'Aruba', dialCode: '297'),
  Country(isoCode: 'AC', name: 'Ascension Island', dialCode: '247'),
  Country(isoCode: 'AU', name: 'Australia', dialCode: '61'),
  Country(isoCode: 'AT', name: 'Austria', dialCode: '43'),
  Country(isoCode: 'AZ', name: 'Azerbaijan', dialCode: '994'),
  Country(isoCode: 'BS', name: 'Bahamas', dialCode: '1'),
  Country(isoCode: 'BH', name: 'Bahrain', dialCode: '973'),
  Country(isoCode: 'BD', name: 'Bangladesh', dialCode: '880'),
  Country(isoCode: 'BB', name: 'Barbados', dialCode: '1'),
  Country(isoCode: 'BY', name: 'Belarus', dialCode: '375'),
  Country(isoCode: 'BE', name: 'Belgium', dialCode: '32'),
  Country(isoCode: 'BZ', name: 'Belize', dialCode: '501'),
  Country(isoCode: 'BJ', name: 'Benin', dialCode: '229'),
  Country(isoCode: 'BM', name: 'Bermuda', dialCode: '1'),
  Country(isoCode: 'BT', name: 'Bhutan', dialCode: '975'),
  Country(isoCode: 'BO', name: 'Bolivia', dialCode: '591'),
  Country(isoCode: 'BQ', name: 'Bonaire, Sint Eustatius and Saba', dialCode: '599'),
  Country(isoCode: 'BA', name: 'Bosnia and Herzegovina', dialCode: '387'),
  Country(isoCode: 'BW', name: 'Botswana', dialCode: '267'),
  Country(isoCode: 'BR', name: 'Brazil', dialCode: '55'),
  Country(isoCode: 'IO', name: 'British Indian Ocean Territory', dialCode: '246'),
  Country(isoCode: 'BN', name: 'Brunei Darussalam', dialCode: '673'),
  Country(isoCode: 'BG', name: 'Bulgaria', dialCode: '359'),
  Country(isoCode: 'BF', name: 'Burkina Faso', dialCode: '226'),
  Country(isoCode: 'BI', name: 'Burundi', dialCode: '257'),
  Country(isoCode: 'CV', name: 'Cabo Verde', dialCode: '238'),
  Country(isoCode: 'KH', name: 'Cambodia', dialCode: '855'),
  Country(isoCode: 'CM', name: 'Cameroon', dialCode: '237'),
  Country(isoCode: 'CA', name: 'Canada', dialCode: '1'),
  Country(isoCode: 'KY', name: 'Cayman Islands', dialCode: '1'),
  Country(isoCode: 'CF', name: 'Central African Republic', dialCode: '236'),
  Country(isoCode: 'TD', name: 'Chad', dialCode: '235'),
  Country(isoCode: 'CL', name: 'Chile', dialCode: '56'),
  Country(isoCode: 'CN', name: 'China', dialCode: '86'),
  Country(isoCode: 'CX', name: 'Christmas Island', dialCode: '61'),
  Country(isoCode: 'CC', name: 'Cocos (Keeling) Islands', dialCode: '61'),
  Country(isoCode: 'CO', name: 'Colombia', dialCode: '57'),
  Country(isoCode: 'KM', name: 'Comoros', dialCode: '269'),
  Country(isoCode: 'CG', name: 'Congo', dialCode: '242'),
  Country(isoCode: 'CD', name: 'Congo (Democratic Republic)', dialCode: '243'),
  Country(isoCode: 'CK', name: 'Cook Islands', dialCode: '682'),
  Country(isoCode: 'CR', name: 'Costa Rica', dialCode: '506'),
  Country(isoCode: 'CI', name: 'Côte d\'Ivoire', dialCode: '225'),
  Country(isoCode: 'HR', name: 'Croatia', dialCode: '385'),
  Country(isoCode: 'CU', name: 'Cuba', dialCode: '53'),
  Country(isoCode: 'CW', name: 'Curaçao', dialCode: '599'),
  Country(isoCode: 'CY', name: 'Cyprus', dialCode: '357'),
  Country(isoCode: 'CZ', name: 'Czechia', dialCode: '420'),
  Country(isoCode: 'DK', name: 'Denmark', dialCode: '45'),
  Country(isoCode: 'DJ', name: 'Djibouti', dialCode: '253'),
  Country(isoCode: 'DM', name: 'Dominica', dialCode: '1'),
  Country(isoCode: 'DO', name: 'Dominican Republic', dialCode: '1'),
  Country(isoCode: 'EC', name: 'Ecuador', dialCode: '593'),
  Country(isoCode: 'EG', name: 'Egypt', dialCode: '20'),
  Country(isoCode: 'SV', name: 'El Salvador', dialCode: '503'),
  Country(isoCode: 'GQ', name: 'Equatorial Guinea', dialCode: '240'),
  Country(isoCode: 'ER', name: 'Eritrea', dialCode: '291'),
  Country(isoCode: 'EE', name: 'Estonia', dialCode: '372'),
  Country(isoCode: 'SZ', name: 'Eswatini', dialCode: '268'),
  Country(isoCode: 'ET', name: 'Ethiopia', dialCode: '251'),
  Country(isoCode: 'FK', name: 'Falkland Islands', dialCode: '500'),
  Country(isoCode: 'FO', name: 'Faroe Islands', dialCode: '298'),
  Country(isoCode: 'FJ', name: 'Fiji', dialCode: '679'),
  Country(isoCode: 'FI', name: 'Finland', dialCode: '358'),
  Country(isoCode: 'FR', name: 'France', dialCode: '33'),
  Country(isoCode: 'GF', name: 'French Guiana', dialCode: '594'),
  Country(isoCode: 'PF', name: 'French Polynesia', dialCode: '689'),
  Country(isoCode: 'GA', name: 'Gabon', dialCode: '241'),
  Country(isoCode: 'GM', name: 'Gambia', dialCode: '220'),
  Country(isoCode: 'GE', name: 'Georgia', dialCode: '995'),
  Country(isoCode: 'DE', name: 'Germany', dialCode: '49'),
  Country(isoCode: 'GH', name: 'Ghana', dialCode: '233'),
  Country(isoCode: 'GI', name: 'Gibraltar', dialCode: '350'),
  Country(isoCode: 'GR', name: 'Greece', dialCode: '30'),
  Country(isoCode: 'GL', name: 'Greenland', dialCode: '299'),
  Country(isoCode: 'GD', name: 'Grenada', dialCode: '1'),
  Country(isoCode: 'GP', name: 'Guadeloupe', dialCode: '590'),
  Country(isoCode: 'GU', name: 'Guam', dialCode: '1'),
  Country(isoCode: 'GT', name: 'Guatemala', dialCode: '502'),
  Country(isoCode: 'GG', name: 'Guernsey', dialCode: '44'),
  Country(isoCode: 'GN', name: 'Guinea', dialCode: '224'),
  Country(isoCode: 'GW', name: 'Guinea-Bissau', dialCode: '245'),
  Country(isoCode: 'GY', name: 'Guyana', dialCode: '592'),
  Country(isoCode: 'HT', name: 'Haiti', dialCode: '509'),
  Country(isoCode: 'HN', name: 'Honduras', dialCode: '504'),
  Country(isoCode: 'HK', name: 'Hong Kong', dialCode: '852'),
  Country(isoCode: 'HU', name: 'Hungary', dialCode: '36'),
  Country(isoCode: 'IS', name: 'Iceland', dialCode: '354'),
  Country(isoCode: 'IN', name: 'India', dialCode: '91'),
  Country(isoCode: 'ID', name: 'Indonesia', dialCode: '62'),
  Country(isoCode: 'IR', name: 'Iran', dialCode: '98'),
  Country(isoCode: 'IQ', name: 'Iraq', dialCode: '964'),
  Country(isoCode: 'IE', name: 'Ireland', dialCode: '353'),
  Country(isoCode: 'IM', name: 'Isle of Man', dialCode: '44'),
  Country(isoCode: 'IL', name: 'Israel', dialCode: '972'),
  Country(isoCode: 'IT', name: 'Italy', dialCode: '39'),
  Country(isoCode: 'JM', name: 'Jamaica', dialCode: '1'),
  Country(isoCode: 'JP', name: 'Japan', dialCode: '81'),
  Country(isoCode: 'JE', name: 'Jersey', dialCode: '44'),
  Country(isoCode: 'JO', name: 'Jordan', dialCode: '962'),
  Country(isoCode: 'KZ', name: 'Kazakhstan', dialCode: '7'),
  Country(isoCode: 'KE', name: 'Kenya', dialCode: '254'),
  Country(isoCode: 'KI', name: 'Kiribati', dialCode: '686'),
  Country(isoCode: 'KP', name: 'Korea (North)', dialCode: '850'),
  Country(isoCode: 'KR', name: 'Korea (South)', dialCode: '82'),
  Country(isoCode: 'XK', name: 'Kosovo', dialCode: '383'),
  Country(isoCode: 'KW', name: 'Kuwait', dialCode: '965'),
  Country(isoCode: 'KG', name: 'Kyrgyzstan', dialCode: '996'),
  Country(isoCode: 'LA', name: 'Laos', dialCode: '856'),
  Country(isoCode: 'LV', name: 'Latvia', dialCode: '371'),
  Country(isoCode: 'LB', name: 'Lebanon', dialCode: '961'),
  Country(isoCode: 'LS', name: 'Lesotho', dialCode: '266'),
  Country(isoCode: 'LR', name: 'Liberia', dialCode: '231'),
  Country(isoCode: 'LY', name: 'Libya', dialCode: '218'),
  Country(isoCode: 'LI', name: 'Liechtenstein', dialCode: '423'),
  Country(isoCode: 'LT', name: 'Lithuania', dialCode: '370'),
  Country(isoCode: 'LU', name: 'Luxembourg', dialCode: '352'),
  Country(isoCode: 'MO', name: 'Macao', dialCode: '853'),
  Country(isoCode: 'MG', name: 'Madagascar', dialCode: '261'),
  Country(isoCode: 'MW', name: 'Malawi', dialCode: '265'),
  Country(isoCode: 'MY', name: 'Malaysia', dialCode: '60'),
  Country(isoCode: 'MV', name: 'Maldives', dialCode: '960'),
  Country(isoCode: 'ML', name: 'Mali', dialCode: '223'),
  Country(isoCode: 'MT', name: 'Malta', dialCode: '356'),
  Country(isoCode: 'MH', name: 'Marshall Islands', dialCode: '692'),
  Country(isoCode: 'MQ', name: 'Martinique', dialCode: '596'),
  Country(isoCode: 'MR', name: 'Mauritania', dialCode: '222'),
  Country(isoCode: 'MU', name: 'Mauritius', dialCode: '230'),
  Country(isoCode: 'YT', name: 'Mayotte', dialCode: '262'),
  Country(isoCode: 'MX', name: 'Mexico', dialCode: '52'),
  Country(isoCode: 'FM', name: 'Micronesia', dialCode: '691'),
  Country(isoCode: 'MD', name: 'Moldova', dialCode: '373'),
  Country(isoCode: 'MC', name: 'Monaco', dialCode: '377'),
  Country(isoCode: 'MN', name: 'Mongolia', dialCode: '976'),
  Country(isoCode: 'ME', name: 'Montenegro', dialCode: '382'),
  Country(isoCode: 'MS', name: 'Montserrat', dialCode: '1'),
  Country(isoCode: 'MA', name: 'Morocco', dialCode: '212'),
  Country(isoCode: 'MZ', name: 'Mozambique', dialCode: '258'),
  Country(isoCode: 'MM', name: 'Myanmar', dialCode: '95'),
  Country(isoCode: 'NA', name: 'Namibia', dialCode: '264'),
  Country(isoCode: 'NR', name: 'Nauru', dialCode: '674'),
  Country(isoCode: 'NP', name: 'Nepal', dialCode: '977'),
  Country(isoCode: 'NL', name: 'Netherlands', dialCode: '31'),
  Country(isoCode: 'NC', name: 'New Caledonia', dialCode: '687'),
  Country(isoCode: 'NZ', name: 'New Zealand', dialCode: '64'),
  Country(isoCode: 'NI', name: 'Nicaragua', dialCode: '505'),
  Country(isoCode: 'NE', name: 'Niger', dialCode: '227'),
  Country(isoCode: 'NG', name: 'Nigeria', dialCode: '234'),
  Country(isoCode: 'NU', name: 'Niue', dialCode: '683'),
  Country(isoCode: 'NF', name: 'Norfolk Island', dialCode: '672'),
  Country(isoCode: 'MK', name: 'North Macedonia', dialCode: '389'),
  Country(isoCode: 'MP', name: 'Northern Mariana Islands', dialCode: '1'),
  Country(isoCode: 'NO', name: 'Norway', dialCode: '47'),
  Country(isoCode: 'OM', name: 'Oman', dialCode: '968'),
  Country(isoCode: 'PK', name: 'Pakistan', dialCode: '92'),
  Country(isoCode: 'PW', name: 'Palau', dialCode: '680'),
  Country(isoCode: 'PS', name: 'Palestine', dialCode: '970'),
  Country(isoCode: 'PA', name: 'Panama', dialCode: '507'),
  Country(isoCode: 'PG', name: 'Papua New Guinea', dialCode: '675'),
  Country(isoCode: 'PY', name: 'Paraguay', dialCode: '595'),
  Country(isoCode: 'PE', name: 'Peru', dialCode: '51'),
  Country(isoCode: 'PH', name: 'Philippines', dialCode: '63'),
  Country(isoCode: 'PL', name: 'Poland', dialCode: '48'),
  Country(isoCode: 'PT', name: 'Portugal', dialCode: '351'),
  Country(isoCode: 'PR', name: 'Puerto Rico', dialCode: '1'),
  Country(isoCode: 'QA', name: 'Qatar', dialCode: '974'),
  Country(isoCode: 'RE', name: 'Réunion', dialCode: '262'),
  Country(isoCode: 'RO', name: 'Romania', dialCode: '40'),
  Country(isoCode: 'RU', name: 'Russia', dialCode: '7'),
  Country(isoCode: 'RW', name: 'Rwanda', dialCode: '250'),
  Country(isoCode: 'BL', name: 'Saint Barthélemy', dialCode: '590'),
  Country(isoCode: 'SH', name: 'Saint Helena', dialCode: '290'),
  Country(isoCode: 'KN', name: 'Saint Kitts and Nevis', dialCode: '1'),
  Country(isoCode: 'LC', name: 'Saint Lucia', dialCode: '1'),
  Country(isoCode: 'MF', name: 'Saint Martin', dialCode: '590'),
  Country(isoCode: 'PM', name: 'Saint Pierre and Miquelon', dialCode: '508'),
  Country(isoCode: 'VC', name: 'Saint Vincent and the Grenadines', dialCode: '1'),
  Country(isoCode: 'WS', name: 'Samoa', dialCode: '685'),
  Country(isoCode: 'SM', name: 'San Marino', dialCode: '378'),
  Country(isoCode: 'ST', name: 'Sao Tome and Principe', dialCode: '239'),
  Country(isoCode: 'SA', name: 'Saudi Arabia', dialCode: '966'),
  Country(isoCode: 'SN', name: 'Senegal', dialCode: '221'),
  Country(isoCode: 'RS', name: 'Serbia', dialCode: '381'),
  Country(isoCode: 'SC', name: 'Seychelles', dialCode: '248'),
  Country(isoCode: 'SL', name: 'Sierra Leone', dialCode: '232'),
  Country(isoCode: 'SG', name: 'Singapore', dialCode: '65'),
  Country(isoCode: 'SX', name: 'Sint Maarten', dialCode: '1'),
  Country(isoCode: 'SK', name: 'Slovakia', dialCode: '421'),
  Country(isoCode: 'SI', name: 'Slovenia', dialCode: '386'),
  Country(isoCode: 'SB', name: 'Solomon Islands', dialCode: '677'),
  Country(isoCode: 'SO', name: 'Somalia', dialCode: '252'),
  Country(isoCode: 'ZA', name: 'South Africa', dialCode: '27'),
  Country(isoCode: 'SS', name: 'South Sudan', dialCode: '211'),
  Country(isoCode: 'ES', name: 'Spain', dialCode: '34'),
  Country(isoCode: 'LK', name: 'Sri Lanka', dialCode: '94'),
  Country(isoCode: 'SD', name: 'Sudan', dialCode: '249'),
  Country(isoCode: 'SR', name: 'Suriname', dialCode: '597'),
  Country(isoCode: 'SJ', name: 'Svalbard and Jan Mayen', dialCode: '47'),
  Country(isoCode: 'SE', name: 'Sweden', dialCode: '46'),
  Country(isoCode: 'CH', name: 'Switzerland', dialCode: '41'),
  Country(isoCode: 'SY', name: 'Syria', dialCode: '963'),
  Country(isoCode: 'TW', name: 'Taiwan', dialCode: '886'),
  Country(isoCode: 'TJ', name: 'Tajikistan', dialCode: '992'),
  Country(isoCode: 'TZ', name: 'Tanzania', dialCode: '255'),
  Country(isoCode: 'TH', name: 'Thailand', dialCode: '66'),
  Country(isoCode: 'TL', name: 'Timor-Leste', dialCode: '670'),
  Country(isoCode: 'TG', name: 'Togo', dialCode: '228'),
  Country(isoCode: 'TK', name: 'Tokelau', dialCode: '690'),
  Country(isoCode: 'TO', name: 'Tonga', dialCode: '676'),
  Country(isoCode: 'TT', name: 'Trinidad and Tobago', dialCode: '1'),
  Country(isoCode: 'TA', name: 'Tristan da Cunha', dialCode: '290'),
  Country(isoCode: 'TN', name: 'Tunisia', dialCode: '216'),
  Country(isoCode: 'TR', name: 'Türkiye', dialCode: '90'),
  Country(isoCode: 'TM', name: 'Turkmenistan', dialCode: '993'),
  Country(isoCode: 'TC', name: 'Turks and Caicos Islands', dialCode: '1'),
  Country(isoCode: 'TV', name: 'Tuvalu', dialCode: '688'),
  Country(isoCode: 'UG', name: 'Uganda', dialCode: '256'),
  Country(isoCode: 'UA', name: 'Ukraine', dialCode: '380'),
  Country(isoCode: 'AE', name: 'United Arab Emirates', dialCode: '971'),
  Country(isoCode: 'GB', name: 'United Kingdom', dialCode: '44'),
  Country(isoCode: 'US', name: 'United States', dialCode: '1'),
  Country(isoCode: 'UY', name: 'Uruguay', dialCode: '598'),
  Country(isoCode: 'UZ', name: 'Uzbekistan', dialCode: '998'),
  Country(isoCode: 'VU', name: 'Vanuatu', dialCode: '678'),
  Country(isoCode: 'VA', name: 'Vatican City', dialCode: '39'),
  Country(isoCode: 'VE', name: 'Venezuela', dialCode: '58'),
  Country(isoCode: 'VN', name: 'Viet Nam', dialCode: '84'),
  Country(isoCode: 'VG', name: 'Virgin Islands (British)', dialCode: '1'),
  Country(isoCode: 'VI', name: 'Virgin Islands (U.S.)', dialCode: '1'),
  Country(isoCode: 'WF', name: 'Wallis and Futuna', dialCode: '681'),
  Country(isoCode: 'EH', name: 'Western Sahara', dialCode: '212'),
  Country(isoCode: 'YE', name: 'Yemen', dialCode: '967'),
  Country(isoCode: 'ZM', name: 'Zambia', dialCode: '260'),
  Country(isoCode: 'ZW', name: 'Zimbabwe', dialCode: '263'),
];

/// Looks up a country by ISO code, falling back to Malaysia.
///
/// Never returns null: an unknown or missing code — an older profile, a typo —
/// should show the default dial code, not crash a form that is mid-edit.
Country countryByIso(String? isoCode) {
  final wanted = (isoCode ?? '').toUpperCase();
  Country? fallback;
  for (final country in kCountries) {
    if (country.isoCode == wanted) return country;
    if (country.isoCode == kDefaultCountryIso) fallback = country;
  }
  return fallback ?? kCountries.first;
}

/// Countries whose name or dial code matches [query], for the picker's search
/// box. An empty query returns everything.
List<Country> searchCountries(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return kCountries;
  final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
  return <Country>[
    for (final country in kCountries)
      if (country.name.toLowerCase().contains(q) ||
          country.isoCode.toLowerCase() == q ||
          (digits.isNotEmpty && country.dialCode.startsWith(digits)))
        country,
  ];
}
