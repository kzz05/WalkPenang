/// Transit-leg details for a [RouteStep] whose `travelMode` is `TRANSIT`
/// (UC-M05 transit navigation), parsed from the Directions API's
/// `transit_details` object.
class TransitDetails {
  final String lineName;
  final String vehicleType; // BUS, SUBWAY, TRAM, RAIL, FERRY, ...
  final String headsign;
  final String departureStopName;
  final String arrivalStopName;
  final int numStops;
  final String departureTimeText;
  final String arrivalTimeText;

  TransitDetails({
    required this.lineName,
    required this.vehicleType,
    required this.headsign,
    required this.departureStopName,
    required this.arrivalStopName,
    required this.numStops,
    required this.departureTimeText,
    required this.arrivalTimeText,
  });
}
