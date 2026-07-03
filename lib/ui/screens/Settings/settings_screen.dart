import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:velqi/utils/helper.dart';
import 'package:velqi/utils/lang_mapping.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/common_dialog_widget.dart';
import '../../widgets/cust_switch.dart';
import '../../widgets/export_file_dialog.dart';
import '../../widgets/backup_dialog.dart';
import '../../widgets/restore_dialog.dart';
import '../../widgets/snackbar.dart';
import '/services/music_service.dart';
import '/ui/player/player_controller.dart';
import '/ui/utils/theme_controller.dart';
import 'components/custom_expansion_tile.dart';
import 'settings_screen_controller.dart';

// ── Shared helpers ──────────────────────────────────────────────────────────

Widget _settingsDropdown(ThemeData theme, Widget child) {
  final cs = theme.colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: cs.outline.withAlpha(60), width: 1),
    ),
    child: child,
  );
}

Widget _settingsOutlinedButton(BuildContext context, String label,
    {VoidCallback? onPressed}) {
  final cs = Theme.of(context).colorScheme;
  return OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: cs.outline.withAlpha(100), width: 1.2),
      foregroundColor: cs.onSurface,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(label,
        style:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
  );
}

/// Wraps a ListTile in a bordered container matching the app's design system.
Widget _borderedTile({
  required BuildContext context,
  required Widget title,
  Widget? subtitle,
  Widget? trailing,
  VoidCallback? onTap,
  bool isThreeLine = false,
}) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: cs.outline.withAlpha(25), width: 1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.only(left: 10, right: 12),
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      isThreeLine: isThreeLine,
      visualDensity: const VisualDensity(vertical: -2),
    ),
  );
}

