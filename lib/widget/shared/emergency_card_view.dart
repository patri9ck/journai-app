// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/data.dart';
import '../../util/dynamic_palette.dart';

class EmergencyCardView extends StatelessWidget {
  final AppLocalizations localizations;
  final List<String> allergies;
  final List<String> conditions;
  final List<String> vitalSigns;
  final List<String> healthValues;
  final List<Data> vaccines;

  const EmergencyCardView({
    required this.localizations,
    required this.allergies,
    required this.conditions,
    required this.vitalSigns,
    required this.healthValues,
    required this.vaccines,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: emergencyCardColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_hospital_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  localizations.dashboardEmergencyCardTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            localizations.dashboardEmergencyCardSubtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
          ),
          const SizedBox(height: 20),
          _CardSection(
            title: localizations.dashboardEmergencyAllergies,
            items: allergies,
            emptyText: localizations.dashboardEmergencyNoAllergies,
          ),
          const SizedBox(height: 16),
          _CardSection(
            title: localizations.dashboardEmergencyConditions,
            items: conditions,
            emptyText: localizations.dashboardEmergencyNoConditions,
          ),
          const SizedBox(height: 16),
          _CardSection(
            title: localizations.dashboardEmergencyVitals,
            items: vitalSigns,
            emptyText: localizations.dashboardEmergencyNoVitals,
          ),
          if (healthValues.isNotEmpty) ...[
            const SizedBox(height: 16),
            _CardSection(title: localizations.dashboardEmergencyHealthValues, items: healthValues, emptyText: ''),
          ],
          const SizedBox(height: 16),
          _CardSection(
            title: localizations.dashboardEmergencyVaccines,
            items: vaccines.isEmpty
                ? [localizations.dashboardEmergencyNoVaccines]
                : vaccines.map((v) {
                    final name = v.fields['name'] as String? ?? '-';
                    final disease = v.fields['disease'] as String?;
                    return disease != null && disease.isNotEmpty ? '$name - $disease' : name;
                  }).toList(),
            emptyText: '',
          ),
          const SizedBox(height: 20),
          Text(
            localizations.dashboardEmergencyShowHint,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final String emptyText;

  const _CardSection({required this.title, required this.items, this.emptyText = ''});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty && emptyText.isNotEmpty)
          Text(
            emptyText,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontStyle: FontStyle.italic),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
