import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '/native_bindings/andrid_utils.dart' show SDKInt;

class PermissionService {
  static Future<bool> getExtStoragePermission() async {
    if (GetPlatform.isDesktop) {
      return Future.value(true);
    }
    if ((SDKInt.Companion.getSDKInt()) < 30) {
      var status = await Permission.storage.status;
      if (status.isDenied) {
        await [
          Permission.storage,
          Permission.accessMediaLocation,
          Permission.mediaLibrary,
        ].request();
      }

      if (await Permission.storage.isPermanentlyDenied) {
        await openAppSettings();
      }

      return (await Permission.storage.status).isGranted;
    } else {
      // Android 11+ (SDK 30+): MANAGE_EXTERNAL_STORAGE
      // This permission CANNOT be requested via normal dialog on Android 11+.
      // The permission_handler .request() silently returns denied.
      // We must open the system settings page directly.
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      // Try requesting via permission_handler first (may work on some devices)
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) return true;

      // If denied/permanently denied, open the "All files access" settings page
      if (Platform.isAndroid) {
        const channel = MethodChannel('com.velqi.app/storage_settings');
        try {
          await channel.invokeMethod('openStorageSettings');
        } catch (_) {
          // Fallback: open generic app settings
          await openAppSettings();
        }
        // IMPORTANT: Don't check permission immediately after opening settings!
        // The user hasn't had a chance to grant it yet.
        // Return false and let the caller guide the user.
      }
      return false;
    }
  }

  static Future<bool> getNotificationPermission() async {
    if (GetPlatform.isDesktop) {
      return Future.value(true);
    }
    if ((SDKInt.Companion.getSDKInt()) >= 33) {
      var status = await Permission.notification.status;
      if (status.isDenied) {
        status = await Permission.notification.request();
      }
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      return status.isGranted;
    }
    return true;
  }
}
