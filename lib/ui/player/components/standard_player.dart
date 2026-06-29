import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/songinfo_bottom_sheet.dart';
import '../player_controller.dart';
import 'albumart_lyrics.dart';
import 'backgroud_image.dart';
import 'lyrics_switch.dart';
import 'player_control.dart';

class StandardPlayer extends StatelessWidget {
  const StandardPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final PlayerController playerController = Get.find<PlayerController>();
    final cs = Theme.of(context).colorScheme;
    final bottomPad = Get.mediaQuery.padding.bottom;

    // Reserve enough space for: top bar (~80) + controls area (~320) + bottom padding
    double playerArtImageSize = size.width - 60;
    final controlsEstimate = 310.0;
    final topBarEstimate = playerController.showLyricsflag.value ? 80.0 : 120.0;
    final lyricsSwitchHeight = 30.0;
    final reservedHeight =
        topBarEstimate + lyricsSwitchHeight + controlsEstimate + bottomPad + 60;
    final spaceAvailableForArtImage = size.height - reservedHeight;
    playerArtImageSize = playerArtImageSize > spaceAvailableForArtImage
        ? (spaceAvailableForArtImage > 100 ? spaceAvailableForArtImage : 100)
        : playerArtImageSize;

    return Stack(
      children: [
        BackgroudImage(
          key: Key("${playerController.currentSong.value?.id}_background"),
          cacheHeight: 480,
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surface.withOpacity(0.85),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 65 + bottomPad + 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.surface,
                        cs.surface,
                        cs.surface.withOpacity(0.4),
                        cs.surface.withOpacity(0),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0, 0.5, 0.8, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: context.isLandscape
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: size.width * .45,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 90),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: AlbumArtNLyrics(
                              playerArtImageSize: size.width * .29,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: size.width * .48,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 10,
                          bottom: bottomPad,
                        ),
                        child: const PlayerControlWidget(),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Obx(
                      () => playerController.showLyricsflag.value
                          ? SizedBox(height: size.height < 750 ? 60 : 80)
                          : SizedBox(height: size.height < 750 ? 90 : 110),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const LyricsSwitch(),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: AlbumArtNLyrics(
                            playerArtImageSize: playerArtImageSize,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: 60 + bottomPad,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: const PlayerControlWidget(),
                      ),
                    ),
                  ],
                ),
        ),
        if (!(context.isLandscape && GetPlatform.isMobile))
          Padding(
            padding: EdgeInsets.only(
              top: Get.mediaQuery.padding.top + 12,
              left: 4,
              right: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 26),
                  onPressed: playerController.playerPanelController.close,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6.0, left: 5, right: 5),
                    child: Obx(
                      () => Column(
                        children: [
                          Text(
                            playerController.playinfrom.value.typeString,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withAlpha(140),
                            ),
                          ),
                          Obx(
                            () => Text(
                              "\"${playerController.playinfrom.value.nameString}\"",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: cs.onSurface.withAlpha(200),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 22),
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () {
                    showModalBottomSheet(
                      constraints: const BoxConstraints(maxWidth: 500),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(10.0)),
                      ),
                      isScrollControlled: true,
                      context: playerController
                          .homeScaffoldkey.currentState!.context,
                      barrierColor: Colors.transparent.withAlpha(100),
                      builder: (context) => SongInfoBottomSheet(
                        playerController.currentSong.value!,
                        calledFromPlayer: true,
                      ),
                    ).whenComplete(() => Get.delete<SongInfoController>());
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
