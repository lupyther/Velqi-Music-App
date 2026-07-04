import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:velqi/ui/screens/Home/home_screen_controller.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final isLight = Theme.of(context).brightness == Brightness.light;
    // Theme-aware nav bar: pure black in dark, soft grey in light.
    final barBg = isLight ? const Color(0xFFF2F2F4) : Colors.black;
    final borderEdge = isLight ? const Color(0xFFE2E2E5) : const Color(0xFF1A1A1A);
    final iconUnselected =
        isLight ? const Color(0xFF8A8A8E) : const Color(0xFFB3B3B3);
    final iconSelected =
        isLight ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0);
    return Obx(
      () => Container(
        decoration: BoxDecoration(
          color: barBg,
          border: Border(
            top: BorderSide(
              color: borderEdge,
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
          indicatorColor: isLight ? Colors.black.withAlpha(12) : Colors.white12,
          labelBehavior:
              NavigationDestinationLabelBehavior.alwaysShow,
          animationDuration: const Duration(milliseconds: 400),
          destinations: [
            _navDest(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: modifyNgetlabel('home'.tr),
              selected: homeScreenController.tabIndex.value == 0,
              iconUnselected: iconUnselected,
              iconSelected: iconSelected,
            ),
            _navDest(
              icon: Icons.search_outlined,
              selectedIcon: Icons.search_rounded,
              label: modifyNgetlabel('search'.tr),
              selected: homeScreenController.tabIndex.value == 1,
              iconUnselected: iconUnselected,
              iconSelected: iconSelected,
            ),
            _navDest(
              icon: Icons.library_music_outlined,
              selectedIcon: Icons.library_music_rounded,
              label: modifyNgetlabel('library'.tr),
              selected: homeScreenController.tabIndex.value == 2,
              iconUnselected: iconUnselected,
              iconSelected: iconSelected,
            ),
            _navDest(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: modifyNgetlabel('settings'.tr),
              selected: homeScreenController.tabIndex.value == 3,
              iconUnselected: iconUnselected,
              iconSelected: iconSelected,
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
    required Color iconUnselected,
    required Color iconSelected,
  }) {
    return NavigationDestination(
      icon: Icon(icon, color: iconUnselected),
      selectedIcon: Icon(selectedIcon, color: iconSelected),
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

