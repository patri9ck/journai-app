// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../messages/app_localizations.dart';
import '../../model/country_content.dart';
import '../../model/data.dart';
import '../../model/emergency/emergency_card_content.dart';
import '../../model/emergency/emergency_card_translation.dart';
import '../../model/emergency/emergency_numbers.dart';
import '../../model/limits.dart';
import '../../model/trip.dart';
import '../../model/location_info.dart';
import '../../model/result.dart';
import '../../service/currency_service.dart';
import '../../service/services.dart';
import '../../service/translation_service.dart';
import '../../service/travel_warning_service.dart';
import '../../util/auth_scope.dart';
import '../../util/cache.dart';
import '../../util/country_data.dart';
import '../../util/country_name.dart';
import '../../util/emergency_card_notifier.dart';
import '../../util/profile_notifier.dart';
import '../../util/storage.dart';
import '../../util/temperature_format.dart';
import '../../util/units_notifier.dart';
import '../shared/emergency_card_view.dart';
import '../shared/share_image.dart';
import '../shared/sheet_handle.dart';
import '../shared/status_row.dart';
import '../shared/tier_badge.dart';
import '../sheet/encryption_sheet.dart';
import 'memories_page.dart';
import 'full_map_page.dart';

class DashboardPage extends StatefulWidget {
  final int refreshTrigger;

  const DashboardPage({super.key, this.refreshTrigger = 0});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  bool _isLocating = true;
  static const _positionCacheKey = 'cache_last_position';

  LatLng? _position;
  LocationInfo? _locationInfo;
  bool _locationPermissionDenied = false;
  double? _temperature;

  bool get _metricUnits => metricUnitsNotifier.value;

  List<Data> _healthData = [];
  bool _healthDataLoaded = false;
  bool _limitsLoaded = false;
  String? _profileName;

  Limits _limits = Limits.unlimited;

