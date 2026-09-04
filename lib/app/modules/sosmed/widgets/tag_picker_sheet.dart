import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../data/models/ess_models.dart';
import '../../../data/providers/avana_api.dart';

/// Opens the "Tag Teman" picker over a compose/comment sheet and resolves
/// with the colleagues picked, or null if dismissed without confirming.
///
/// [initiallySelected] pre-checks whoever is already tagged — reopening the
/// picker to add one more person should not lose the others.
Future<List<TaggedPerson>?> showTagPickerSheet(
  BuildContext context, {
  List<TaggedPerson> initiallySelected = const [],
}) {
  return showAppSheet<List<TaggedPerson>?>(
    context,
    scrollable: true,
    child: _TagPickerSheet(initiallySelected: initiallySelected),
  );
}

class _TagPickerSheet extends StatefulWidget {
  final List<TaggedPerson> initiallySelected;

  const _TagPickerSheet({required this.initiallySelected});

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  final AvanaApi _api = AvanaApi();
  final TextEditingController _searchC = TextEditingController();
  Timer? _debounce;

  final RxList<TaggedPerson> _results = <TaggedPerson>[].obs;
  final RxBool _loading = true.obs;
  final RxBool _failed = false.obs;

  // Keyed by id so re-picking the same person (from a fresh search) still
  // shows as checked.
  late final RxMap<int, TaggedPerson> _selected = <int, TaggedPerson>{
    for (final person in widget.initiallySelected) person.id: person,
  }.obs;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    _loading.value = true;
    _failed.value = false;

    try {
      _results.assignAll(await _api.directorySearch(query.trim()));
    } catch (_) {
      _results.clear();
      _failed.value = true;
    }

    _loading.value = false;
  }

  void _toggle(TaggedPerson person) {
    if (_selected.containsKey(person.id)) {
      _selected.remove(person.id);
    } else if (_selected.length < 20) {
      _selected[person.id] = person;
    } else {
      Get.snackbar('', 'Maksimal 20 orang yang bisa ditag.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHeader('Tag Teman'),
          SizedBox(height: 14.h),
          TextField(
            controller: _searchC,
            onChanged: _onQueryChanged,
            style: TextStyle(fontSize: 13.5.sp),
            decoration: InputDecoration(
              hintText: 'Cari nama karyawan…',
              hintStyle: TextStyle(fontSize: 13.sp, color: AppColors.textMuted),
              prefixIcon: Icon(
                Iconsax.search_normal_1,
                size: 18.sp,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: AppColors.muted,
              contentPadding: EdgeInsets.symmetric(vertical: 10.h),
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
          SizedBox(height: 6.h),
          Obx(
            () => Text(
              _selected.isEmpty
                  ? 'Belum ada yang ditag'
                  : '${_selected.length} orang ditag',
              style: TextStyle(fontSize: 11.5.sp, color: AppColors.textMuted),
            ),
          ),
          SizedBox(height: 4.h),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 340.h),
            child: Obx(() {
              if (_loading.value && _results.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 30.h),
                  child: Center(
                    child: SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              if (_failed.value) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: Center(
                    child: Text(
                      'Daftar karyawan gagal dimuat.',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                );
              }

              if (_results.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: Center(
                    child: Text(
                      'Tidak ada karyawan ditemukan.',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _results.length,
                separatorBuilder: (_, _) => SizedBox(height: 2.h),
                itemBuilder: (_, index) {
                  final person = _results[index];

                  return Obx(() {
                    final checked = _selected.containsKey(person.id);

                    return InkWell(
                      borderRadius: BorderRadius.circular(10.r),
                      onTap: () => _toggle(person),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        child: Row(
                          children: [
                            _avatar(person),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(
                                person.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              checked
                                  ? Iconsax.tick_circle5
                                  : Iconsax.tick_circle,
                              size: 20.sp,
                              color: checked
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    );
                  });
                },
              );
            }),
          ),
          SizedBox(height: 16.h),
          AppSubmitButton(
            loading: false,
            label: 'Selesai',
            onPressed: () => Get.back(result: _selected.values.toList()),
          ),
        ],
      ),
    );
  }

  Widget _avatar(TaggedPerson person) {
    if (person.photoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(99.r),
        child: CachedNetworkImage(
          imageUrl: person.photoUrl!,
          width: 34.w,
          height: 34.w,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _initials(person),
        ),
      );
    }

    return _initials(person);
  }

  Widget _initials(TaggedPerson person) {
    return Container(
      width: 34.w,
      height: 34.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        person.name.isEmpty ? '?' : person.name.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
