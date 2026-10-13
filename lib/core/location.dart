import 'package:geolocator/geolocator.dart';

enum LocationProblem { serviceOff, denied }

/// Current GPS fix, asking for permission when needed.
Future<({Position? position, LocationProblem? problem})> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    return (position: null, problem: LocationProblem.serviceOff);
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    return (position: null, problem: LocationProblem.denied);
  }
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    ),
  );
  return (position: position, problem: null);
}
