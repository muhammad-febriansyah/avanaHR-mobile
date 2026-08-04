import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/models/ess_models.dart';
import '../sosmed_controller.dart';
import '../sosmed_view.dart' show hexColor;

/// Open a post and its thread as a sheet over the feed.
///
/// There used to be a detail page in between: tapping a card pushed a whole
/// route, which then raised the comments as a sheet anyway. Two steps to reach
/// a thread, and the feed's scroll position was rebuilt on the way back. The
/// sheet does the same job in one tap, and the feed stays exactly where it was
/// underneath it.
///
/// The post instance is the feed's own, so a like or a new comment moves the
/// counts on the card behind the sheet at the same time.
Future<void> showPostComments(
  BuildContext context,
  SocialPostItem post, {
  bool focusComposer = false,
}) {
  return showAppSheet<void>(
    context,
    scrollable: true,
    child: PostCommentsSheet(post: post, focusComposer: focusComposer),
  );
}

/// The post, its thread, and the box to reply in — the whole discussion in one
/// sheet.
class PostCommentsSheet extends StatefulWidget {
  final SocialPostItem post;

  /// Put the cursor in the composer on arrival — what someone who tapped the
  /// comment button came for, rather than the thread's first line.
  final bool focusComposer;

  const PostCommentsSheet({
    super.key,
    required this.post,
    this.focusComposer = false,
  });

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  final SosmedController controller = Get.find<SosmedController>();
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();

  late final Rxn<SocialPostItem> _post = Rxn<SocialPostItem>(widget.post);
  final RxList<SocialCommentItem> _comments = <SocialCommentItem>[].obs;
  final RxBool _loading = true.obs;
  final RxBool _sending = false.obs;

  /// The comment being replied to, or null for a top-level comment.
  final Rxn<SocialCommentItem> _replyTo = Rxn<SocialCommentItem>();

