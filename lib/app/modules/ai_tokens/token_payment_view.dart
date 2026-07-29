import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../data/providers/avana_api.dart';

/// Where the gateway sends a buyer back to once payment is handed over. Read
/// off the API origin so a LAN or localhost build recognises its own return.
String get _returnUrl => '${Env.apiOrigin}/bayar/token-ai/selesai';

/// The payment page, kept inside the app.
///
/// The gateway serves its own checkout, so it is shown in a WebView rather than
/// handed to the phone's browser: a buyer who leaves the app loses sight of it
/// and has no way back except the task switcher. As soon as the gateway bounces
/// to the AvanaHR return page, that page is never rendered — the order is asked
/// about directly instead, and the result is stated here in the app's own words.
///
/// Pops `true` once the tokens have landed.
class TokenPaymentView extends StatefulWidget {
  const TokenPaymentView({
    super.key,
    required this.payUrl,
    required this.orderNumber,
  });

  final String payUrl;
  final String orderNumber;

  @override
  State<TokenPaymentView> createState() => _TokenPaymentViewState();
}

/// What the buyer is looking at: the checkout itself, or its outcome.
enum _Phase { paying, checking, credited, unfinished, unreachable }

class _TokenPaymentViewState extends State<TokenPaymentView> {
  final AvanaApi _api = AvanaApi();

  late final WebViewController _web;

  final _phase = _Phase.paying.obs;
  final _pageLoading = true.obs;

  @override
  void initState() {
    super.initState();

    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _pageLoading.value = true,
          onPageFinished: (_) => _pageLoading.value = false,
          onNavigationRequest: _onNavigation,
        ),
      )
      ..loadRequest(Uri.parse(widget.payUrl));
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final url = request.url;

    // Payment handed over: drop the WebView and ask our own server instead.
    if (url.startsWith(_returnUrl)) {
      _confirmPayment();

      return NavigationDecision.prevent;
    }

    // QRIS and e-wallets hand off with their own schemes (gojek://, intent://,
    // shopeeid://), which no WebView can load — those do belong outside.
    if (!url.startsWith('http')) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  /// Ask the server whether the order settled, a few times over.
  ///
  /// The gateway's webhook can arrive seconds after the buyer is bounced back,
  /// so a single unpaid answer is too early to call it a failed payment. The
  /// order endpoint verifies with the gateway on the way past, so this settles
  /// the payment itself when the webhook has not landed at all.
  Future<void> _confirmPayment({int attempts = 5}) async {
    _phase.value = _Phase.checking;

    for (var attempt = 0; attempt < attempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      if (!mounted) {
        return;
      }

      try {
        final result = await _api.aiTokenOrder(widget.orderNumber);

        if (result['credited'] == true) {
          _phase.value = _Phase.credited;

          return;
        }
      } catch (_) {
        // Losing the network says nothing about the payment, so the buyer is
        // offered another try rather than told it failed.
        _phase.value = _Phase.unreachable;

        return;
      }
    }

    _phase.value = _Phase.unfinished;
  }

  /// Leaving mid-payment is easy to do by accident, and the gateway page holds
  /// a QR the buyer may still be scanning.
  Future<void> _leave() async {
    if (_phase.value != _Phase.paying) {
      Get.back(result: _phase.value == _Phase.credited);

      return;
    }

    final leave = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Tutup halaman pembayaran?',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Kalau Anda sudah terlanjur membayar, tidak perlu bayar lagi — token '
          'masuk otomatis setelah pembayaran dikonfirmasi.',
          style: TextStyle(
            fontSize: 12.5.sp,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'Lanjut bayar',
              style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              'Tutup',
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );

    if (leave == true) {
      Get.back(result: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _leave();
        }
      },
      child: Obx(
        () => AppPage(
          title: 'Pembayaran',
          subtitle: widget.orderNumber,
          showBack: false,
          actions: [
            if (_phase.value == _Phase.paying)
              HeaderAction(Iconsax.refresh, _web.reload),
            HeaderAction(Iconsax.close_circle, _leave),
          ],
          child: _phase.value == _Phase.paying ? _checkout() : _result(),
        ),
      ),
    );
  }

  Widget _checkout() {
    return Stack(
      children: [
        WebViewWidget(controller: _web),
        Obx(
          () => _pageLoading.value
              ? LinearProgressIndicator(
                  minHeight: 3.h,
                  color: AppColors.primary,
                  backgroundColor: AppColors.muted,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _result() {
    final (icon, tone, title, body) = switch (_phase.value) {
      _Phase.checking => (
        null,
        AppColors.primary,
        'Mengecek pembayaran…',
        'Sebentar, kami sedang memastikan pembayaran Anda.',
      ),
      _Phase.credited => (
        Iconsax.tick_circle,
        AppColors.success,
        'Pembayaran berhasil',
        'Token sudah masuk ke saldo pribadi Anda dan tidak hangus tiap bulan.',
      ),
      _Phase.unfinished => (
        Iconsax.clock,
        AppColors.warning,
        'Pembayaran belum masuk',
        'Kalau Anda baru saja membayar, tunggu sebentar lalu cek lagi. Token '
            'masuk otomatis setelah pembayaran dikonfirmasi — Anda tidak perlu '
            'membayar lagi.',
      ),
      _ => (
        Iconsax.wifi_square,
        AppColors.textMuted,
        'Gagal mengecek status',
        'Koneksi ke server terputus. Ini tidak membatalkan pembayaran Anda — '
            'coba cek lagi setelah sinyal membaik.',
      ),
    };

    final settled = _phase.value == _Phase.credited;
    final retryable =
        _phase.value == _Phase.unfinished || _phase.value == _Phase.unreachable;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24.w, 48.h, 24.w, 32.h),
      child: Column(
        children: [
          Container(
            width: 72.w,
            height: 72.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: icon == null
                ? SizedBox(
                    width: 26.w,
                    height: 26.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: tone,
                    ),
                  )
                : Icon(icon, size: 34.sp, color: tone),
          ),
          SizedBox(height: 18.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5.sp,
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'No. pesanan ${widget.orderNumber}',
            style: TextStyle(fontSize: 11.sp, color: AppColors.textMuted),
          ),
          SizedBox(height: 26.h),
          if (retryable)
            SizedBox(
              width: double.infinity,
              height: 46.h,
              child: ElevatedButton.icon(
                onPressed: () => _confirmPayment(attempts: 3),
                icon: Icon(Iconsax.refresh, size: 16.sp, color: Colors.white),
                label: Text(
                  'Cek lagi',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
          if (settled)
            SizedBox(
              width: double.infinity,
              height: 46.h,
              child: ElevatedButton(
                onPressed: () => Get.back(result: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'Kembali ke Token AI',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (retryable) ...[
            SizedBox(height: 6.h),
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text(
                'Nanti saja',
                style: TextStyle(fontSize: 12.5.sp, color: AppColors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
