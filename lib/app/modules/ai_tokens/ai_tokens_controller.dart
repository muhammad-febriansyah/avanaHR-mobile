import 'dart:async';

import 'package:dio/dio.dart';

import 'package:get/get.dart';

import '../../core/widgets/app_toast.dart';
import '../../data/models/ai_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';
import '../../data/services/auth_service.dart';
import 'token_payment_view.dart';

/// Buying AI tokens for yourself.
///
/// The gateway serves its own checkout page, shown inside the app by
/// [TokenPaymentView] so the buyer never loses sight of AvanaHR. Polling stays
/// even so: a buyer can close that page while a payment is still in flight, and
/// waiting for the webhook alone would leave a paid-for balance stale on screen.
class AiTokensController extends GetxController {
  final AvanaApi _api = AvanaApi();
  final AuthService _auth = Get.find();

  final isLoading = true.obs;
  final buyingPackId = RxnInt();
  final balance = Rxn<AiTokenBalance>();
  final spend = Rxn<AiTokenSpend>();
  final packs = <AiTokenPack>[].obs;
  final orders = <AiTokenOrder>[].obs;

  /// Which bucket size the spending chart is showing.
  final chartIsMonthly = false.obs;

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
      spend.value = AiTokenSpend.fromJson(
        Map<String, dynamic>.from(data['usage'] ?? {}),
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

  /// Open an order and show the payment page inside the app.
  Future<void> buy(AiTokenPack pack) async {
    if (buyingPackId.value != null) {
      return;
    }

    buyingPackId.value = pack.id;

    try {
      final order = await _api.aiBuyTokens(pack.id);
      final payUrl = order['pay_url']?.toString() ?? '';
      final orderNumber = order['order_number']?.toString();

      if (payUrl.isEmpty || orderNumber == null) {
        AppToast.error('Halaman pembayaran tidak tersedia. Coba lagi.');

        return;
      }

      // The order exists whether or not the payment page opens, so it is
      // tracked first: a buyer who pays and then closes the page is still
      // settled the next time this screen polls.
      pendingOrder.value = orderNumber;
      await load();
      _startPolling();

      final credited = await Get.to<bool>(
        () => TokenPaymentView(payUrl: payUrl, orderNumber: orderNumber),
      );

      if (credited == true) {
        await settle();

        return;
      }

      // Closed without a confirmed payment — ask once now rather than leaving
      // the buyer to wait out the next poll.
      await checkPending();
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
        await settle();

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

  /// Stop waiting on the order and show the tokens that arrived.
  Future<void> settle() async {
    _poll?.cancel();
    pendingOrder.value = null;
    AppToast.success('Pembayaran berhasil. Token sudah masuk.');
    // The AI screen reads the balance off the signed-in user, so it has to be
    // refreshed too rather than only this screen's copy.
    await _auth.loadMe();
    await load();
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