// ── Main Settings screen ────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.isBottomNavActive = false});
  final bool isBottomNavActive;

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsScreenController>();
    final topPadding = context.isLandscape ? 50.0 : 90.0;
    final isDesktop = GetPlatform.isDesktop;
    return Padding(
      padding: isBottomNavActive
          ? const EdgeInsets.only(left: 20, top: 90, right: 15)
          : EdgeInsets.only(top: topPadding, left: 5, right: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "settings".tr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 200),
              children: [
                // ── New version banner ──────────────────────────────────────
                Obx(
                  () => settingsController.isNewVersionAvailable.value
                      ? Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            onTap: () {
                              launchUrl(
                                Uri.parse(
                                  'https://github.com/lupyther/Velqi-Music-App/releases/latest',
                                ),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            contentPadding:
                                const EdgeInsets.only(left: 8, right: 10),
                            leading: const CircleAvatar(
                                child: Icon(Icons.download)),
                            title: Text("newVersionAvailable".tr),
                            visualDensity:
                                const VisualDensity(horizontal: -2),
                            subtitle: Text(
                              "goToDownloadPage".tr,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(
                                      color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // ── Music & Playback ────────────────────────────────────────
                CustomExpansionTile(
                  title: "music&Playback".tr,
                  icon: Icons.music_note,
                  children: [
                    _borderedTile(
                      context: context,
                      title: Text("streamingQuality".tr),
                      subtitle: Text("streamingQualityDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => _settingsDropdown(
                          Theme.of(context),
                          DropdownButton(
                            dropdownColor: Theme.of(context).cardColor,
                            underline: const SizedBox.shrink(),
                            value:
                                settingsController.streamingQuality.value,
                            items: [
                              DropdownMenuItem(
                                  value: AudioQuality.Low,
                                  child: Text("low".tr)),
                              DropdownMenuItem(
                                value: AudioQuality.High,
                                child: Text("high".tr),
                              ),
                            ],
                            onChanged:
                                settingsController.setStreamingQuality,
                          ),
                        ),
                      ),
                    ),
                    if (!isDesktop)
                      _borderedTile(
                        context: context,
                        title: Text("cacheSongs".tr),
                        subtitle: Text("cacheSongsDes".tr,
                            style: Theme.of(context).textTheme.bodyMedium),
                        trailing: Obx(
                          () => CustSwitch(
                              value: settingsController.cacheSongs.value,
                              onChanged:
                                  settingsController.toggleCachingSongsValue),
                        ),
                      ),
                    if (isDesktop)
                      _borderedTile(
                        context: context,
                        title: Text("backgroundPlay".tr),
                        subtitle: Text("backgroundPlayDes".tr,
                            style: Theme.of(context).textTheme.bodyMedium),
                        trailing: Obx(
                          () => CustSwitch(
                              value: settingsController
                                  .backgroundPlayEnabled.value,
                              onChanged:
                                  settingsController.toggleBackgroundPlay),
                        ),
                      ),
                    _borderedTile(
                      context: context,
                      title: Text("keepScreenOnWhilePlaying".tr),
                      subtitle: Text("keepScreenOnWhilePlayingDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => CustSwitch(
                            value: settingsController.keepScreenAwake.value,
                            onChanged:
                                settingsController.toggleKeepScreenAwake),
                      ),
                    ),
                    _borderedTile(
                      context: context,
                      title: Text("restoreLastPlaybackSession".tr),
                      subtitle: Text("restoreLastPlaybackSessionDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => CustSwitch(
                            value: settingsController
                                .restorePlaybackSession.value,
                            onChanged: settingsController
                                .toggleRestorePlaybackSession),
                      ),
                    ),
                    _borderedTile(
                      context: context,
                      title: Text("autoOpenPlayer".tr),
                      subtitle: Text("autoOpenPlayerDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => CustSwitch(
                            value: settingsController.autoOpenPlayer.value,
                            onChanged:
                                settingsController.toggleAutoOpenPlayer),
                      ),
                    ),
                    if (!isDesktop)
                      _borderedTile(
                        context: context,
                        title: Text("equalizer".tr),
                        subtitle: Text("equalizerDes".tr,
                            style: Theme.of(context).textTheme.bodyMedium),
                        onTap: () async {
                          try {
                            await Get.find<PlayerController>()
                                .openEqualizer();
                          } catch (e) {
                            printERROR(e);
                          }
                        },
                      ),
                  ],
                ),

                // ── Content ─────────────────────────────────────────────────
                CustomExpansionTile(
                  title: "content".tr,
                  icon: Icons.music_video,
                  children: [
                    _borderedTile(
                      context: context,
                      title: Text("homeContentCount".tr),
                      subtitle: Text("homeContentCountDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => _settingsDropdown(
                          Theme.of(context),
                          DropdownButton(
                            dropdownColor: Theme.of(context).cardColor,
                            underline: const SizedBox.shrink(),
                            value: settingsController
                                .noOfHomeScreenContent.value,
                            items: ([3, 5, 7, 9, 11])
                                .map((e) => DropdownMenuItem(
                                    value: e, child: Text("$e")))
                                .toList(),
                            onChanged:
                                settingsController.setContentNumber,
                          ),
                        ),
                      ),
                    ),
                    _borderedTile(
                      context: context,
                      title: Text("cacheHomeScreenData".tr),
                      subtitle: Text("cacheHomeScreenDataDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => CustSwitch(
                            value: settingsController
                                .cacheHomeScreenData.value,
                            onChanged: settingsController
                                .toggleCacheHomeScreenData),
                      ),
                    ),
                    _borderedTile(
                      context: context,
                      title: Text("clearImgCache".tr),
                      subtitle: Text("clearImgCacheDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      isThreeLine: true,
                      onTap: () {
                        settingsController.clearImagesCache().then((_) =>
                            ScaffoldMessenger.of(Get.context!).showSnackBar(
                                snackbar(Get.context!,
                                    "clearImgCacheAlert".tr,
                                    size: SanckBarSize.BIG)));
                      },
                    ),
                  ],
                ),

                // ── Personalisation ─────────────────────────────────────────
                CustomExpansionTile(
                  title: "personalisation".tr,
                  icon: Icons.palette,
                  children: [
                    _borderedTile(
                      context: context,
                      title: Text("Tema oscuro"),
                      subtitle: Text("Cambia entre tema oscuro y claro",
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => CustSwitch(
                            value: settingsController.themeModetype.value == ThemeType.dark,
                            onChanged: (val) {
                              settingsController.onThemeChange(
                                  val ? ThemeType.dark : ThemeType.light);
                            }),
                      ),
                    ),
                    _borderedTile(
                      context: context,
                      title: Text("language".tr),
                      subtitle: Text("languageDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => _settingsDropdown(
                          Theme.of(context),
                          DropdownButton(
                            menuMaxHeight: Get.height - 250,
                            dropdownColor: Theme.of(context).cardColor,
                            underline: const SizedBox.shrink(),
                            style:
                                Theme.of(context).textTheme.titleSmall,
                            value: settingsController
                                .currentAppLanguageCode.value,
                            items: langMap.entries
                                .map((lang) => DropdownMenuItem(
                                      value: lang.key,
                                      child: Text(lang.value),
                                    ))
                                .whereType<DropdownMenuItem<String>>()
                                .toList(),
                            selectedItemBuilder: (context) =>
                                langMap.entries.map<Widget>((item) {
                              return Container(
                                alignment: Alignment.centerRight,
                                constraints:
                                    const BoxConstraints(minWidth: 50),
                                child: Text(item.value),
                              );
                            }).toList(),
                            onChanged:
                                settingsController.setAppLanguage,
                          ),
                        ),
                      ),
                    ),
                    _borderedTile(
                      context: context,
                      title: Text("disableTransitionAnimation".tr),
                      subtitle: Text("disableTransitionAnimationDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => CustSwitch(
                            value: settingsController
                                .isTransitionAnimationDisabled.isTrue,
                            onChanged: settingsController
                                .disableTransitionAnimation),
                      ),
                    ),
                    _borderedTile(
                      context: context,
                      title: Text("enableSlidableAction".tr),
                      subtitle: Text("enableSlidableActionDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => CustSwitch(
                            value: settingsController
                                .slidableActionEnabled.isTrue,
                            onChanged:
                                settingsController.toggleSlidableAction),
                      ),
                    ),
                  ],
                ),

                // ── Download ────────────────────────────────────────────────
                CustomExpansionTile(
                  title: "download".tr,
                  icon: Icons.download,
                  children: [
                    _borderedTile(
                      context: context,
                      title: Text("autoDownFavSong".tr),
                      subtitle: Text("autoDownFavSongDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => CustSwitch(
                            value: settingsController
                                .autoDownloadFavoriteSongEnabled.value,
                            onChanged: settingsController
                                .toggleAutoDownloadFavoriteSong),
                      ),
                    ),
                    _borderedTile(
                      context: context,
                      title: Text("downloadingFormat".tr),
                      subtitle: Text("downloadingFormatDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      trailing: Obx(
                        () => _settingsDropdown(
                          Theme.of(context),
                          DropdownButton(
                            dropdownColor: Theme.of(context).cardColor,
                            underline: const SizedBox.shrink(),
                            value:
                                settingsController.downloadingFormat.value,
                            items: const [
                              DropdownMenuItem(
                                  value: "opus",
                                  child: Text("Opus/Ogg")),
                              DropdownMenuItem(
                                value: "m4a",
                                child: Text("M4a"),
                              ),
                            ],
                            onChanged: settingsController
                                .changeDownloadingFormat,
                          ),
                        ),
                      ),
                    ),
                    _borderedTile(
                      context: context,
                      title: Text("downloadLocation".tr),
                      subtitle: Obx(() => Text(
                          settingsController.isCurrentPathsupportDownDir
                              ? "In App storage directory"
                              : settingsController
                                  .downloadLocationPath.value,
                          style:
                              Theme.of(context).textTheme.bodyMedium)),
                      trailing: _settingsOutlinedButton(
                        context,
                        "reset".tr,
                        onPressed: () {
                          settingsController.resetDownloadLocation();
                        },
                      ),
                      onTap: () async {
                        settingsController.setDownloadLocation();
                      },
                    ),
                  ],
                ),

                // ── Backup & Restore ────────────────────────────────────────
                CustomExpansionTile(
                  title: "${"backup".tr} & ${"restore".tr}",
                  icon: Icons.restore,
                  children: [
                    _borderedTile(
                      context: context,
                      title: Text("backupAppData".tr),
                      subtitle: Text("backupSettingsAndPlaylistsDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      isThreeLine: true,
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) => const BackupDialog(),
                      ).whenComplete(
                          () => Get.delete<BackupDialogController>()),
                    ),
                    _borderedTile(
                      context: context,
                      title: Text("restoreAppData".tr),
                      subtitle: Text("restoreSettingsAndPlaylistsDes".tr,
                          style: Theme.of(context).textTheme.bodyMedium),
                      isThreeLine: true,
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) => const RestoreDialog(),
                      ).whenComplete(
                          () => Get.delete<RestoreDialogController>()),
                    ),
                  ],
                ),

                // ── Advanced ────────────────────────────────────────────────
                CustomExpansionTile(
                  title: "advanced".tr,
                  icon: Icons.tune,
                  children: [
                    if (GetPlatform.isAndroid)
                      _borderedTile(
                        context: context,
                        title: Text("loudnessNormalization".tr),
                        subtitle: Text("loudnessNormalizationDes".tr,
                            style:
                                Theme.of(context).textTheme.bodyMedium),
                        trailing: Obx(
                          () => CustSwitch(
                              value: settingsController
                                  .loudnessNormalizationEnabled.value,
                              onChanged: settingsController
                                  .toggleLoudnessNormalization),
                        ),
                      ),
                    if (!isDesktop)
                      _borderedTile(
                        context: context,
                        title: Text("skipSilence".tr),
                        subtitle: Text("skipSilenceDes".tr,
                            style:
                                Theme.of(context).textTheme.bodyMedium),
                        trailing: Obx(
                          () => CustSwitch(
                              value: settingsController
                                  .skipSilenceEnabled.value,
                              onChanged:
                                  settingsController.toggleSkipSilence),
                        ),
                      ),
                    _borderedTile(
                      context: context,
                      title: const Text("⚡ Modo Rápido"),
                      subtitle: Text(
                        "Baja calidad + timeouts cortos. Ideal para conexiones lentas o evitar cortes al saltar canciones rápido.",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      isThreeLine: true,
                      trailing: Obx(
                        () => CustSwitch(
                          value: settingsController.fastMode.value,
                          onChanged: settingsController.toggleFastMode,
                        ),
                      ),
                    ),
                    if (!isDesktop)
                      _borderedTile(
                        context: context,
                        title: Text("stopMusicOnTaskClear".tr),
                        subtitle: Text("stopMusicOnTaskClearDes".tr,
                            style:
                                Theme.of(context).textTheme.bodyMedium),
                        trailing: Obx(
                          () => CustSwitch(
                              value: settingsController
                                  .stopPlyabackOnSwipeAway.value,
                              onChanged: settingsController
                                  .toggleStopPlyabackOnSwipeAway),
                        ),
                      ),
                    if (GetPlatform.isAndroid)
                      Obx(
                        () => _borderedTile(
                          context: context,
                          title: Text("ignoreBatOpt".tr),
                          onTap: settingsController
                                  .isIgnoringBatteryOptimizations.isFalse
                              ? settingsController
                                  .enableIgnoringBatteryOptimizations
                              : null,
                          subtitle: RichText(
                            text: TextSpan(
                              text:
                                  "${"status".tr}: ${settingsController.isIgnoringBatteryOptimizations.isTrue ? "enabled".tr : "disabled".tr}\n",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(
                                      fontWeight: FontWeight.bold),
                              children: <TextSpan>[
                                TextSpan(
                                    text: "ignoreBatOptDes".tr,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium),
                              ],
                            ),
                          ),
                        ),
                      ),
                    _borderedTile(
                      context: context,
                      title: Text("exportDowloadedFiles".tr),
                      subtitle: Text("exportDowloadedFilesDes".tr,
                          style:
                              Theme.of(context).textTheme.bodyMedium),
                      isThreeLine: true,
                      onTap: () => showDialog(
                        context: context,
                        builder: (context) =>
                            const ExportFileDialog(),
                      ).whenComplete(
                          () => Get.delete<
                                  ExportFileDialogController>()),
                    ),
                    _borderedTile(
                      context: context,
                      title: Text("exportedFileLocation".tr),
                      subtitle: Obx(() => Text(
                          settingsController
                              .exportLocationPath.value,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium)),
                      onTap: () async {
                        settingsController.setExportedLocation();
                      },
                    ),
                    // ── Cookies de YouTube ──────────────────────────────────
                    if (!isDesktop)
                      Obx(() {
                        final isUser = settingsController.cookiesSource.value == "user";
                        final active = settingsController.cookiesActive.value;
                        return _borderedTile(
                          context: context,
                          title: const Text("Cookies de YouTube"),
                          subtitle: Text(
                            active
                                ? (isUser
                                    ? "Cookies personalizadas activas"
                                    : "Cookies integradas activas")
                                : "Sin cookies configuradas",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.green.withAlpha(40)
                                  : Colors.grey.withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              active
                                  ? (isUser ? "Custom" : "Sistema")
                                  : "Inactivas",
                              style: TextStyle(
                                color: active
                                    ? Colors.green
                                    : Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => const _CookiesDialog(),
                          ),
                        );
                      }),
                  ],
                ),

                // ── Misc ────────────────────────────────────────────────────
                CustomExpansionTile(
                  icon: Icons.miscellaneous_services,
                  title: "misc".tr,
                  children: [
                    _borderedTile(
                      context: context,
                      title: Text("resetToDefault".tr),
                      subtitle: Text("resetToDefaultDes".tr,
                          style:
                              Theme.of(context).textTheme.bodyMedium),
                      onTap: () {
                        settingsController
                            .resetAppSettingsToDefault()
                            .then((_) {
                          ScaffoldMessenger.of(Get.context!)
                              .showSnackBar(snackbar(Get.context!,
                                  "resetToDefaultMsg".tr,
                                  size: SanckBarSize.BIG,
                                  duration:
                                      const Duration(seconds: 2)));
                        });
                      },
                    ),
                  ],
                ),

                // ── App Info ────────────────────────────────────────────────
                CustomExpansionTile(
                  icon: Icons.info,
                  title: "appInfo".tr,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/velqi.png',
                              width: 140,
                              height: 140,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Velqi ${settingsController.currentVersion}",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "by @lupyther",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  letterSpacing: 0.3,
                                ),
                          ),

                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Theme Selector Dialog ────────────────────────────────────────────────────

class ThemeSelectorDialog extends StatelessWidget {
  const ThemeSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsScreenController>();
    return CommonDialog(
      child: Container(
        height: 300,
        padding:
            const EdgeInsets.only(top: 30, left: 5, right: 30, bottom: 10),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(left: 20.0, bottom: 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "themeMode".tr,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          radioWidget(
            label: "dynamic".tr,
            controller: settingsController,
            value: ThemeType.dynamic,
          ),
          radioWidget(
              label: "systemDefault".tr,
              controller: settingsController,
              value: ThemeType.system),
          radioWidget(
              label: "dark".tr,
              controller: settingsController,
              value: ThemeType.dark),
          radioWidget(
              label: "light".tr,
              controller: settingsController,
              value: ThemeType.light),
          Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("cancel".tr),
                ),
                onTap: () => Navigator.of(context).pop(),
              ))
        ]),
      ),
    );
  }
}

