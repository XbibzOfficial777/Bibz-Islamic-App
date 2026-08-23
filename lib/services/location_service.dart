part of '../main.dart';

class GpsServiceDisabledException extends StateError {
  GpsServiceDisabledException()
    : super('Layanan lokasi/GPS perangkat sedang nonaktif.');
}

class GpsPermissionDeniedException extends StateError {
  GpsPermissionDeniedException({required this.permanentlyDenied})
    : super(
        permanentlyDenied
            ? 'Izin lokasi ditolak permanen. Aktifkan izin lokasi QuranX dari Pengaturan aplikasi.'
            : 'Izin lokasi diperlukan untuk jadwal sholat otomatis.',
      );

  final bool permanentlyDenied;
}

String _normalizePrayerLocationName(String value) {
  final withoutPunctuation = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
  return withoutPunctuation
      .replaceAll(
        RegExp(
          r'\b(kecamatan|kabupaten|kab|kota|provinsi|province|district)\b',
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> buildPrayerLocationQueries(Iterable<String?> values) {
  final queries = <String>[];
  for (final value in values) {
    final original = value?.trim() ?? '';
    if (original.isEmpty) continue;
    if (!queries.contains(original)) queries.add(original);

    final normalized = _normalizePrayerLocationName(original);
    if (normalized.isNotEmpty && !queries.contains(normalized)) {
      queries.add(normalized);
    }
  }
  return queries;
}

PrayerCity? selectPrayerCity(String query, List<PrayerCity> cities) {
  final normalizedQuery = _normalizePrayerLocationName(query);
  if (normalizedQuery.isEmpty) return null;

  for (final city in cities) {
    final normalizedCity = _normalizePrayerLocationName(city.name);
    if (normalizedCity == normalizedQuery ||
        normalizedCity.contains(normalizedQuery) ||
        normalizedQuery.contains(normalizedCity)) {
      return city;
    }
  }
  return null;
}

class GpsPrayerResolver {
  final Geocoding geocoder = Geocoding();

  Future<PrayerCity> resolveCity(PrayerApiClient api) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw GpsPermissionDeniedException(permanentlyDenied: true);
    }
    if (permission == LocationPermission.denied) {
      throw GpsPermissionDeniedException(permanentlyDenied: false);
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw GpsServiceDisabledException();
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );
    final placemarks = await geocoder.placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    final placemark = placemarks.isEmpty ? null : placemarks.first;
    final queries = buildPrayerLocationQueries([
      placemark?.locality,
      placemark?.subAdministrativeArea,
      placemark?.administrativeArea,
    ]);
    if (queries.isEmpty) {
      throw StateError('Nama wilayah tidak dapat ditentukan dari GPS.');
    }

    for (final query in queries) {
      final cities = await api.searchCities(query);
      final city = selectPrayerCity(query, cities);
      if (city != null) return city;
    }

    throw StateError(
      'Wilayah GPS tidak ditemukan pada API QuranX. '
      'Pencarian: ${queries.join(', ')}.',
    );
  }
}
