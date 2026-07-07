import 'dart:ui' show ImageFilter;
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:widget_marquee/widget_marquee.dart';

import '/ui/player/components/animated_play_button.dart';
import '/ui/widgets/song_download_btn.dart';
import '../player_controller.dart';

class PlayerControlWidget extends StatelessWidget {
  const PlayerControlWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerController playerController = Get.find<PlayerController>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.35),
            border: Border.all(
              color: cs.outline.withOpacity(0.08),
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Title + Artist ──────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(() {
                          return Marquee(
                            delay: const Duration(milliseconds: 300),
                            duration: const Duration(seconds: 10),
                            id: "${playerController.currentSong.value}_title",
                            child: Text(
                              playerController.currentSong.value != null
                                  ? playerController.currentSong.value!.title
                                  : "NA",
                              style: tt.labelMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 2),
                        Obx(() {
                          return Marquee(
                            delay: const Duration(milliseconds: 300),
                            duration: const Duration(seconds: 10),
                            id: "${playerController.currentSong.value}_subtitle",
                            child: Text(
                              playerController.currentSong.value != null
                                  ? playerController.currentSong.value!.artist!
                                  : "NA",
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelSmall?.copyWith(
                                fontSize: 13,
                                color: cs.onSurface.withOpacity(0.55),
                                letterSpacing: -0.2,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Progress Bar ────────────────────────────────────────────
              GetX<PlayerController>(builder: (controller) {
                return ProgressBar(
                  thumbRadius: 6,
                  barHeight: 4,
                  baseBarColor: cs.outline.withOpacity(0.15),
                  bufferedBarColor: cs.outline.withOpacity(0.25),
                  progressBarColor: cs.primary,
                  thumbColor: cs.primary,
                  thumbGlowRadius: 12,
                  timeLabelLocation: TimeLabelLocation.sides,
                  timeLabelPadding: 4,
                  timeLabelTextStyle: tt.titleMedium?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                  progress: controller.progressBarStatus.value.current,
                  total: controller.progressBarStatus.value.total,
                  buffered: controller.progressBarStatus.value.buffered,
                  onSeek: controller.seek,
                );
              }),
              const SizedBox(height: 20),

              // ── Main Controls Row (prev, play, next) ────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ctrlBtn(
                    icon: Icons.skip_previous_rounded,
                    size: 28,
                    onPressed: () => playerController.prev(),
                    cs: cs,
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary.withOpacity(0.12),
                      border: Border.all(
                        color: cs.primary.withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.15),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: AnimatedPlayButton(
                      key: const Key("playButton"),
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _nextBtn(playerController, cs),
                ],
              ),
              const SizedBox(height: 18),

              // ── Secondary Controls Row (shuffle, fav, loop, download) ───
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Shuffle
                  Obx(() => _secBtn(
                        icon: Icons.shuffle_rounded,
                        active: playerController.isShuffleModeEnabled.value,
                        onPressed: playerController.toggleShuffleMode,
                        cs: cs,
                      )),
                  const SizedBox(width: 8),
              // Favorite
              Obx(() => _secBtn(
                    icon: playerController.isCurrentSongFav.isFalse
                        ? Icons.favorite_outline_rounded
                        : Icons.favorite_rounded,
                    customColor: playerController.isCurrentSongFav.isFalse
                        ? null
                        : Colors.redAccent,
                    active: playerController.isCurrentSongFav.value,
                    onPressed: playerController.toggleFavourite,
                    cs: cs,
                  )),
                  const SizedBox(width: 8),
                  // Loop
                  Obx(() => _secBtn(
                        icon: Icons.repeat_rounded,
                        active: playerController.isLoopModeEnabled.value,
                        onPressed: playerController.toggleLoopMode,
                        cs: cs,
                      )),
                  const SizedBox(width: 8),
                  // Download
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.outline.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                    child: SongDownloadButton(calledFromPlayer: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Control button helpers ──────────────────────────────────────────────────

/// Primary control button (prev/next) — circular, subtle bg on hover
Widget _ctrlBtn({
  required IconData icon,
  required double size,
  VoidCallback? onPressed,
  required ColorScheme cs,
}) {
  return IconButton(
    icon: Icon(icon, size: size),
    color: cs.onSurface,
    onPressed: onPressed,
    splashRadius: 22,
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    style: IconButton.styleFrom(
      backgroundColor: cs.surfaceContainerHighest.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  );
}

/// Secondary control button (shuffle/fav/loop) — compact, pill-shaped
Widget _secBtn({
  required IconData icon,
  required bool active,
  required VoidCallback onPressed,
  required ColorScheme cs,
  Color? customColor,
}) {
  final color = customColor ??
      (active ? cs.onSurface : cs.onSurface.withOpacity(0.4));
  return AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    decoration: BoxDecoration(
      color: active
          ? cs.primaryContainer.withOpacity(0.3)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: active
            ? cs.primary.withOpacity(0.2)
            : cs.outline.withOpacity(0.08),
        width: 0.5,
      ),
    ),
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      color: color,
      splashRadius: 18,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    ),
  );
}

Widget _nextBtn(PlayerController playerController, ColorScheme cs) {
  return Obx(() {
    final isLastSong = playerController.currentQueue.isEmpty ||
        (!(playerController.isShuffleModeEnabled.isTrue ||
                playerController.isQueueLoopModeEnabled.isTrue) &&
            (playerController.currentQueue.last.id ==
                playerController.currentSong.value?.id));
    return _ctrlBtn(
      icon: Icons.skip_next_rounded,
      size: 28,
      onPressed: isLastSong ? null : () => playerController.next(),
      cs: cs,
    );
  });
}
