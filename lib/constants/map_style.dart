/// Google Maps style JSON for the Map & GPS module.
///
/// Fed straight into `GoogleMap.style`. Two palettes: [warm] for the browse
/// and route-summary screens, so the map sits inside the app's cream design
/// tokens instead of Google's stock grey/blue, and [night] for UC-M05's
/// in-app navigation, where a dark map keeps the instruction banner and the
/// route line as the brightest things on screen.
///
/// Both styles also strip Google's own POI pins and labels — UC-007 renders
/// its own food/attraction pins, and two competing sets of pins on one map
/// is the single biggest source of visual clutter.
class MapStyles {
  const MapStyles._();

  /// Cream/terracotta daylight palette matching `AppColors.background`.
  static const String warm = '''
[
  {"elementType":"geometry","stylers":[{"color":"#fdf1e6"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#6f5c4d"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#fff8f1"},{"weight":3}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.neighborhood","stylers":[{"visibility":"off"}]},
  {"featureType":"landscape.man_made","elementType":"geometry","stylers":[{"color":"#f7e9db"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#f6eadc"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#dfe9d6"},{"visibility":"on"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#7d8f6d"},{"visibility":"on"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#efdfd0"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9a8676"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#fdf7f1"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#f4dcc3"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#e4b592"}]},
  {"featureType":"road.local","elementType":"labels","stylers":[{"visibility":"simplified"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#eee0d2"},{"visibility":"on"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#bcd8de"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#7fa3ab"}]}
]
''';

  /// Dark palette for the turn-by-turn screen (UC-M05).
  static const String night = '''
[
  {"elementType":"geometry","stylers":[{"color":"#14171a"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#9aa0a6"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#14171a"},{"weight":3}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.neighborhood","stylers":[{"visibility":"off"}]},
  {"featureType":"landscape.man_made","elementType":"geometry","stylers":[{"color":"#1b1f24"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1b2a1f"},{"visibility":"on"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2b3036"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1b1f23"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a9199"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3a4149"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#22262b"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0b1116"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4d6570"}]}
]
''';
}
