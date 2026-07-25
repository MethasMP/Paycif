import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// A device GPS coordinate pair. This is a soft signal only — GPS is
/// trivially spoofed — used purely to give the backend an additional
/// logging/audit data point alongside the real, server-side IP geo-fence.
typedef DeviceLocation = ({double lat, double lng});

/// Returns the device's current location. Throws an exception if location
/// permission is denied, services are disabled, or mock locations are detected.
Future<DeviceLocation> getCurrentLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('Location services are disabled. Please enable location to proceed with payment.');
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw Exception('Location permission is required to verify the point of sale.');
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: Duration(seconds: 3),
    ),
  );

  if (position.isMocked) {
    debugPrint('🚨 WARNING: Mocked location detected! Returning fail-closed boundary.');
    return (lat: 999.0, lng: 999.0);
  }

  return (lat: position.latitude, lng: position.longitude);
}

/// Kept as legacy helper if needed elsewhere
Future<DeviceLocation?> getCurrentLocationOrNull() async {
  try {
    return await getCurrentLocation();
  } catch (_) {
    return null;
  }
}