  String _homeCurrency = 'EUR';
  String? _awayCurrency;
  Map<String, double>? _exchangeRates;
  bool _ratesLoading = false;
  bool _ratesOffline = false;
  DateTime? _ratesFetchedAt;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadHealthData();
    _loadLimits();
    _refreshRates(_homeCurrency);
    metricUnitsNotifier.addListener(_onUnitsChanged);
    selectedProfileNotifier.addListener(_loadHealthData);
    emergencyCardRequestedNotifier.addListener(_onEmergencyCardRequested);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onEmergencyCardRequested());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    metricUnitsNotifier.removeListener(_onUnitsChanged);
    selectedProfileNotifier.removeListener(_loadHealthData);
    emergencyCardRequestedNotifier.removeListener(_onEmergencyCardRequested);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _healthDataLoaded) {
      emergencyCardWidgetService.update(_healthData, metricUnits: _metricUnits);
    }
  }

  void _onUnitsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _loadHealthData();
      _loadLimits();
    }
  }

  Future<void> _refreshRates(String homeCurrency) async {
    if (_ratesLoading) {
      return;
    }

    setState(() => _ratesLoading = true);

    final cached = await currencyService.getCachedRates(homeCurrency);
    final cachedAge = await currencyService.getCacheAge(homeCurrency);

    if (!mounted) {
      return;
    }

    if (cached != null) {
      setState(() {
        _exchangeRates = cached;
        _ratesFetchedAt = cachedAge;
        _ratesOffline = false;
      });
    }

    final fresh = await currencyService.fetchRates(homeCurrency);

    if (!mounted) {
      return;
    }

    if (fresh != null) {
      final newFetchedAt = await currencyService.getCacheAge(homeCurrency);

      setState(() {
        _exchangeRates = fresh;
        _ratesFetchedAt = newFetchedAt;
        _ratesLoading = false;
        _ratesOffline = false;
      });
    } else {
      setState(() {
        _ratesLoading = false;
        _ratesOffline = cached == null;
      });
    }
  }

  Future<void> _loadLimits() async {
    final cachedLimits = await limitsService.getCachedLimits();

    if (!mounted) {
      return;
    }

    setState(() => _limits = cachedLimits);

    final freshLimits = await limitsService.getLimits();

    if (!mounted) {
      return;
    }

    setState(() {
      _limits = freshLimits;
      _limitsLoaded = true;
    });

    if (!freshLimits.hasProfiles && selectedProfileNotifier.value != null) {
      await selectProfile(null);
    }

    await travelWarningAlertService.sync(freshLimits.travelWarningAlertsEnabled);
  }

  Future<void> _initLocation() async {
    final cachedLocation = await geocodingService.getCachedLocation();
    final cachedPosition = await readObjectCache(_positionCacheKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _locationInfo = cachedLocation ?? _locationInfo;
      _position = _toLatLng(cachedPosition) ?? _position;
      _isLocating = _isLocating && cachedLocation == null;
    });

    if (cachedLocation != null) {
      _updateCurrencyFromLocation(cachedLocation);
    }

    final position = await _currentPosition();

    if (!mounted) {
      return;
    }

    setState(() {
      _position = position ?? _position;
      _isLocating = false;
    });

    if (position == null) {
      return;
    }

    await saveObjectCache(_positionCacheKey, {'lat': position.latitude, 'lon': position.longitude});

    final results = await Future.wait([
      weatherService.getCurrentTemperature(position.latitude, position.longitude),
      geocodingService.reverseGeocode(position.latitude, position.longitude),
    ]);

    if (!mounted) {
      return;
    }

    final locationInfo = results[1] as LocationInfo?;

    setState(() {
      _temperature = results[0] as double?;
      _locationInfo = locationInfo ?? _locationInfo;
    });

    if (locationInfo != null) {
      _updateCurrencyFromLocation(locationInfo);
    }
  }

  Future<LatLng?> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return null;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() => _locationPermissionDenied = true);
      }

      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );

      return LatLng(position.latitude, position.longitude);
    } on TimeoutException {
      final lastKnown = await Geolocator.getLastKnownPosition();

      return lastKnown == null ? null : LatLng(lastKnown.latitude, lastKnown.longitude);
    } on LocationServiceDisabledException {
      return null;
    } on PermissionDeniedException {
      return null;
    }
  }

  LatLng? _toLatLng(Map<String, dynamic>? cachedPosition) {
    final latitude = (cachedPosition?['lat'] as num?)?.toDouble();
    final longitude = (cachedPosition?['lon'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  void _updateCurrencyFromLocation(LocationInfo locationInfo) {
    final detectedCurrency = CurrencyService.countryToCurrency[locationInfo.countryCode];

    if (detectedCurrency == null) {
      return;
    }

    if (detectedCurrency == _homeCurrency) {
      if (_awayCurrency == null) {
        setState(() => _awayCurrency = _homeCurrency == 'USD' ? 'EUR' : 'USD');
      }
      return;
    }

    setState(() => _awayCurrency = detectedCurrency);
  }

  Future<void> _loadHealthData() async {
    final cachedData = await dataService.getCachedData();
    final profileName = await _selectedProfileName();

    if (!mounted) {
      return;
    }

    setState(() {
      _healthData = cachedData;
      _healthDataLoaded = true;
      _profileName = profileName;
    });

    if (cachedData.isNotEmpty) {
      emergencyCardWidgetService.update(cachedData, metricUnits: _metricUnits);
    }

    final freshResult = await dataService.getData();

    if (!mounted) {
      return;
    }

    if (freshResult is Success<List<Data>>) {
      final freshData = freshResult.value ?? [];

      setState(() {
        _healthData = freshData;
        _healthDataLoaded = true;
      });

      final allProfilesData = await dataService.getCachedDataOfAllProfiles();

      notificationService.scheduleNotifications(allProfilesData);
      emergencyCardWidgetService.update(freshData, metricUnits: _metricUnits);
      await _syncTripAlerts(allProfilesData);
    } else {
      setState(() => _healthDataLoaded = true);
    }
  }

  void _onEmergencyCardRequested() {
    if (!emergencyCardRequestedNotifier.value || !mounted) {
      return;
    }

    emergencyCardRequestedNotifier.value = false;
    _openEmergencyCard(context);
  }

  Future<void> _syncTripAlerts(List<Data> allProfilesData) async {
    final upcomingTrips = Trip.fromDataList(allProfilesData).where((trip) => !trip.isOver(_today()));

    await travelWarningAlertService.setTripCountries([
      for (final trip in upcomingTrips) ?iso2ToIso3[trip.countryCode],
    ]);

    if (_limitsLoaded) {
      await travelWarningAlertService.sync(_limits.travelWarningAlertsEnabled);
    }
  }

  DateTime _today() {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  Future<String?> _selectedProfileName() async {
    final profileId = selectedProfileNotifier.value;

    if (profileId == null) {
      return null;
    }

    final profiles = await dataService.getCachedData(['PROFILE']);

    return profiles.where((profile) => profile.id == profileId).firstOrNull?.fields['name'] as String?;
  }

  void _openTravelWarning(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final countryCode = _locationInfo?.countryCode ?? '';
    final countryName = _locationInfo?.countryName ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TravelWarningSheet(
        countryCode: countryCode,
        countryName: countryName,
        limits: _limits,
        isLoggedIn: AuthScope.of(context),
        locale: locale,
      ),
    );
  }

  Future<void> _openEmergencyCard(BuildContext context) async {
    if (AuthScope.of(context)) {
      final encryptionReady = await ensureEncryptionUnlocked(context);

      if (!encryptionReady || !context.mounted) {
        return;
      }

      if (!_healthDataLoaded) {
        final cachedData = await dataService.getCachedData();

        if (!mounted) {
          return;
        }

        setState(() {
          _healthData = cachedData;
          _healthDataLoaded = true;
        });
      }
    }

    if (!context.mounted) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EmergencyCardSheet(healthData: _healthData, metricUnits: _metricUnits),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final countryCode = _locationInfo?.countryCode ?? '';
    final emergencyNumbers = emergencyNumbersFor(countryCode);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(localizations, theme, context)),
            SliverToBoxAdapter(child: RepaintBoundary(child: _buildMap(theme))),
            SliverToBoxAdapter(child: _buildEmergencyCardPreview(localizations, theme, context)),
            SliverToBoxAdapter(child: _buildTripsCard(localizations, theme, context)),
            SliverToBoxAdapter(
              child: _buildEmergencyNumbers(localizations, theme, emergencyNumbers),
            ),
            SliverToBoxAdapter(child: _buildCurrencyCard(localizations, theme, context)),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    AppLocalizations localizations,
    ThemeData theme,
    BuildContext context,
  ) {
    final locationText = _isLocating
        ? localizations.dashboardLoadingLocation
        : _locationPermissionDenied
            ? localizations.dashboardLocationPermissionDenied
            : _locationInfo?.city.isNotEmpty == true
                ? _locationInfo!.city
                : localizations.dashboardLocationUnknown;

    final subtitleText = _locationInfo?.countryName.isNotEmpty == true
        ? _locationInfo!.countryName
        : null;

    final canShowWarning = !_isLocating &&
        _locationInfo != null &&
        _locationInfo!.countryCode.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              key: const ValueKey('location_header'),
              onTap: canShowWarning ? () => _openTravelWarning(context) : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locationText,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitleText != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            subtitleText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canShowWarning) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ] else if (!_isLocating && !_locationPermissionDenied && _locationInfo == null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() => _isLocating = true);
                        _initLocation();
                      },
                      child: Icon(
                        Icons.refresh,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_temperature != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                formatTemperature(localizations, _temperature!, metricUnits: _metricUnits),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrencyCard(
    AppLocalizations localizations,
    ThemeData theme,
    BuildContext context,
  ) {
    final awayCurrency = _awayCurrency ?? 'USD';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: () => _openCurrencyConverter(context, localizations, theme),
        child: Container(
          decoration: BoxDecoration(
            color: Color.lerp(
              theme.colorScheme.surface,
              theme.colorScheme.onSurface,
              0.04,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                Icons.currency_exchange,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.currencyConverterTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (_ratesLoading && _exchangeRates == null)
                      Text(
                        '...',
                        style: theme.textTheme.bodySmall,
                      )
                    else if (_exchangeRates == null)
                      Text(
                        localizations.currencyConverterNoRates,
                        style: theme.textTheme.bodySmall,
                      )
                    else
                      _buildRateDisplay(theme, localizations, awayCurrency),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRateDisplay(
    ThemeData theme,
    AppLocalizations localizations,
    String awayCurrency,
  ) {
    final rates = _exchangeRates!;
    final rate = currencyService.convert(1, _homeCurrency, awayCurrency, rates);
    final rateStr = rate >= 100
        ? rate.toStringAsFixed(0)
        : rate >= 10
            ? rate.toStringAsFixed(1)
            : rate.toStringAsFixed(4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '1 $_homeCurrency = $rateStr $awayCurrency',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_ratesFetchedAt != null) ...[
          const SizedBox(height: 2),
          Text(
            _ratesOffline
                ? localizations.currencyConverterOffline
                : localizations.currencyConverterLastUpdated(
                    _formatAge(_ratesFetchedAt!, localizations),
                  ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ],
    );
  }

  void _openCurrencyConverter(
    BuildContext context,
    AppLocalizations localizations,
    ThemeData theme,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CurrencyConverterSheet(
        homeCurrency: _homeCurrency,
        awayCurrency: _awayCurrency ?? 'USD',
        rates: _exchangeRates,
        ratesOffline: _ratesOffline,
        fetchedAt: _ratesFetchedAt,
        localizations: localizations,
        onCurrenciesChanged: (home, away) async {
          final previousHome = _homeCurrency;

          setState(() {
            _homeCurrency = home;
            _awayCurrency = away;
          });

          if (home != previousHome && mounted) {
            await _refreshRates(home);
          }
        },
      ),
    );
  }

  Widget _buildMap(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 220,
          child: _position != null
              ? Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: _position!,
                        initialZoom: 13,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: appId,
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _position!,
                              width: 48,
                              height: 48,
                              child: Icon(
                                Icons.location_pin,
                                color: theme.colorScheme.primary,
                                size: 40,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FullMapPage(position: _position!),
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ],
                )
              : Container(
                  color: theme.colorScheme.surface,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 40,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                        if (!_isLocating && !_locationPermissionDenied) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() => _isLocating = true);
                              _initLocation();
                            },
                            child: Icon(
                              Icons.refresh,
                              size: 24,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildEmergencyCardPreview(
    AppLocalizations localizations,
    ThemeData theme,
    BuildContext context,
  ) {
    final allergyCount =
        _healthData.where((item) => item.feature == 'ALLERGY').length;
    final conditionCount =
        _healthData.where((item) => item.feature == 'CONDITION').length;
    final vaccineCount =
        _healthData.where((item) => item.feature == 'VACCINE').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        key: const ValueKey('emergency_card_preview'),
        onTap: () => _openEmergencyCard(context),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              const Icon(
                Icons.local_hospital_outlined,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _limits.hasProfiles
                          ? '${localizations.dashboardEmergencyCardTitle} - ${_profileName ?? localizations.profileMe}'
                          : localizations.dashboardEmergencyCardTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (!_healthDataLoaded)
                      Text(
                        '...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      )
                    else
                      Text(
                        localizations.dashboardEmergencyCardPreviewSummary(
                          allergyCount,
                          conditionCount,
                          vaccineCount,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripsCard(AppLocalizations localizations, ThemeData theme, BuildContext context) {
    final nextTrip = Trip.fromDataList(_healthData).where((trip) => !trip.isOver(_today())).firstOrNull;
    final dateFormat = DateFormat.yMd(localizations.localeName);

    return _buildFeatureCard(
      theme: theme,
      key: const ValueKey('trips_card'),
      icon: Icons.flight_takeoff_outlined,
      title: localizations.tripsTitle,
      subtitle: nextTrip == null
          ? localizations.tripsSubtitle
          : '${tripPlaceName(context, nextTrip)}, ${dateFormat.format(nextTrip.start)}',
      enabled: _limits.tripsEnabled,
      onOpen: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MemoriesPage()));
        await _loadHealthData();
      },
    );
  }

  Widget _buildFeatureCard({
    required ThemeData theme,
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onOpen,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Opacity(
        opacity: enabled ? 1 : 0.38,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onOpen : null,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          if (!enabled) ...[
                            const SizedBox(width: 8),
                            const TierBadge('Pro'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  enabled ? Icons.chevron_right : Icons.lock_outline,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  size: enabled ? 20 : 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyNumbers(
    AppLocalizations localizations,
    ThemeData theme,
    EmergencyNumbers numbers,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              localizations.dashboardEmergencyNumbersTitle.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 0.8,
              ),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                _EmergencyNumberTile(
                  icon: Icons.local_police_outlined,
                  label: localizations.dashboardEmergencyPolice,
                  number: numbers.police,
                  isFirst: true,
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                ),
                _EmergencyNumberTile(
                  icon: Icons.local_fire_department_outlined,
                  label: localizations.dashboardEmergencyFire,
                  number: numbers.fire,
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                ),
                _EmergencyNumberTile(
                  icon: Icons.emergency_outlined,
                  label: localizations.dashboardEmergencyAmbulance,
                  number: numbers.ambulance,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyCardSheet extends StatefulWidget {
  final List<Data> healthData;
  final bool metricUnits;

  const _EmergencyCardSheet({required this.healthData, required this.metricUnits});

  @override
  State<_EmergencyCardSheet> createState() => _EmergencyCardSheetState();
}

class _EmergencyCardSheetState extends State<_EmergencyCardSheet> {
  static const _lastLanguageKey = 'emergency_card_last_language';
  bool _exporting = false;

  String? _selectedLanguage;
  EmergencyCardTranslation? _translation;
  bool _translating = false;
  bool _stale = false;

  @override
  void initState() {
    super.initState();
    _restoreLastLanguage();
  }

  Future<void> _restoreLastLanguage() async {
    final saved = await storage.read(key: _lastLanguageKey);

    if (saved != null && mounted) {
      await _selectLanguage(saved);
    }
  }

  Future<void> _selectLanguage(String? langCode) async {
    if (langCode == null) {
      await storage.delete(key: _lastLanguageKey);
      setState(() {
        _selectedLanguage = null;
        _translation = null;
        _stale = false;
      });

      return;
    }

    await storage.write(key: _lastLanguageKey, value: langCode);

    setState(() {
      _selectedLanguage = langCode;
      _translating = true;
      _stale = false;
    });

    final currentHash = EmergencyCardTranslation.hashFrom(widget.healthData);
    final cacheKey = 'emergency_card_translation_$langCode';
    final cached = await readObjectCache(cacheKey);

    if (cached != null) {
      final cachedTranslation = EmergencyCardTranslation.fromJson(cached);

      if (cachedTranslation.dataHash == currentHash) {
        if (!mounted) {
          return;
        }

        setState(() {
          _translation = cachedTranslation;
          _translating = false;
        });

        return;
      }
    }

    final translation = await _generateTranslation(langCode, currentHash);

    if (!mounted) {
      return;
    }

    if (translation != null) {
      await saveObjectCache(cacheKey, translation.toJson());
      setState(() {
        _translation = translation;
        _translating = false;
        _stale = false;
      });
    } else if (cached != null) {
      setState(() {
        _translation = EmergencyCardTranslation.fromJson(cached);
        _translating = false;
        _stale = true;
      });
    } else {
      setState(() {
        _translation = null;
        _translating = false;
      });
    }
  }

  Future<EmergencyCardTranslation?> _generateTranslation(
    String langCode,
    String hash,
  ) async {
    final modelsReady = await translationService.ensureModels('de', langCode);

    if (!modelsReady) {
      return null;
    }

    final originalAllergies = EmergencyCardTranslation.allergiesFrom(widget.healthData);
    final allergies = await translationService.translateList(
          originalAllergies,
          from: 'de',
          to: langCode,
        ) ??
        originalAllergies;

    final originalConditions = EmergencyCardTranslation.conditionsFrom(widget.healthData);
    final conditions = await translationService.translateList(
          originalConditions,
          from: 'de',
          to: langCode,
        ) ??
        originalConditions;

    final originalHealthValues = EmergencyCardTranslation.healthValuesFrom(widget.healthData);
    final healthValues = await translationService.translateList(
          originalHealthValues,
          from: 'de',
          to: langCode,
        ) ??
        originalHealthValues;

    final vaccineNames = EmergencyCardTranslation.vaccineNamesFrom(widget.healthData);
    final rawDiseases = EmergencyCardTranslation.vaccineDiseaseFrom(widget.healthData);
    final nonNullDiseases = rawDiseases.whereType<String>().toList();
    final translatedDiseases =
        await translationService.translateList(nonNullDiseases, from: 'de', to: langCode) ??
            nonNullDiseases;
    var translatedDiseaseIndex = 0;
    final vaccineDiseases = rawDiseases
        .map((disease) => disease != null ? translatedDiseases[translatedDiseaseIndex++] : null)
        .toList();

    final originalVitalSigns = EmergencyCardTranslation.vitalSignsFrom(widget.healthData, metricUnits: widget.metricUnits);
    final translatedVitalLabels = await translationService.translateList(
          originalVitalSigns.map((vitalSign) => vitalSign.split(': ').first).toList(),
          from: 'de',
          to: langCode,
        ) ??
        originalVitalSigns.map((vitalSign) => vitalSign.split(': ').first).toList();
    final vitalValues = originalVitalSigns.map((vitalSign) {
      final parts = vitalSign.split(': ');
      return parts.length > 1 ? parts.sublist(1).join(': ') : '-';
    }).toList();
    final vitalSigns = List.generate(
      translatedVitalLabels.length,
      (index) => '${translatedVitalLabels[index]}: ${vitalValues[index]}',
    );

    return EmergencyCardTranslation(
      languageCode: langCode,
      allergies: allergies,
      conditions: conditions,
      vitalSigns: vitalSigns,
      healthValues: healthValues,
      vaccineNames: vaccineNames,
      vaccineDiseases: vaccineDiseases,
      dataHash: hash,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isTranslated = _selectedLanguage != null && _translation != null;
    final translatedLocalizations = isTranslated
        ? lookupAppLocalizations(Locale(_selectedLanguage!))
        : null;

    final content = _content;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              SheetHandle(color: Colors.white.withValues(alpha: 0.3)),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_hospital_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                translatedLocalizations?.dashboardEmergencyCardTitle ?? appLocalizations.dashboardEmergencyCardTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                translatedLocalizations?.dashboardEmergencyCardSubtitle ?? appLocalizations.dashboardEmergencyCardSubtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _exporting ? null : () => _shareCard(appLocalizations),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: _exporting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.share_outlined, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        appLocalizations.share,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
                    const SizedBox(height: 20),
                    if (_translating) ...[
                      Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            appLocalizations.emergencyCardTranslating,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      if (_stale)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_outlined,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  appLocalizations.emergencyCardTranslationStale,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _selectLanguage(_selectedLanguage),
                                child: Text(
                                  appLocalizations.emergencyCardTranslationUpdate,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _EmergencySection(
                        title: translatedLocalizations?.dashboardEmergencyAllergies ?? appLocalizations.dashboardEmergencyAllergies,
                        icon: Icons.warning_amber_outlined,
                        items: content.allergies,
                        emptyText: translatedLocalizations?.dashboardEmergencyNoAllergies ?? appLocalizations.dashboardEmergencyNoAllergies,
                      ),
                      const SizedBox(height: 20),
                      _EmergencySection(
                        title: translatedLocalizations?.dashboardEmergencyConditions ?? appLocalizations.dashboardEmergencyConditions,
                        icon: Icons.medical_information_outlined,
                        items: content.conditions,
                        emptyText: translatedLocalizations?.dashboardEmergencyNoConditions ?? appLocalizations.dashboardEmergencyNoConditions,
                      ),
                      const SizedBox(height: 20),
                      _EmergencySection(
                        title: translatedLocalizations?.dashboardEmergencyVitals ?? appLocalizations.dashboardEmergencyVitals,
                        icon: Icons.favorite_outline,
                        items: content.vitalSigns,
                        emptyText: translatedLocalizations?.dashboardEmergencyNoVitals ?? appLocalizations.dashboardEmergencyNoVitals,
                      ),
                      if (content.healthValues.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _EmergencySection(
                          title: translatedLocalizations?.dashboardEmergencyHealthValues ?? appLocalizations.dashboardEmergencyHealthValues,
                          icon: Icons.monitor_heart_outlined,
                          items: content.healthValues,
                          emptyText: '',
                        ),
                      ],
                      const SizedBox(height: 20),
                      _EmergencySection(
                        title: translatedLocalizations?.dashboardEmergencyVaccines ?? appLocalizations.dashboardEmergencyVaccines,
                        icon: Icons.vaccines_outlined,
                        items: content.vaccines,
                        emptyText: translatedLocalizations?.dashboardEmergencyNoVaccines ?? appLocalizations.dashboardEmergencyNoVaccines,
                      ),
                    ],
                    const SizedBox(height: 28),
                    Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            translatedLocalizations?.dashboardEmergencyShowHint ?? appLocalizations.dashboardEmergencyShowHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _LanguageChip(
                            label: appLocalizations.emergencyCardOriginal,
                            selected: _selectedLanguage == null,
                            onTap: () => _selectLanguage(null),
                          ),
                          ...TranslationService.supportedLanguages.map(
                            (lang) => _LanguageChip(
                              label: lang.$2,
                              selected: _selectedLanguage == lang.$1,
                              onTap: () => _selectLanguage(lang.$1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  EmergencyCardContent get _content {
    final translation = _translation;

    if (_selectedLanguage != null && translation != null) {
      return EmergencyCardContent.fromTranslation(translation, widget.healthData);
    }

    return EmergencyCardContent.fromHealthData(widget.healthData, metricUnits: widget.metricUnits);
  }

  Future<void> _shareCard(AppLocalizations localizations) async {
    setState(() => _exporting = true);

    final isTranslated = _selectedLanguage != null && _translation != null;
    final translatedLocalizations = isTranslated
        ? lookupAppLocalizations(Locale(_selectedLanguage!))
        : null;

    try {
      await shareWidgetAsImage(
        context,
        fileName: 'emergency-card',
        subject: localizations.dashboardEmergencyCardTitle,
        child: EmergencyCardView(localizations: translatedLocalizations ?? localizations, content: _content),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }
}


class _LanguageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: selected ? 1.0 : 0.3),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmergencySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final String emptyText;

  const _EmergencySection({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            emptyText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontStyle: FontStyle.italic,
                ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map(
                  (item) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _EmergencyNumberTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String number;
  final bool isFirst;
  final bool isLast;

  const _EmergencyNumberTile({
    required this.icon,
    required this.label,
    required this.number,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final borderRadius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(12) : Radius.zero,
      bottom: isLast ? const Radius.circular(12) : Radius.zero,
    );

    return InkWell(
      onTap: () => launchUrl(Uri.parse('tel:$number')),
      borderRadius: borderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: theme.textTheme.bodyMedium),
            ),
            Text(
              number,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.phone_outlined,
              size: 16,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _TravelWarningSheet extends StatefulWidget {
  final String countryCode;
  final String countryName;
  final Limits limits;
  final bool isLoggedIn;
  final String locale;

  const _TravelWarningSheet({
    required this.countryCode,
    required this.countryName,
    required this.limits,
    required this.isLoggedIn,
    required this.locale,
  });

  @override
  State<_TravelWarningSheet> createState() => _TravelWarningSheetState();
}

class _TravelWarningSheetState extends State<_TravelWarningSheet> {
  TravelWarningResult? _result;
  bool _loadingWarning = true;
  CountryContent? _content;
  bool _loadingContent = false;
  bool _translating = false;
  bool _translationFailed = false;

  bool get _anyContentEnabled =>
      widget.isLoggedIn &&
      (widget.limits.countryInfoSafetyEnabled ||
          widget.limits.countryInfoTravelEnabled ||
          widget.limits.countryInfoEntryEnabled ||
          widget.limits.countryInfoHealthEnabled ||
          widget.limits.countryInfoLegalEnabled ||
          widget.limits.countryInfoLgbtqEnabled);

  bool get _needsTranslation => widget.locale != 'de';

  @override
  void initState() {
    super.initState();
    _loadWarning();
  }

  Future<void> _loadWarning() async {
    final cachedResult = await travelWarningService.getCachedWarningForCountry(
      widget.countryCode,
    );

    if (!mounted) {
      return;
    }

    if (cachedResult != null) {
      setState(() {
        _result = cachedResult;
        _loadingWarning = false;
      });

      final cachedCountryId = cachedResult.warning?.countryId;

      if (cachedCountryId != null && _anyContentEnabled) {
        final cachedContent = await travelWarningService.getCachedCountryContent(cachedCountryId);

        if (!mounted) {
          return;
        }

        if (cachedContent != null) {
          if (!_needsTranslation) {
            setState(() => _content = cachedContent);
          } else {
            _showCachedTranslation(cachedCountryId, cachedContent);
          }
        }
      }
    }

    final freshResult = await travelWarningService.getWarningForCountry(
      widget.countryCode,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _result = freshResult;
      _loadingWarning = false;
    });

    final countryId = freshResult.warning?.countryId;

    if (countryId != null && _anyContentEnabled) {
      setState(() => _loadingContent = true);

      final german = await travelWarningService.getCountryContent(countryId);

      if (!mounted) {
        return;
      }

      if (!_needsTranslation || german == null) {
        setState(() {
          _content = german;
          _loadingContent = false;
        });

        return;
      }

      setState(() => _loadingContent = false);

      await _translateContent(countryId, german);
    }
  }

  Future<void> _showCachedTranslation(int countryId, CountryContent german) async {
    final cacheKey = travelWarningService.translatedCacheKey(countryId, widget.locale);
    final cached = await readObjectCache(cacheKey);

    if (!mounted || cached == null) {
      return;
    }

    setState(() => _content = CountryContent.fromJson(cached));
  }

  Future<void> _translateContent(int countryId, CountryContent german) async {
    setState(() {
      _translating = true;
      _translationFailed = false;
    });

    final cacheKey = travelWarningService.translatedCacheKey(countryId, widget.locale);
    final germanHash = TravelWarningService.hashContent(german);
    final cached = await readObjectCache(cacheKey);

    if (cached != null && cached['hash'] == germanHash) {
      if (!mounted) {
        return;
      }

      setState(() {
        _content = CountryContent.fromJson(cached);
        _translating = false;
      });

      return;
    }

    final modelsReady = await translationService.ensureModels('de', widget.locale);

    if (!modelsReady) {
      if (!mounted) {
        return;
      }

      setState(() {
        _content = cached != null ? CountryContent.fromJson(cached) : german;
        _translating = false;
        _translationFailed = cached == null;
      });

      return;
    }

    Future<String?> translateSection(String? text) async {
      if (text == null) {
        return null;
      }

      final lines = text.split('\n').where((line) => line.isNotEmpty).toList();

      if (lines.isEmpty) {
        return text;
      }

      final result = await translationService.translateList(lines, from: 'de', to: widget.locale);

      return result?.join('\n');
    }

    final translated = CountryContent(
      safety: await translateSection(german.safety),
      travel: await translateSection(german.travel),
      entry: await translateSection(german.entry),
      health: await translateSection(german.health),
      legal: await translateSection(german.legal),
      lgbtq: await translateSection(german.lgbtq),
    );

    final failed = translated.safety == null &&
        translated.travel == null &&
        translated.entry == null &&
        translated.health == null &&
        translated.legal == null &&
        translated.lgbtq == null;

    if (!mounted) {
      return;
    }

    if (failed) {
      setState(() {
        _content = cached != null ? CountryContent.fromJson(cached) : german;
        _translating = false;
        _translationFailed = cached == null;
      });

      return;
    }

    await saveObjectCache(cacheKey, {
      'hash': germanHash,
      ...translated.toJson(),
    });

    setState(() {
      _content = translated;
      _translating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final warning = _result?.warning;
    final networkError = _result?.networkError ?? false;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SheetHandle(key: ValueKey('travel_warning_drag_handle')),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.travel_explore_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${localizations.dashboardTravelWarningTitle} - ${widget.countryName}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  _warningBadge(localizations, theme, warning, networkError),
                  if (_translating) ...[
                    const SizedBox(height: 16),
                    LoadingRow(text: localizations.emergencyCardTranslating),
                  ],
                  if (_translationFailed) ...[
                    const SizedBox(height: 16),
                    StatusRow(
                      icon: Icons.translate,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      text: localizations.emergencyCardTranslationFailed,
                    ),
                  ],
                  if (warning?.countryId != null && !_translating) ...[
                    const SizedBox(height: 16),
                    _contentSection(
                      localizations.countryInfoSafety,
                      widget.limits.countryInfoSafetyEnabled,
                      _content?.safety,
                    ),
                    const SizedBox(height: 12),
                    _contentSection(
                      localizations.countryInfoTravel,
                      widget.limits.countryInfoTravelEnabled,
                      _content?.travel,
                    ),
                    const SizedBox(height: 12),
                    _contentSection(
                      localizations.countryInfoEntry,
                      widget.limits.countryInfoEntryEnabled,
                      _content?.entry,
                    ),
                    const SizedBox(height: 12),
                    _contentSection(
                      localizations.countryInfoHealth,
                      widget.limits.countryInfoHealthEnabled,
                      _content?.health,
                    ),
                    const SizedBox(height: 12),
                    _contentSection(
                      localizations.countryInfoLegal,
                      widget.limits.countryInfoLegalEnabled,
                      _content?.legal,
                    ),
                    const SizedBox(height: 12),
                    _contentSection(
                      localizations.countryInfoLgbtq,
                      widget.limits.countryInfoLgbtqEnabled,
                      _content?.lgbtq,
                    ),
                    if (_result?.warning?.countryId != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(
                              'https://www.auswaertiges-amt.de/de/ReiseUndSicherheit/${warning!.countryId}',
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: Text(localizations.dashboardTravelWarningOpenMore),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _warningBadge(
    AppLocalizations localizations,
    ThemeData theme,
    TravelWarning? warning,
    bool networkError,
  ) {
    if (_loadingWarning) {
      return LoadingRow(text: localizations.dashboardTravelWarningLoading);
    }

    if (networkError) {
      return StatusRow(
        icon: Icons.wifi_off_outlined,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        text: localizations.dashboardTravelWarningOffline,
      );
    }

    if (warning == null) {
      return StatusRow(
        icon: Icons.info_outline,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        text: widget.countryCode == 'DE' ? localizations.countryNoInformationGermany : localizations.countryNoInformation,
      );
    }

    return StatusRow(
      icon: warning.hasWarning
          ? Icons.warning_amber_rounded
          : warning.hasPartialWarning
              ? Icons.info_outline
              : Icons.check_circle_outline,
      color: warning.hasWarning
          ? Colors.red.shade600
          : warning.hasPartialWarning
              ? Colors.orange.shade600
              : Colors.green.shade600,
      text: warning.hasWarning
          ? localizations.dashboardTravelWarningActive
          : warning.hasPartialWarning
              ? localizations.dashboardTravelWarningPartial
              : localizations.dashboardTravelWarningNone,
    );
  }

  Widget _contentSection(String title, bool enabled, String? content) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (!widget.isLoggedIn || !enabled) {
      return _DisabledFeatureRow(
        label: title,
        loginRequired: !widget.isLoggedIn,
      );
    }

    if (_loadingContent) {
      return LoadingRow(text: localizations.dashboardTravelWarningContentLoading);
    }

    if (content == null || content.isEmpty) {
      return StatusRow(
        icon: Icons.info_outline,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        text: localizations.countryInfoUnavailableOffline,
      );
    }

    final lines = content.split('\n').where((line) => line.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ...lines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(line, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
          ),
        ),
      ],
    );
  }
}

class _DisabledFeatureRow extends StatelessWidget {
  final String label;
  final bool loginRequired;

  const _DisabledFeatureRow({required this.label, this.loginRequired = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    return Opacity(
      opacity: 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              loginRequired ? Icons.person_outline : Icons.lock_outline,
              size: 18,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  Text(
                    loginRequired
                        ? localizations.loginRequiredForFeature
                        : localizations.featureNotAvailableInPlan,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyConverterSheet extends StatefulWidget {
  final String homeCurrency;
  final String awayCurrency;
  final Map<String, double>? rates;
  final bool ratesOffline;
  final DateTime? fetchedAt;
  final AppLocalizations localizations;
  final void Function(String home, String away) onCurrenciesChanged;

  const _CurrencyConverterSheet({
    required this.homeCurrency,
    required this.awayCurrency,
    required this.rates,
    required this.ratesOffline,
    required this.fetchedAt,
    required this.localizations,
    required this.onCurrenciesChanged,
  });

  @override
  State<_CurrencyConverterSheet> createState() => _CurrencyConverterSheetState();
}

class _CurrencyConverterSheetState extends State<_CurrencyConverterSheet> {
  late String _from;
  late String _to;
  final _fromController = TextEditingController(text: '1');
  final _toController = TextEditingController();
  bool _updatingFields = false;

  @override
  void initState() {
    super.initState();
    _from = widget.homeCurrency;
    _to = widget.awayCurrency;
    _recalculateTo();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  String _format(double value) {
    if (value >= 1000) {
      return value.toStringAsFixed(0);
    }

    if (value >= 10) {
      return value.toStringAsFixed(2);
    }

    return value.toStringAsFixed(4);
  }

  void _recalculateTo() {
    if (_updatingFields) {
      return;
    }

    final rates = widget.rates;

    if (rates == null) {
      return;
    }

    final amount = double.tryParse(_fromController.text) ?? 0;
    final result = currencyService.convert(amount, _from, _to, rates);

    _updatingFields = true;
    _toController.text = _format(result);
    _updatingFields = false;

    setState(() {});
  }

  void _recalculateFrom() {
    if (_updatingFields) {
      return;
    }

    final rates = widget.rates;

    if (rates == null) {
      return;
    }

    final amount = double.tryParse(_toController.text) ?? 0;
    final result = currencyService.convert(amount, _to, _from, rates);

    _updatingFields = true;
    _fromController.text = _format(result);
    _updatingFields = false;

    setState(() {});
  }

  void _swap() {
    final fromText = _fromController.text;

    setState(() {
      final temp = _from;
      _from = _to;
      _to = temp;
      _fromController.text = _toController.text;
      _toController.text = fromText;
    });

    widget.onCurrenciesChanged(_from, _to);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = widget.localizations;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Row(
              children: [
                Icon(
                  Icons.currency_exchange,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  localizations.currencyConverterTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.rates == null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      localizations.currencyConverterNoRates,
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          localizations.currencyConverterSelectFrom,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 12 + 48 + 12),
                      Expanded(
                        child: Text(
                          localizations.currencyConverterSelectTo,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _CurrencyField(
                          currency: _from,
                          controller: _fromController,
                          onCurrencyTap: () => _pickCurrency(
                            context,
                            localizations,
                            isFrom: true,
                          ),
                          onChanged: (_) => _recalculateTo(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _swap,
                        icon: Icon(
                          Icons.swap_horiz,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CurrencyField(
                          currency: _to,
                          controller: _toController,
                          onCurrencyTap: () => _pickCurrency(
                            context,
                            localizations,
                            isFrom: false,
                          ),
                          onChanged: (_) => _recalculateFrom(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (widget.fetchedAt != null)
                    Text(
                      widget.ratesOffline
                          ? localizations.currencyConverterOffline
                          : localizations.currencyConverterLastUpdated(
                              _formatAge(widget.fetchedAt!, localizations),
                            ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCurrency(
    BuildContext context,
    AppLocalizations localizations, {
    required bool isFrom,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CurrencyPickerSheet(
        currencies: CurrencyService.supportedCurrencies,
        selected: isFrom ? _from : _to,
        localizations: localizations,
      ),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      if (isFrom) {
        _from = selected;
      } else {
        _to = selected;
      }
    });

    widget.onCurrenciesChanged(_from, _to);
  }
}

class _CurrencyPickerSheet extends StatelessWidget {
  final List<String> currencies;
  final String selected;
  final AppLocalizations localizations;

  const _CurrencyPickerSheet({
    required this.currencies,
    required this.selected,
    required this.localizations,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, controller) {
        return Column(
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                localizations.currencyConverterSelectCurrency,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: currencies.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                ),
                itemBuilder: (_, index) {
                  final code = currencies[index];
                  final name = CurrencyService.currencyNames[code] ?? code;
                  final isSelected = code == selected;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(
                      code,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : null,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    subtitle: Text(name, style: theme.textTheme.bodySmall),
                    trailing: isSelected
                        ? Icon(Icons.check, color: theme.colorScheme.primary, size: 18)
                        : null,
                    onTap: () => Navigator.of(context).pop(code),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CurrencyField extends StatelessWidget {
  final String currency;
  final TextEditingController controller;
  final VoidCallback onCurrencyTap;
  final ValueChanged<String> onChanged;

  const _CurrencyField({
    required this.currency,
    required this.controller,
    required this.onCurrencyTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        suffixIcon: GestureDetector(
          onTap: onCurrencyTap,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currency,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.expand_more, size: 14, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatAge(DateTime fetchedAt, AppLocalizations localizations) {
  final age = DateTime.now().difference(fetchedAt);

  if (age.inMinutes < 1) {
    return localizations.currencyConverterJustNow;
  }

  if (age.inMinutes < 60) {
    return localizations.currencyConverterMinutesAgo(age.inMinutes);
  }

  return localizations.currencyConverterHoursAgo(age.inHours);
}
