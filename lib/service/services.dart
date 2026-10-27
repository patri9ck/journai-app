// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import '../util/storage.dart';
import 'apple_account_service.dart';
import 'overpass_service.dart';
import 'consent_service.dart';
import 'contact_service.dart';
import 'cryptography_service.dart';
import 'currency_service.dart';
import 'data_service.dart';
import 'emergency_card_widget_service.dart';
import 'encryption_service.dart';
import 'entry_check_service.dart';
import 'geocoding_service.dart';
import 'google_account_service.dart';
import 'limits_service.dart';
import 'login_service.dart';
import 'notification_service.dart';
import 'sound_service.dart';
import 'push_notification_service.dart';
import 'request_service.dart';
import 'subscription_service.dart';
import 'translation_service.dart';
import 'travel_warning_alert_service.dart';
import 'travel_warning_service.dart';
import 'weather_service.dart';

const baseUrl = String.fromEnvironment('BASE_URL');
const appId = String.fromEnvironment('APP_ID');
const _contactEmail = String.fromEnvironment('CONTACT_EMAIL');
const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const _revenueCatGoogleApiKey = String.fromEnvironment('REVENUE_CAT_GOOGLE_API_KEY');
const _revenueCatAppleApiKey = String.fromEnvironment('REVENUE_CAT_APPLE_API_KEY');

final requestService = RequestService(baseUrl: baseUrl);
final cryptographyService = CryptographyService();
final appleAccountService = AppleAccountService();
final googleAccountService = GoogleAccountService(serverClientId: _googleWebClientId);
final loginService = LoginService(
  requestService: requestService,
  cryptographyService: cryptographyService,
  googleAccountService: googleAccountService,
  appleAccountService: appleAccountService,
);
final encryptionService = EncryptionService(
  requestService: requestService,
  cryptographyService: cryptographyService,
);
final dataService = DataService(
  requestService: requestService,
  cryptographyService: cryptographyService,
);
final consentService = ConsentService(requestService: requestService);
final limitsService = LimitsService(requestService: requestService);
final entryCheckService = EntryCheckService(requestService: requestService);
final contactService = ContactService(requestService: requestService);
final weatherService = WeatherService();
final geocodingService = GeocodingService(contactEmail: _contactEmail);
final travelWarningService = TravelWarningService();
final travelWarningAlertService = TravelWarningAlertService();
final overpassService = OverpassService(contactEmail: _contactEmail);
final translationService = TranslationService();
final currencyService = CurrencyService();
final notificationService = NotificationService();
final emergencyCardWidgetService = EmergencyCardWidgetService();
final pushNotificationService = PushNotificationService();
final soundService = SoundService();
final subscriptionService = SubscriptionService(
  googleApiKey: _revenueCatGoogleApiKey,
  appleApiKey: _revenueCatAppleApiKey,
  requestService: requestService,
);

Future<void> clearAccount() async {
  await travelWarningAlertService.clear();
  await emergencyCardWidgetService.clear();
  await notificationService.clear();
  await clearSession();
}
