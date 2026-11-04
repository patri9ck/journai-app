// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const _messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
const _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
const _androidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
const _iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
const _iosBundleId = String.fromEnvironment('APP_ID');

FirebaseOptions? get firebaseOptions {
  final (apiKey, appId) = switch (defaultTargetPlatform) {
    TargetPlatform.android => (_androidApiKey, _androidAppId),
    TargetPlatform.iOS => (_iosApiKey, _iosAppId),
    _ => ('', ''),
  };

  if (apiKey.isEmpty || appId.isEmpty) {
    return null;
  }

  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: defaultTargetPlatform == TargetPlatform.iOS ? _iosBundleId : null,
  );
}
