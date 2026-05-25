import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectivityService Robustness Test', () {
    test(
      'Should return ConnectivityStatus.online when plugin is missing',
      () async {
        final service = ConnectivityService();

        // Allow for microtasks to run (initialization)
        await Future.delayed(const Duration(milliseconds: 50));

        // Check currentStatus directly
        expect(service.currentStatus, ConnectivityStatus.online);
      },
    );
  });
}
