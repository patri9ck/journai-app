// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter_test/flutter_test.dart';
import 'package:journai_app/model/country_content.dart';
import 'package:journai_app/model/data.dart';
import 'package:journai_app/model/day_weather.dart';
import 'package:journai_app/model/location_info.dart';
import 'package:journai_app/model/place_suggestion.dart';
import 'package:journai_app/model/poi.dart';
import 'package:journai_app/model/user_info.dart';

void main() {
  test('Data round-trips and tolerates missing fields', () {
    final data = Data(id: 7, feature: 'TRIP', fields: {'city': 'Kyoto'}, profileId: 2);

    final parsed = Data.fromJson(data.toJson());

    expect(parsed.id, 7);
    expect(parsed.feature, 'TRIP');
    expect(parsed.fields, {'city': 'Kyoto'});
    expect(parsed.profileId, 2);
    expect(Data.fromJson({'feature': 'VACCINE'}).fields, isEmpty);
    expect(Data.fromJson({'feature': 'VACCINE'}).id, isNull);
  });

  test('UserInfo counts the login methods', () {
    expect(UserInfo.fromJson({}).loginMethodCount, 0);
    expect(
      UserInfo.fromJson({'email': 'a@b.c', 'googleLinked': true}).loginMethodCount,
      2,
    );
    expect(UserInfo.fromJson({'phone': '+4915123456789', 'appleLinked': true}).phone, '+4915123456789');
  });

  test('DayWeather is rainy from one millimeter up and round-trips', () {
    expect(DayWeather.fromJson({'temperature': 21, 'precipitation': 0.9}).isRainy, isFalse);
    expect(DayWeather.fromJson({'temperature': 21, 'precipitation': 1}).isRainy, isTrue);
    expect(DayWeather.fromJson(DayWeather(temperature: 21.5, precipitation: 2).toJson()).temperature, 21.5);
  });

  test('Poi.fromOverpass maps amenities and skips everything else', () {
    final hospital = Poi.fromOverpass({
      'lat': 52.5,
      'lon': 13.4,
      'tags': {'amenity': 'hospital', 'name': 'Charité'},
    });

    expect(hospital?.type, PoiType.hospital);
    expect(hospital?.name, 'Charité');

    expect(Poi.fromOverpass({
      'center': {'lat': 1.0, 'lon': 2.0},
      'tags': {'amenity': 'pharmacy'},
    })?.type, PoiType.pharmacy);

    expect(Poi.fromOverpass({'lat': 1.0, 'lon': 2.0, 'tags': {'amenity': 'cafe'}}), isNull);
    expect(Poi.fromOverpass({'tags': {'amenity': 'police'}}), isNull);
    expect(Poi.fromOverpass({'lat': 1.0, 'lon': 2.0}), isNull);
  });

  test('CountryContent round-trips with missing sections as null', () {
    final content = CountryContent.fromJson({'safety': '- a\n- b', 'entry': '- c'});

    expect(content.safety, '- a\n- b');
    expect(content.legal, isNull);
    expect(CountryContent.fromJson(content.toJson()).safety, content.safety);
  });

  test('PlaceSuggestion and LocationInfo hold their values', () {
    const suggestion = PlaceSuggestion(name: 'Berlin', detail: 'Berlin, Germany');
    const location = LocationInfo(city: 'Berlin', countryName: 'Germany', countryCode: 'DE');

    expect(suggestion.name, 'Berlin');
    expect(location.countryCode, 'DE');
  });
}
