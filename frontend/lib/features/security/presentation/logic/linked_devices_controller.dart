import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/security_repository.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';

class LinkedDevicesController extends ChangeNotifier {
  final SecurityRepository _repository;

  LinkedDevicesController(this._repository) {
    _loadDevices();
  }

  StreamSubscription? _devicesSub;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> get devices => _devices;

  String? _currentDeviceId;
  String? get currentDeviceId => _currentDeviceId;

  Future<void> _loadDevices() async {
    _currentDeviceId = await _repository.getCurrentDeviceId();

    // ⚡ [Fast-Path] Try getting Cache first (Loads instantly from Memory/Disk)
    final cachedDevices = await _repository.getLinkedDevices();
    if (cachedDevices.isNotEmpty) {
      _devices = cachedDevices;
      _isLoading = false; // 🚫 Spinner is not needed because we have data
      notifyListeners();
    } else {
      _isLoading = true;
      notifyListeners();
    }

    // 🛰️ [Real-time Path] Subscribe for instant updates
    _devicesSub?.cancel();
    _devicesSub = _repository.watchLinkedDevices().listen(
      (freshDevices) {
        _devices = freshDevices;
        _isLoading = false;
        notifyListeners();
        debugPrint('📡 [LinkedDevices] Real-time Sync received.');
      },
      onError: (e) {
        debugPrint('⚠️ [LinkedDevices] Real-time Sync Error: $e');
        // Fallback: One-time network refresh if Real-time fails
        _repository.getLinkedDevices(forceRefresh: true).then((fresh) {
          _devices = fresh;
          _isLoading = false;
          notifyListeners();
        });
      },
    );
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    super.dispose();
  }

  Future<bool> revokeDevice(String deviceId, AppLocalizations l10n) async {
    try {
      await _repository.revokeDevice(
        deviceId,
        reason: "User manually revoked via settings",
      );

      // Update local list for immediate feedback
      _devices.removeWhere((d) => d['device_id'] == deviceId);
      notifyListeners();

      // Check for Self-Revocation
      if (deviceId == _currentDeviceId) {
        // Trigger Logout / Session expiry
        return true; // Return true to signal "Logout Needed"
      }

      return false; // Just revoked, no logout needed
    } catch (e) {
      // Error handling is usually done by UI listening to this or re-throwing
      rethrow;
    }
  }

  String formatLastActive(String isoDate) {
    if (isoDate.isEmpty) return 'Unknown';
    final date = DateTime.parse(isoDate).toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Active now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
