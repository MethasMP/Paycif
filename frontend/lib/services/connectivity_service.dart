import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

enum ConnectivityStatus { online, offline }

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();
  StreamSubscription? _subscription;

  ConnectivityStatus _currentStatus = ConnectivityStatus.online;
  ConnectivityStatus get currentStatus => _currentStatus;

  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  // Elite UX: Stabilization flag to prevent blips on startup
  bool _isStabilizing = true;
  Timer? _debounceTimer;

  ConnectivityService() {
    _init();
    // Allow 2 seconds for system services to settle before reporting offline
    Future.delayed(const Duration(seconds: 2), () {
      _isStabilizing = false;
    });
  }

  void _init() {
    try {
      _subscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          _emitStatus(results);
        },
        onError: (e) {
          debugPrint('⚠️ Connectivity stream error: $e');
          // Fallback to online on error
          _currentStatus = ConnectivityStatus.online;
          _statusController.add(ConnectivityStatus.online);
        },
      );
      // Check initial status
      checkStatus();
    } on MissingPluginException catch (e) {
      debugPrint('❌ Connectivity plugin missing: $e. Defaulting to online.');
      _currentStatus = ConnectivityStatus.online;
      _statusController.add(ConnectivityStatus.online);
    } catch (e) {
      debugPrint('⚠️ Unexpected error in ConnectivityService init: $e');
      _currentStatus = ConnectivityStatus.online;
      _statusController.add(ConnectivityStatus.online);
    }
  }

  Future<void> checkStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _emitStatus(results);
    } on MissingPluginException catch (e) {
      debugPrint('❌ connectivity_plus plugin implementation not found: $e');
      _currentStatus = ConnectivityStatus.online;
      _statusController.add(ConnectivityStatus.online);
    } on PlatformException catch (e) {
      debugPrint('⚠️ Platform error checking connectivity: $e');
      _currentStatus = ConnectivityStatus.online;
      _statusController.add(ConnectivityStatus.online);
    } catch (e) {
      debugPrint('⚠️ Error checking connectivity status: $e');
      _currentStatus = ConnectivityStatus.online;
      _statusController.add(ConnectivityStatus.online);
    }
  }

  void _emitStatus(List<ConnectivityResult> results) {
    try {
      final hasConnection = results.any(
        (result) => result != ConnectivityResult.none,
      );
      final newStatus = hasConnection
          ? ConnectivityStatus.online
          : ConnectivityStatus.offline;

      // Elite UX: Debounce and Stabilization logic
      _debounceTimer?.cancel();

      if (_isStabilizing && newStatus == ConnectivityStatus.offline) {
        debugPrint('🛡️ Connectivity: Suppressing startup offline blip');
        return;
      }

      if (newStatus == _currentStatus) return;

      // Debounce offline changes to filter out flickers
      if (newStatus == ConnectivityStatus.offline) {
        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
          _currentStatus = ConnectivityStatus.offline;
          _statusController.add(_currentStatus);
        });
      } else {
        // Online status is reported immediately for responsiveness
        _currentStatus = ConnectivityStatus.online;
        _statusController.add(_currentStatus);
      }
    } catch (e) {
      debugPrint('⚠️ Error emitting connectivity status: $e');
      _currentStatus = ConnectivityStatus.online;
      _statusController.add(ConnectivityStatus.online);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
