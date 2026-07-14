import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Connection quality as the app sees it.
enum ConnStatus {
  /// Interface up and the internet is actually reachable.
  online,

  /// Interface reports connected, but the internet can't be reached
  /// (dead wifi / captive portal / very weak signal).
  unstable,

  /// No network interface at all.
  offline,
}

/// Tracks device connectivity AND real internet reachability so the UI can
/// warn on no/bad internet. `connectivity_plus` alone only knows whether an
/// interface exists — not whether traffic actually flows — so a lightweight
/// reachability probe distinguishes "connected" from "connected but dead".
class ConnectivityService extends GetxService {
  final Connectivity _connectivity = Connectivity();

  /// Whether the internet is actually reachable (interface up + probe ok).
  final RxBool online = true.obs;

  /// Fine-grained state for the connection popup/banner.
  final Rx<ConnStatus> status = ConnStatus.online.obs;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _heartbeat;

  @override
  void onInit() {
    super.onInit();
    _refresh();
    _sub = _connectivity.onConnectivityChanged.listen(_apply);
    // Silent-death heartbeat: catches an interface that stays "connected" while
    // the internet drops (no connectivity event fires in that case).
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      await _apply(await _connectivity.checkConnectivity());
    } catch (_) {
      _set(
        ConnStatus.online,
      ); // fail open — never trap the app on a probe error
    }
  }

  Future<void> _apply(List<ConnectivityResult> results) async {
    final hasInterface = results.any((r) => r != ConnectivityResult.none);
    if (!hasInterface) {
      _set(ConnStatus.offline);
      return;
    }
    _set(await _reachable() ? ConnStatus.online : ConnStatus.unstable);
  }

  /// A cheap DNS probe: resolves a stable host to confirm the internet is
  /// actually reachable. Fails fast (times out) on dead/blocked networks.
  Future<bool> _reachable() async {
    try {
      final res = await InternetAddress.lookup(
        'one.one.one.one',
      ).timeout(const Duration(seconds: 4));
      return res.isNotEmpty && res.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _set(ConnStatus s) {
    status.value = s;
    online.value = s == ConnStatus.online;
  }

  /// Manual re-check, e.g. from the popup's "Coba Lagi" button.
  Future<void> recheck() => _refresh();

  @override
  void onClose() {
    _sub?.cancel();
    _heartbeat?.cancel();
    super.onClose();
  }
}
