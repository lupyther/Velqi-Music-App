import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:velqi/ui/screens/Home/home_screen_controller.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    return Obx(
      () => Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(
            top: BorderSide(
              color: Color(0xFF1A1A1A),
              width: 0.8,
            ),
          ),
        ),
        child: NavigationBar(
          onDestinationSelected:
              homeScreenController.onBottonBarTabSelected,
          selectedIndex: homeScreenController.tabIndex.toInt(),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          indicatorColor: Colors.white12,
          labelBehavior:
              NavigationDestinationLabelBehavior.alwaysShow,
          animationDuration: const Duration(milliseconds: 400),
          destinations: [
            _navDest(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: modifyNgetlabel('home'.tr),
              selected: homeScreenController.tabIndex.value == 0,
            ),
            _navDest(
              icon: Icons.search_outlined,
              selectedIcon: Icons.search_rounded,
              label: modifyNgetlabel('search'.tr),
              selected: homeScreenController.tabIndex.value == 1,
            ),
            _navDest(
              icon: Icons.library_music_outlined,
              selectedIcon: Icons.library_music_rounded,
              label: modifyNgetlabel('library'.tr),
              selected: homeScreenController.tabIndex.value == 2,
            ),
            _navDest(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: modifyNgetlabel('settings'.tr),
              selected: homeScreenController.tabIndex.value == 3,
            ),
          ],
        ),
      ),
    );
  }

  NavigationDestination _navDest({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool selected,
  }) {
    return NavigationDestination(
      icon: Icon(icon, color: const Color(0xFFB3B3B3)),
      selectedIcon: Icon(selectedIcon, color: const Color(0xFFE0E0E0)),
      label: label,
    );
  }

  String modifyNgetlabel(String label) {
    if (label.length > 9) {
      return "${label.substring(0, 8)}..";
    }
    return label;
  }
}

