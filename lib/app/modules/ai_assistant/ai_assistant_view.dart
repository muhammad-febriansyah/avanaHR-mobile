import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/ui.dart';
import '../../data/models/ai_models.dart';
import 'ai_assistant_controller.dart';

class AiAssistantView extends GetView<AiAssistantController> {
  const AiAssistantView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'AI Assistant',
      subtitle: 'Asisten HR pribadi Anda',
      actions: [
        HeaderAction(Iconsax.messages_2, () => _openHistory(context)),
        HeaderAction(Iconsax.message_add_1, controller.newChat),
      ],
      child: Column(
        children: [
          Obx(() {
            final usage = controller.usage.value;
            return usage == null ? const SizedBox.shrink() : _TokenMeter(usage);
          }),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.messages.isEmpty) {
                return const Loading();
              }
              if (controller.messages.isEmpty) {
                return _EmptyState(
                  ready: controller.ready.value,
                  suggestions: controller.suggestions,
                  onPick: controller.send,
                );
              }
              return _Transcript();
            }),
          ),
          _Composer(),
        ],
      ),
    );
  }

  void _openHistory(BuildContext context) {
    showAppSheet(context, scrollable: true, child: _HistorySheet());
  }
}

/// Slim monthly token allowance bar, mirrors the web assistant meter.
class _TokenMeter extends StatelessWidget {
  final AiTokenUsage usage;
  const _TokenMeter(this.usage);

  @override
  Widget build(BuildContext context) {
    final fraction = usage.fraction;
    final Color barColor = fraction >= 0.9
        ? AppColors.destructive
        : fraction >= 0.7
        ? AppColors.warning
        : AppColors.primary;

    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 4.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.flash_1, size: 14.sp, color: AppColors.textMuted),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Token AI · ${usage.period}',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                usage.hasQuota
                    ? '${_fmt(usage.used)} / ${_fmt(usage.quota!)}'
                    : _fmt(usage.used),
                style: TextStyle(
                  fontSize: 11.5.sp,
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(99.r),
            child: LinearProgressIndicator(
              value: usage.hasQuota ? fraction : 0,
              minHeight: 6.h,
              backgroundColor: AppColors.muted,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          SizedBox(height: 6.h),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              usage.hasQuota
                  ? 'Sisa ${_fmt(usage.remaining)} token'
                  : 'Kuota tak terbatas',
              style: TextStyle(fontSize: 10.5.sp, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Welcome screen with quick-start prompt chips.
class _EmptyState extends StatelessWidget {
  final bool ready;
  final List<String> suggestions;
  final void Function(String) onPick;

  const _EmptyState({
    required this.ready,
    required this.suggestions,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 20.h),
      children: [
        Center(
          child: Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(Iconsax.magicpen, color: Colors.white, size: 30.sp),
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          'Ada yang bisa dibantu?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          ready
              ? 'Tanya seputar cuti, slip gaji, kehadiran, dan pengajuan Anda. Jawaban hanya berdasarkan data Anda sendiri.'
              : 'Asisten AI belum diaktifkan. Hubungi admin perusahaan untuk mengatur penyedia AI.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5.sp,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        SizedBox(height: 22.h),
        ...suggestions.map(
          (s) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: ContentCard(
              onTap: () => onPick(s),
              child: Row(
                children: [
                  Icon(Iconsax.magicpen, size: 17.sp, color: AppColors.primary),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Iconsax.arrow_right_3,
                    size: 15.sp,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The scrolling message list, plus a typing indicator while awaiting a reply.
class _Transcript extends GetView<AiAssistantController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = controller.messages;
      final showTyping = controller.sending.value;

      return ListView.builder(
        controller: controller.scrollCtrl,
        padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 16.h),
        itemCount: items.length + (showTyping ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= items.length) {
            return const _TypingBubble();
          }
          return _MessageBubble(items[index]);
        },
      );
    });
  }
}

class _MessageBubble extends StatelessWidget {
  final AiChatMessage message;
  const _MessageBubble(this.message);

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    final avatar = Container(
      width: 30.w,
      height: 30.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: isUser
            ? null
            : const LinearGradient(
                colors: [AppColors.primary, Color(0xFF7C3AED)],
              ),
        color: isUser ? AppColors.primaryLight : null,
        borderRadius: BorderRadius.circular(9.r),
      ),
      child: Icon(
        isUser ? Iconsax.user : Iconsax.magicpen,
        size: 15.sp,
        color: isUser ? AppColors.primary : Colors.white,
      ),
    );

    final bubble = Flexible(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(13.r),
        ),
        child: _FormattedText(
          message.content,
          color: isUser ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: isUser ? TextDirection.rtl : TextDirection.ltr,
        children: [
          avatar,
          SizedBox(width: 9.w),
          bubble,
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(9.r),
            ),
            child: Icon(Iconsax.magicpen, size: 15.sp, color: Colors.white),
          ),
          SizedBox(width: 9.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(13.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14.w,
                  height: 14.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 9.w),
                Text(
                  'mengetik…',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom message composer.
class _Composer extends GetView<AiAssistantController> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: controller.inputCtrl,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                    border: InputBorder.none,
                    hintText: 'Tulis pertanyaan…',
                    hintStyle: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Obx(() {
              final busy = controller.sending.value;
              return GestureDetector(
                onTap: busy
                    ? null
                    : () => controller.send(controller.inputCtrl.text),
                child: Container(
                  width: 46.w,
                  height: 46.w,
                  decoration: BoxDecoration(
                    color: busy ? AppColors.border : AppColors.primary,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: busy
                      ? Padding(
                          padding: EdgeInsets.all(13.w),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Iconsax.send_1, color: Colors.white, size: 20.sp),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Conversation history in a bottom sheet.
class _HistorySheet extends GetView<AiAssistantController> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          const SectionTitle('Riwayat Percakapan'),
          SizedBox(height: 12.h),
          Obx(() {
            if (controller.conversations.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: const EmptyState(
                  icon: Iconsax.messages_1,
                  message: 'Belum ada percakapan.',
                ),
              );
            }
            return Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: controller.conversations.length,
                separatorBuilder: (_, _) => SizedBox(height: 8.h),
                itemBuilder: (context, index) {
                  final c = controller.conversations[index];
                  final active = c.id == controller.activeId.value;
                  return ContentCard(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    onTap: () {
                      Get.back<void>();
                      controller.openConversation(c.id);
                    },
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.message_text_1,
                          size: 17.sp,
                          color: active
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => controller.deleteConversation(c.id),
                          child: Padding(
                            padding: EdgeInsets.all(4.w),
                            child: Icon(
                              Iconsax.trash,
                              size: 16.sp,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Renders assistant/user text with lightweight markdown: **bold** spans,
/// preserved line breaks, and `- ` bullets turned into `•`.
class _FormattedText extends StatelessWidget {
  final String text;
  final Color color;

  const _FormattedText(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: 13.5.sp, color: color, height: 1.5);
    return RichText(
      text: TextSpan(style: base, children: _spans(base)),
    );
  }

  List<TextSpan> _spans(TextStyle base) {
    final normalised = text.replaceAll(
      RegExp(r'^\s*[-*]\s', multiLine: true),
      '• ',
    );
    final spans = <TextSpan>[];
    final parts = normalised.split('**');

    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) {
        continue;
      }
      spans.add(
        TextSpan(
          text: parts[i],
          style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w700) : null,
        ),
      );
    }

    return spans;
  }
}

/// Groups an integer with `.` thousands separators (id-ID style).
String _fmt(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  return (value < 0 ? '-' : '') + buffer.toString();
}