// ── Shared radio widget (used by ThemeSelectorDialog) ──────────────────────

Widget radioWidget({
  required String label,
  required SettingsScreenController controller,
  required value,
}) {
  return Obx(() => ListTile(
        visualDensity: const VisualDensity(vertical: -4),
        onTap: () {
          controller.onThemeChange(value);
        },
        leading: Radio(
            value: value,
            groupValue: controller.themeModetype.value,
            onChanged: controller.onThemeChange),
        title: Text(label),
      ));
}

// ── Cookies Dialog ────────────────────────────────────────────────────────────

class _CookiesDialog extends StatefulWidget {
  const _CookiesDialog();
  @override
  State<_CookiesDialog> createState() => _CookiesDialogState();
}

class _CookiesDialogState extends State<_CookiesDialog> {
  late final TextEditingController _tc;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final saved =
        Hive.box("AppPrefs").get('userCookiesContent') as String? ?? '';
    _tc = TextEditingController(text: saved);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sc = Get.find<SettingsScreenController>();
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text("Cookies de YouTube"),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withAlpha(120),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "¿Cómo obtener las cookies?",
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "💻 En PC (recomendado):",
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      "1. Inicia sesión en youtube.com con Chrome\n"
                      "2. Instala la extensión 'Get cookies.txt LOCALLY'\n"
                      "3. Haz clic en la extensión → Exportar cookies\n"
                      "4. Abre el archivo descargado, selecciona todo y cópialo\n"
                      "5. Pégalo en el campo de abajo y pulsa Aplicar",
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "📱 En Android:",
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      "1. Descarga Kiwi Browser (soporta extensiones)\n"
                      "2. Instala 'Get cookies.txt LOCALLY' desde la web store\n"
                      "3. Abre music.youtube.com e inicia sesión\n"
                      "4. Pulsa la extensión → Exportar → copia el contenido",
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tc,
                maxLines: 7,
                style: const TextStyle(fontSize: 11),
                decoration: InputDecoration(
                  hintText:
                      "# Netscape HTTP Cookie File\n.youtube.com\tTRUE\t/ ...",
                  hintStyle:
                      TextStyle(color: cs.onSurface.withAlpha(80), fontSize: 11),
                  border: const OutlineInputBorder(),
                  labelText: "Pega aquí el contenido de cookies.txt",
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await sc.clearCookies();
                  _tc.clear();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(snackbar(
                        context, "Cookies eliminadas. Se usan las integradas.",
                        size: SanckBarSize.BIG));
                    Navigator.of(context).pop();
                  }
                },
          child: const Text("Limpiar"),
        ),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  final content = _tc.text.trim();
                  if (content.isEmpty) return;
                  setState(() => _saving = true);
                  await sc.saveCookies(content);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(snackbar(
                        context, "Cookies aplicadas correctamente.",
                        size: SanckBarSize.BIG));
                    Navigator.of(context).pop();
                  }
                },
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Aplicar"),
        ),
      ],
    );
  }
}
