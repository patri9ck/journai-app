// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

enum ConsentType {
  healthDataScan('HEALTH_DATA_SCAN', 'health-data-scan', 'cache_consent_health'),
  documentScan('DOCUMENT_SCAN', 'document-scan', 'cache_consent_document');

  final String apiName;
  final String pagePath;
  final String cacheKey;

  const ConsentType(this.apiName, this.pagePath, this.cacheKey);
}
