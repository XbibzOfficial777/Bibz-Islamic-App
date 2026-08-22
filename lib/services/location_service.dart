part of '../main.dart';

class GpsPrayerResolver {
  final Geocoding geocoder = Geocoding();

  Future<PrayerCity> resolveCity(PrayerApiClient api) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Layanan lokasi/GPS perangkat sedang nonaktif.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Izin lokasi diperlukan untuk jadwal sholat otomatis.');
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
    final query =
        [
          placemark?.locality,
          placemark?.subAdministrativeArea,
          placemark?.administrativeArea,
        ].whereType<String>().firstWhere(
          (value) => value.trim().isNotEmpty,
          orElse: () => '',
        );
    if (query.isEmpty) {
      throw StateError('Nama wilayah tidak dapat ditentukan dari GPS.');
    }
    final cities = await api.searchCities(query);
    if (cities.isEmpty) {
      throw StateError('Wilayah GPS "$query" tidak ditemukan pada API QuranX.');
    }
    final normalized = query.toLowerCase();
    return cities.firstWhere(
      (city) => city.name.toLowerCase().contains(normalized),
      orElse: () => cities.first,
    );
  }
}
