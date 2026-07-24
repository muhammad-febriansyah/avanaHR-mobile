import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import '../../core/widgets/app_toast.dart';
import '../../data/models/ai_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

/// Drives the mobile AI Assistant chat. All data the assistant returns is
/// scoped to the signed-in employee by the backend — it can answer about the
/// user's own cuti, slip gaji, kehadiran, and pengajuan, never anyone else's.
class AiAssistantController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final sending = false.obs;
  final ready = false.obs;

  final messages = <AiChatMessage>[].obs;
  final conversations = <AiConversationSummary>[].obs;
  final suggestions = <String>[].obs;
  final usage = Rxn<AiTokenUsage>();
  final activeId = Rxn<int>();

  final TextEditingController inputCtrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();

  @override
  void onInit() {
    super.onInit();
    loadSession();
  }

  @override
  void onClose() {
    inputCtrl.dispose();
    scrollCtrl.dispose();
    super.onClose();
  }

  Future<void> loadSession() async {
    isLoading.value = true;
    try {
      final session = await _api.aiSession();
      ready.value = session.ready;
      usage.value = session.usage;
      conversations.assignAll(session.conversations);
      suggestions.assignAll(session.suggestions);
    } catch (_) {
      // Keep whatever is already on screen; the composer still works offline-ish.
    }
    isLoading.value = false;
  }

  /// Start a fresh conversation (clears the transcript, keeps history).
  void newChat() {
    if (sending.value) return;
    activeId.value = null;
    messages.clear();
    inputCtrl.clear();
  }

  /// Load one of the caller's past conversations into the transcript.
  Future<void> openConversation(int id) async {
    if (sending.value || id == activeId.value) return;
    activeId.value = id;
    messages.clear();
    isLoading.value = true;
    try {
      messages.assignAll(await _api.aiMessages(id));
    } catch (_) {
      AppToast.error('Gagal memuat percakapan.');
    }
    isLoading.value = false;
    _scrollToBottom();
  }

  Future<void> deleteConversation(int id) async {
    try {
      await _api.aiDeleteConversation(id);
      conversations.removeWhere((c) => c.id == id);
      if (activeId.value == id) {
        newChat();
      }
      AppToast.success('Percakapan dihapus');
    } on DioException catch (e) {
      AppToast.error(
        ApiClient.messageFrom(e.response, 'Gagal menghapus percakapan.'),
      );
    }
  }

  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || sending.value) {
      return;
    }

    inputCtrl.clear();
    sending.value = true;
    messages.add(AiChatMessage(role: 'user', content: message));
    _scrollToBottom();

    try {
      final res = await _api.aiChat(message, conversationId: activeId.value);

      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(res.data);

        final id = (data['conversation_id'] as num?)?.toInt();
        activeId.value = id;

        messages.add(
          AiChatMessage.fromJson(Map<String, dynamic>.from(data['reply'])),
        );

        if (data['usage'] != null) {
          usage.value = AiTokenUsage.fromJson(
            Map<String, dynamic>.from(data['usage']),
          );
        }

        _rememberConversation(id, data['title']?.toString());
      } else {
        AppToast.error(ApiClient.messageFrom(res, 'Gagal mengirim pesan.'));
        messages.add(
          const AiChatMessage(
            role: 'assistant',
            content: 'Maaf, pesan gagal dikirim. Coba lagi.',
          ),
        );
      }
    } on DioException catch (e) {
      AppToast.error(
        ApiClient.messageFrom(e.response, 'Gagal terhubung ke server.'),
      );
      messages.add(
        const AiChatMessage(
          role: 'assistant',
          content: 'Maaf, terjadi kesalahan koneksi. Coba lagi.',
        ),
      );
    }

    sending.value = false;
    _scrollToBottom();
  }

  /// Prepend a freshly created conversation to the history list.
  void _rememberConversation(int? id, String? title) {
    if (id == null || conversations.any((c) => c.id == id)) {
      return;
    }
    conversations.insert(
      0,
      AiConversationSummary(id: id, title: title ?? 'Percakapan baru'),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollCtrl.hasClients) {
        scrollCtrl.animateTo(
          scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
