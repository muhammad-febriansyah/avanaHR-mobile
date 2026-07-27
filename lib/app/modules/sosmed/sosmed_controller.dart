import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../core/utils/image_compressor.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/models/ess_models.dart';
import '../../data/providers/api_client.dart';
import '../../data/providers/avana_api.dart';

/// The employee social wall: a paginated feed, posting, likes and comments.
///
/// Every list here comes from the server already scoped to the caller's tenant,
/// so nothing is filtered again on the client.
class SosmedController extends GetxController {
  final AvanaApi _api = AvanaApi();

  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final submitting = false.obs;

  final posts = <SocialPostItem>[].obs;
  final categories = <SocialCategoryItem>[].obs;
  final leaders = <SocialLeaderItem>[].obs;

  /// null = "Semua"; otherwise the category being filtered on.
  final activeCategory = Rxn<int>();
  final leaderRange = 'all'.obs;
  final loadingLeaders = false.obs;

  int _page = 1;
  bool _hasMore = true;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    _page = 1;
    _hasMore = true;

    try {
      final results = await Future.wait([
        _api.socialCategories(),
        _api.socialFeed(page: 1, categoryId: activeCategory.value),
      ]);

      categories.assignAll(results[0] as List<SocialCategoryItem>);

      final feed = results[1] as Paged<SocialPostItem>;
      posts.assignAll(feed.items);
      _hasMore = feed.hasMore;
    } catch (_) {
      posts.clear();
    }

    isLoading.value = false;
  }

  /// Next page, appended. No-op while one is already in flight or at the end.
  Future<void> loadMore() async {
    if (isLoadingMore.value || !_hasMore || isLoading.value) {
      return;
    }

    isLoadingMore.value = true;

    try {
      final feed = await _api.socialFeed(
        page: _page + 1,
        categoryId: activeCategory.value,
      );
      posts.addAll(feed.items);
      _page += 1;
      _hasMore = feed.hasMore;
    } catch (_) {
      // Keep what is already on screen; the user can pull to refresh.
    }

    isLoadingMore.value = false;
  }

  Future<void> filterBy(int? categoryId) async {
    if (activeCategory.value == categoryId) {
      return;
    }

    activeCategory.value = categoryId;
    await load();
  }

  Future<bool> createPost({
    required String body,
    int? categoryId,
    String? imagePath,
  }) async {
    submitting.value = true;

    try {
      // Shrink on the device: a raw camera shot easily exceeds the server's
      // 5 MB limit and would make the feed slow to scroll.
      final prepared = imagePath == null
          ? null
          : await ImageCompressor.compress(imagePath);

      final res = await _api.createSocialPost(
        body: body,
        categoryId: categoryId,
        imagePath: prepared,
      );
      submitting.value = false;

      if (res.statusCode == 201) {
        AppToast.success('Postingan terkirim');
        await load();
        return true;
      }

      AppToast.error(ApiClient.messageFrom(res, 'Gagal mengirim postingan.'));
      return false;
    } on DioException catch (e) {
      submitting.value = false;
      AppToast.error(ApiClient.errorMessage(e));
      return false;
    }
  }

  /// Flip the heart straight away, then reconcile with what the server counted.
  /// A failed request rolls the optimistic change back.
  Future<void> toggleLike(SocialPostItem post) async {
    final index = posts.indexWhere((p) => p.id == post.id);
    if (index < 0) {
      return;
    }

    final wasLiked = post.liked;
    final wasCount = post.likesCount;

    post.liked = !wasLiked;
    post.likesCount = wasLiked ? wasCount - 1 : wasCount + 1;
    posts.refresh();

    try {
      final result = await _api.toggleSocialLike(post.id);
      post.liked = result['liked'] == true;
      post.likesCount = (result['likes_count'] as num?)?.toInt() ?? wasCount;
      posts.refresh();
    } on DioException catch (e) {
      post.liked = wasLiked;
      post.likesCount = wasCount;
      posts.refresh();
      AppToast.error(ApiClient.errorMessage(e));
    }
  }

  Future<bool> deletePost(SocialPostItem post) async {
    try {
      await _api.deleteSocialPost(post.id);
      posts.removeWhere((p) => p.id == post.id);
      AppToast.success('Postingan dihapus');
      return true;
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
      return false;
    }
  }

  /// Edit your own post. Likes and comments are untouched — the post keeps its
  /// id, so fixing a typo does not throw away the conversation under it.
  Future<SocialPostItem?> editPost({
    required SocialPostItem post,
    required String body,
    int? categoryId,
    String? imagePath,
    bool removeImage = false,
  }) async {
    submitting.value = true;

    try {
      final prepared = imagePath == null
          ? null
          : await ImageCompressor.compress(imagePath);

      final res = await _api.updateSocialPost(
        id: post.id,
        body: body,
        categoryId: categoryId,
        imagePath: prepared,
        removeImage: removeImage,
      );
      submitting.value = false;

      final updated = SocialPostItem.fromJson(
        Map<String, dynamic>.from(res.data['data'] as Map),
      );

      final index = posts.indexWhere((p) => p.id == post.id);
      if (index >= 0) {
        posts[index] = updated;
        posts.refresh();
      }

      AppToast.success('Postingan diperbarui');
      return updated;
    } on DioException catch (e) {
      submitting.value = false;
      AppToast.error(ApiClient.errorMessage(e));
      return null;
    }
  }

  /// One post on its own, for the detail screen and notification deep links.
  Future<SocialPostItem?> fetchPost(int id) async {
    try {
      return await _api.socialPost(id);
    } catch (_) {
      return null;
    }
  }

  /// Flag a post for HR to review. Posts go live immediately, so this is how
  /// the wall polices itself between HR sweeps.
  Future<bool> reportPost(SocialPostItem post, String? reason) async {
    try {
      await _api.reportSocialPost(post.id, reason);
      AppToast.success('Laporan terkirim. Tim HR akan meninjau.');
      return true;
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
      return false;
    }
  }

  Future<List<SocialCommentItem>> comments(int postId) async {
    try {
      return await _api.socialComments(postId);
    } catch (_) {
      return [];
    }
  }

  Future<SocialCommentItem?> addComment(
    SocialPostItem post,
    String body,
  ) async {
    try {
      final res = await _api.createSocialComment(post.id, body);
      post.commentsCount += 1;
      posts.refresh();

      return SocialCommentItem.fromJson(
        Map<String, dynamic>.from(res.data['data'] as Map),
      );
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
      return null;
    }
  }

  Future<bool> deleteComment(SocialPostItem post, int commentId) async {
    try {
      await _api.deleteSocialComment(commentId);
      if (post.commentsCount > 0) {
        post.commentsCount -= 1;
        posts.refresh();
      }
      return true;
    } on DioException catch (e) {
      AppToast.error(ApiClient.errorMessage(e));
      return false;
    }
  }

  /// Whether the leaderboard is showing the full list rather than the top 20.
  final showAllLeaders = false.obs;

  Future<void> loadLeaderboard({String? range, bool? showAll}) async {
    if (range != null) {
      leaderRange.value = range;
    }

    if (showAll != null) {
      showAllLeaders.value = showAll;
    }

    loadingLeaders.value = true;

    try {
      leaders.assignAll(
        await _api.socialLeaderboard(
          range: leaderRange.value,
          limit: showAllLeaders.value ? 100 : 20,
        ),
      );
    } catch (_) {
      leaders.clear();
    }

    loadingLeaders.value = false;
  }
}
