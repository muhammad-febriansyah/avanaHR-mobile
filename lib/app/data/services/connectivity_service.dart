import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Tracks device connectivity so the UI can react to no/bad internet.
/// Exposes a reactive [online] flag updated on every connectivity change.
class ConnectivityService extends GetxService {
  final Connectivity _connectivity = Connectivity();

  /// Whether the device currently has any network connection.
  final RxBool online = true.obs;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _refresh();
    _sub = _connectivity.onConnectivityChanged.listen(_apply);
  }

  Future<void> _refresh() async {
    try {
      _apply(await _connectivity.checkConnectivity());
    } catch (_) {
      online.value = true; // fail open — don't block the app if the check fails
    }
  }

  void _apply(List<ConnectivityResult> results) {
    online.value = results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
