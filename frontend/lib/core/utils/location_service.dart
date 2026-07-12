import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// A device GPS coordinate pair. This is a soft signal only — GPS is
/// trivially spoofed — used purely to give the backend an additional
/// logging/audit data point alongside the real, server-side IP geo-fence.
typedef DeviceLocation = ({double lat, double lng});

/// Returns the device's current location, or `null` if permission is
/// denied, location services are off, or the lookup fails/times out.
/// Never throws — callers should treat `null` as "no signal available"
/// and proceed with the request regardless.
Future<DeviceLocation?> getCurrentLocationOrNull() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 3),
      ),
    );
    return (lat: position.latitude, lng: position.longitude);
  } catch (e) {
    debugPrint('getCurrentLocationOrNull: soft-failed, proceeding without location: $e');
    return null;
  }
}
