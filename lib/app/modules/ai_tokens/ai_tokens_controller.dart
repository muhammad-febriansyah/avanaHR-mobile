import 'dart:async';

import 'package:dio/dio.dart';

import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/app_toast.dart';
import '../../data/models/ai_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';
import '../../data/services/auth_service.dart';

/// Buying AI tokens for yourself.
///
/// Payment happens in a browser rather than in the app: the gateway serves its
/// own page, and embedding it would mean shipping a new build every time that
/// page changes. So after handing the buyer over, this polls the order — the
/// app never sees the browser come back, and waiting for the webhook alone
/// would leave a paid-for balance stale on screen.
class AiTokensController extends GetxController {
  final AvanaApi _api = AvanaApi();
  final AuthService _auth = Get.find();

  final isLoading = true.obs;
  final buyingPackId = RxnInt();
  final balance = Rxn<AiTokenBalance>();
  final packs = <AiTokenPack>[].obs;
  final orders = <AiTokenOrder>[].obs;

  /// The order left waiting at the payment page, polled until it settles.
  final pendingOrder = RxnString();

  Timer? _poll;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _poll?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;

    try {
      final data = await _api.aiTokens();

      balance.value = AiTokenBalance.fromJson(
        Map<String, dynamic>.from(data['summary'] ?? {}),
      );
      packs.value = ((data['packs'] as List?) ?? [])
          .map((e) => AiTokenPack.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      orders.value = ((data['orders'] as List?) ?? [])
          .map((e) => AiTokenOrder.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
    } finally {
      isLoading.value = false;
    }
  }

  /// Open an order and send the buyer to the payment page.
  Future<void> buy(AiTokenPack pack) async {
    if (buyingPackId.value != null) {
      return;
    }

    buyingPackId.value = pack.id;

    try {
      final order = await _api.aiBuyTokens(pack.id);
      final url = Uri.tryParse(order['pay_url']?.toString() ?? '');

      if (url == null) {
        AppToast.error('Halaman pembayaran tidak tersedia. Coba lagi.');

        return;
      }

      // The order exists whether or not the browser opens, so it is tracked
      // before launching: a buyer who pays and never returns is still settled
      // the next time this screen polls.
      pendingOrder.value = order['order_number']?.toString();
      await load();
      _startPolling();

      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        AppToast.error('Tidak bisa membuka halaman pembayaran.');
      }
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
    } finally {
      buyingPackId.value = null;
    }
  }

  /// Check the waiting order now — what the buyer taps after paying.
  Future<void> checkPending() async {
    final orderNumber = pendingOrder.value;

    if (orderNumber == null) {
      return;
    }

    try {
      final result = await _api.aiTokenOrder(orderNumber);

      if (result['credited'] == true) {
        _poll?.cancel();
        pendingOrder.value = null;
        AppToast.success('Pembayaran berhasil. Token sudah masuk.');
        // The AI screen reads the balance off the signed-in user, so it has to
        // be refreshed too rather than only this screen's copy.
        await _auth.loadMe();
        await load();

        return;
      }

      balance.value = AiTokenBalance.fromJson(
        Map<String, dynamic>.from(result['summary'] ?? {}),
      );
    } catch (_) {
      // A failed check is not worth a toast: polling tries again shortly, and
      // the buyer may simply still be on the payment page.
    }
  }

  /// Poll while an order is outstanding, giving up after five minutes so a
  /// buyer who abandoned payment is not checked on forever.
  void _startPolling() {
    _poll?.cancel();

    var elapsed = 0;

    _poll = Timer.periodic(const Duration(seconds: 6), (timer) {
      elapsed += 6;

      if (pendingOrder.value == null || elapsed > 300) {
        timer.cancel();

        return;
      }

      checkPending();
    });
  }
}
