import 'package:get/get.dart';

/// Holds the active bottom-navigation tab for the app shell.
class MainController extends GetxController {
  final tab = 0.obs;

  void changeTab(int index) => tab.value = index;
}