  @override
  void initState() {
    super.initState();
    _load();

    if (widget.focusComposer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focus.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _loading.value = true;

    final id = widget.post.id;

    // The feed handed us the post, but counts move while the list sits in
    // memory — take the fresh numbers onto the feed's own instance so the card
    // behind the sheet lands on the same figures.
    final fresh = await controller.fetchPost(id);
    if (fresh != null) {
      widget.post
        ..likesCount = fresh.likesCount
        ..commentsCount = fresh.commentsCount
        ..liked = fresh.liked;
      controller.posts.refresh();
      _post.refresh();
    }

    _comments.assignAll(await controller.comments(id));
    _loading.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final post = _post.value;

      if (post == null) {
        return const SizedBox.shrink();
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 10.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(99.r),
            ),
          ),
          _header(post),
          Divider(height: 1, color: AppColors.border),
          Flexible(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
              children: [
                _postBody(post),
                SizedBox(height: 14.h),
                _actions(post),
                SizedBox(height: 6.h),
                Divider(height: 20.h, color: AppColors.border),
                ..._threadOrPlaceholder(post),
              ],
            ),
          ),
          _composer(post),
        ],
      );
    });
  }

  List<Widget> _threadOrPlaceholder(SocialPostItem post) {
    if (_loading.value && _comments.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 30.h),
          child: const Loading(),
        ),
      ];
    }

    if (_comments.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 30.h),
          child: Center(
            child: Text(
              'Belum ada komentar. Jadi yang pertama!',
              style: TextStyle(fontSize: 13.sp, color: AppColors.textMuted),
            ),
          ),
        ),
      ];
    }

    return _comments.map((c) => _thread(post, c)).toList();
  }

  Widget _header(SocialPostItem post) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 10.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              post.commentsCount == 0
                  ? 'Komentar'
                  : '${post.commentsCount} komentar',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: Get.back<void>,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(8.w),
              child: Icon(
                Iconsax.close_circle,
                size: 20.sp,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Liking and editing, kept with the post rather than on a bar of their own:
  /// the sheet's foot belongs to the composer.
  Widget _actions(SocialPostItem post) {
    return Row(
      children: [
        _action(
          icon: post.liked ? Iconsax.heart5 : Iconsax.heart,
          label: '${post.likesCount}',
          tone: post.liked ? AppColors.destructive : AppColors.textMuted,
          onTap: () async {
            await controller.toggleLike(post);
            _post.refresh();
          },
        ),
        _action(
          icon: Iconsax.message_text,
          label: '${post.commentsCount}',
          tone: AppColors.textMuted,
          onTap: () => _focus.requestFocus(),
        ),
        if (post.isMine)
          _action(
            icon: Iconsax.edit_2,
            label: 'Edit',
            tone: AppColors.primary,
            onTap: () => showPostEditSheet(
              context,
              post,
              onUpdated: (updated) => _post.value = updated,
            ),
          ),
      ],
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required Color tone,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19.sp, color: tone),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                  color: tone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postBody(SocialPostItem post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _avatar(post.authorPhoto, post.author, 40),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.author,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    [
                      RelativeTime.format(post.createdAt),
                      if (post.edited) 'diedit',
                    ].where((part) => part.isNotEmpty).join(' · '),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        if (post.category != null) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: hexColor(post.categoryColor).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(99.r),
            ),
            child: Text(
              post.category!,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: hexColor(post.categoryColor),
              ),
            ),
          ),
        ],

        SizedBox(height: 12.h),
        Text(
          post.body,
          style: TextStyle(
            fontSize: 14.sp,
            height: 1.55,
            color: AppColors.textPrimary,
          ),
        ),

        if (post.imageUrl != null) ...[
          SizedBox(height: 14.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: CachedNetworkImage(
              imageUrl: post.imageUrl!,
              width: double.infinity,
              // Whole photo here; the feed card is where it is cropped.
              fit: BoxFit.fitWidth,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ],
    );
  }

  /// A top-level comment and its replies, tied together by an elbow line.
  ///
  /// Indentation alone is ambiguous once a thread scrolls: the reader has to
  /// guess which comment above a reply belongs to. The line answers it.
  Widget _thread(SocialPostItem post, SocialCommentItem comment) {
    if (comment.replies.isEmpty) {
      return _comment(post, comment);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No gap under the parent — the connector picks up where it ends.
        _comment(post, comment, tightBottom: true),
        ...comment.replies.asMap().entries.map(
          (entry) => IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _connectorWidth.w,
                  child: CustomPaint(
                    painter: _ThreadConnector(
                      // The last reply ends the line at its elbow; the others
                      // carry it on down to the next one.
                      isLast: entry.key == comment.replies.length - 1,
                      lineX: 16.w,
                      elbowY: 13.h + 14.h,
                      color: AppColors.border,
                    ),
                  ),
                ),
                Expanded(child: _comment(post, entry.value, isReply: true)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _comment(
    SocialPostItem post,
    SocialCommentItem comment, {
    bool isReply = false,
    bool tightBottom = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        top: isReply ? 14.h : 0,
        bottom: tightBottom ? 0 : 14.h,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(comment.authorPhoto, comment.author, isReply ? 26 : 32),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                // Muted, not surface: the thread sits on the sheet's own white,
                // and a white bubble on white would lose its edges.
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.author,
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (comment.isMine)
                        GestureDetector(
                          onTap: () async {
                            final ok = await controller.deleteComment(
                              post,
                              comment.id,
                            );
                            if (ok) {
                              _comments.removeWhere((c) => c.id == comment.id);
                              _post.refresh();
                            }
                          },
                          child: Icon(
                            Iconsax.trash,
                            size: 15.sp,
                            color: AppColors.destructive,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  // The name leads the text rather than sitting above it, so a
                  // reply reads as a sentence addressed to someone.
                  Text.rich(
                    TextSpan(
                      children: [
                        if (comment.replyTo != null)
                          TextSpan(
                            text: '${comment.replyTo} ',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        TextSpan(text: comment.body),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 13.sp,
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  GestureDetector(
                    onTap: () {
                      _replyTo.value = comment;
                      _focus.requestFocus();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      'Balas',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pinned to the foot of the sheet, so the box to type in is always where the
  /// thumb already is.
  Widget _composer(SocialPostItem post) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Without this banner a reply looks identical to a new comment, and
          // the user cannot tell where it will land.
          Obx(() {
            final target = _replyTo.value;

            if (target == null) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                children: [
                  Icon(Iconsax.undo, size: 14.sp, color: AppColors.textMuted),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'Membalas ${target.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _replyTo.value = null,
                    child: Icon(
                      Iconsax.close_circle,
                      size: 16.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _focus,
                  style: TextStyle(fontSize: 13.5.sp),
                  decoration: InputDecoration(
                    hintText: 'Tulis komentar…',
                    hintStyle: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: AppColors.muted,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(99.r),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(99.r),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(99.r),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Obx(
                () => GestureDetector(
                  onTap: _sending.value ? null : () => _send(post),
                  child: Container(
                    width: 42.w,
                    height: 42.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _sending.value
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Iconsax.send_1,
                            size: 18.sp,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _send(SocialPostItem post) async {
    final body = _input.text.trim();

    if (body.isEmpty) {
      return;
    }

    final target = _replyTo.value;

    _sending.value = true;
    final created = await controller.addComment(
      post,
      body,
      parentId: target?.id,
    );
    _sending.value = false;

    if (created == null) {
      return;
    }

    _input.clear();
    _replyTo.value = null;

    if (created.parentId == null) {
      _comments.add(created);
    } else {
      // Rebuild the parent with the reply appended: SocialCommentItem holds an
      // unmodifiable list, and the thread must show the reply immediately.
      final index = _comments.indexWhere((c) => c.id == created.parentId);

      if (index >= 0) {
        final parent = _comments[index];
        _comments[index] = SocialCommentItem(
          id: parent.id,
          body: parent.body,
          author: parent.author,
          authorPhoto: parent.authorPhoto,
          isMine: parent.isMine,
          createdAt: parent.createdAt,
          parentId: parent.parentId,
          replies: [...parent.replies, created],
        );
      } else {
        await _load();
      }
    }

    _post.refresh();
  }

  Widget _avatar(String? photo, String name, double size) {
    if (photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(99.r),
        child: CachedNetworkImage(
          imageUrl: photo,
          width: size.w,
          height: size.w,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _initials(name, size),
        ),
      );
    }

    return _initials(name, size);
  }

  Widget _initials(String name, double size) {
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: (size * 0.4).sp,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Edit sheet — text and category only. Swapping the photo is left to the
/// compose flow; an edit is nearly always a wording fix.
///
/// [onUpdated] receives the saved post, for a caller holding its own copy. The
/// feed list is swapped by the controller either way.
void showPostEditSheet(
  BuildContext context,
  SocialPostItem post, {
  ValueChanged<SocialPostItem>? onUpdated,
}) {
  final controller = Get.find<SosmedController>();
  final bodyC = TextEditingController(text: post.body);
  final categoryId = Rxn<int>(post.categoryId);

  showAppFormSheet<void>(
    context,
    padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 24.h),
    children: [
      Text(
        'Edit Postingan',
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      SizedBox(height: 14.h),
      // No categories loaded: leave the row out entirely rather than open a gap
      // above the text field.
      Obx(() {
        if (controller.categories.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: controller.categories.map((category) {
                final selected = categoryId.value == category.id;
                final accent = hexColor(category.color);

                return GestureDetector(
                  onTap: () => categoryId.value = selected ? null : category.id,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.12)
                          : AppColors.muted,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: selected ? accent : AppColors.textMuted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 14.h),
          ],
        );
      }),
      TextField(
        controller: bodyC,
        maxLines: 5,
        maxLength: 500,
        style: TextStyle(fontSize: 14.sp),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.muted,
          contentPadding: EdgeInsets.all(14.w),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: AppColors.primary, width: 1.4),
          ),
        ),
      ),
      SizedBox(height: 16.h),
      Obx(
        () => GestureDetector(
          onTap: controller.submitting.value
              ? null
              : () async {
                  final updated = await controller.editPost(
                    post: post,
                    body: bodyC.text.trim(),
                    categoryId: categoryId.value,
                  );

                  if (updated != null) {
                    onUpdated?.call(updated);
                    Get.back<void>();
                  }
                },
          child: Container(
            height: 48.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: controller.submitting.value
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Simpan Perubahan',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    ],
  );
}

/// How far a reply is pushed in. Wide enough to clear the parent's 32px avatar
/// and leave the elbow somewhere to travel.
const double _connectorWidth = 42;

/// Draws the elbow that ties a reply to the comment above it: a vertical line
/// dropping from under the parent's avatar, turning right into the reply's.
class _ThreadConnector extends CustomPainter {
  /// The last reply stops the line at its own elbow, so the thread does not
  /// trail off into empty space.
  final bool isLast;

  final double lineX;
  final double elbowY;
  final Color color;

  const _ThreadConnector({
    required this.isLast,
    required this.lineX,
    required this.elbowY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const radius = 8.0;
    final stopY = isLast ? elbowY : size.height;

    final path = Path()
      ..moveTo(lineX, 0)
      ..lineTo(lineX, isLast ? elbowY - radius : stopY);

    if (isLast) {
      // Rounded corner, then out to the avatar.
      path
        ..quadraticBezierTo(lineX, elbowY, lineX + radius, elbowY)
        ..lineTo(size.width, elbowY);
    } else {
      // A branch that continues: draw the elbow separately so the trunk stays
      // unbroken behind it.
      canvas.drawPath(
        Path()
          ..moveTo(lineX, elbowY - radius)
          ..quadraticBezierTo(lineX, elbowY, lineX + radius, elbowY)
          ..lineTo(size.width, elbowY),
        paint,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ThreadConnector oldDelegate) =>
      oldDelegate.isLast != isLast ||
      oldDelegate.lineX != lineX ||
      oldDelegate.elbowY != elbowY ||
      oldDelegate.color != color;
}
