part of '../main.dart';

class PrayerCity {
  const PrayerCity({required this.id, required this.name});

  final String id;
  final String name;

  factory PrayerCity.fromJson(Map<String, dynamic> json) => PrayerCity(
    id: '${json['id']}',
    name: json['lokasi'] as String? ?? 'Wilayah tidak bernama',
  );
}

class PrayerSchedule {
  const PrayerSchedule({
    required this.cityId,
    required this.cityName,
    required this.regionName,
    required this.date,
    required this.times,
  });

  final int cityId;
  final String cityName;
  final String regionName;
  final DateTime date;
  final Map<String, String> times;

  static const names = <String>[
    'imsak',
    'subuh',
    'terbit',
    'dhuha',
    'dzuhur',
    'ashar',
    'maghrib',
    'isya',
  ];

  factory PrayerSchedule.fromApi(
    Map<String, dynamic> body, {
    required int requestedCityId,
    required DateTime requestedDate,
  }) {
    if (body['success'] != true) {
      throw ApiException(
        body['message'] as String? ?? 'Jadwal sholat gagal dimuat',
      );
    }
    final data = Map<String, dynamic>.from(body['data'] as Map);
    if (data['isLiveDataFromInternet'] != true || data['schedule'] is! Map) {
      throw const FormatException(
        'Respons bukan jadwal Kemenag live untuk kota yang dipilih',
      );
    }
    final city = Map<String, dynamic>.from(data['cityInfo'] as Map);
    final cityId = int.tryParse('${city['id']}');
    if (cityId == null || cityId != requestedCityId) {
      throw const FormatException('Kota pada respons API tidak sesuai pilihan');
    }
    final rawSchedule = Map<String, dynamic>.from(data['schedule'] as Map);
    final isoDate = rawSchedule['date'] as String?;
    final date = isoDate == null ? null : DateTime.tryParse(isoDate);
    if (date == null ||
        date.year != requestedDate.year ||
        date.month != requestedDate.month ||
        date.day != requestedDate.day) {
      throw const FormatException('Tanggal jadwal API tidak sesuai permintaan');
    }
    final times = <String, String>{};
    for (final name in names) {
      final value = rawSchedule[name];
      if (value is! String || !RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) {
        throw FormatException('Waktu sholat $name tidak valid');
      }
      times[name] = value;
    }
    return PrayerSchedule(
      cityId: cityId,
      cityName: city['lokasi'] as String? ?? 'Wilayah tidak bernama',
      regionName: city['daerah'] as String? ?? '',
      date: DateTime(date.year, date.month, date.day),
      times: times,
    );
  }
}

class PrayerApiClient {
  PrayerApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<PrayerCity>> searchCities(String query) async {
    final encoded = Uri.encodeQueryComponent(query.trim());
    final response = await _client
        .get(Uri.parse('$apiBaseUrl/falak/cities?q=$encoded'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw ApiException('Daftar kota gagal: HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw ApiException(body['message'] as String? ?? 'Daftar kota gagal');
    }
    final data = Map<String, dynamic>.from(body['data'] as Map);
    return (data['cities'] as List)
        .map(
          (item) => PrayerCity.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<PrayerSchedule> fetchSchedule(int cityId, DateTime date) async {
    final dateText =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final response = await _client
        .get(
          Uri.parse(
            '$apiBaseUrl/falak/prayer-times?cityId=$cityId&date=$dateText',
          ),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw ApiException('Jadwal sholat gagal: HTTP ${response.statusCode}');
    }
    return PrayerSchedule.fromApi(
      jsonDecode(response.body) as Map<String, dynamic>,
      requestedCityId: cityId,
      requestedDate: date,
    );
  }

  void dispose() => _client.close();
}

const _adhanChannelId = 'quranx_prayer_adhan_v3';
const _fallbackPrayerChannelId = 'quranx_prayer_default_v2';

class PrayerReminderService {
  PrayerReminderService(this.preferences);

  final SharedPreferences preferences;
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  bool _timezoneConfigured = false;
  bool? _customAdhanSoundUsable;
  bool _customAdhanWarningRecorded = false;
  Future<void>? _initializing;

  Future<void> initialize() {
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    tz.initializeTimeZones();
    await _syncDeviceTimezone();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await plugin.initialize(settings: settings);
  }

  Future<void> _syncDeviceTimezone() async {
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
      _timezoneConfigured = true;
    } catch (value, stack) {
      final deviceOffset = DateTime.now().timeZoneOffset;
      final abbreviation = DateTime.now().timeZoneName;
      tz.setLocalLocation(
        tz.Location('QuranX/device-offset', const <int>[], const <int>[], [
          tz.TimeZone(
            deviceOffset,
            isDst: false,
            abbreviation: abbreviation.isEmpty ? 'LOCAL' : abbreviation,
          ),
        ]),
      );
      _timezoneConfigured = true;
      DiagnosticLog.recordWarning(
        'Timezone IANA perangkat tidak dapat dibaca; QuranX memakai offset lokal saat ini.',
        context: 'prayer.timezone',
        stack: stack,
      );
    }
  }

  tz.TZDateTime _now() {
    final current = DateTime.now();
    return _timezoneConfigured
        ? tz.TZDateTime.now(tz.local)
        : tz.TZDateTime.from(current, tz.local);
  }

  tz.TZDateTime _atDeviceLocalTime(DateTime date, int hour, int minute) {
    final localDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    return _timezoneConfigured
        ? tz.TZDateTime(tz.local, date.year, date.month, date.day, hour, minute)
        : tz.TZDateTime.from(localDateTime, tz.local);
  }

  Future<bool> requestNotificationPermission() async {
    await initialize();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  int _notificationId(String name, int dayOffset) =>
      5000 + dayOffset * 10 + PrayerSchedule.names.indexOf(name);

  AndroidNotificationDetails get _androidDetails =>
      const AndroidNotificationDetails(
        _adhanChannelId,
        'Adzan dan Jadwal Sholat QuranX',
        channelDescription: 'Pengingat waktu sholat QuranX dengan audio adzan',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('quranx_adhan'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
      );

  AndroidNotificationDetails get _fallbackDetails =>
      const AndroidNotificationDetails(
        _fallbackPrayerChannelId,
        'Jadwal Sholat QuranX',
        channelDescription:
            'Pengingat waktu sholat QuranX dengan suara sistem perangkat',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        playSound: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
      );

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String payload,
  }) async {
    final notificationDetails = NotificationDetails(
      android: _customAdhanSoundUsable == false
          ? _fallbackDetails
          : _androidDetails,
    );
    try {
      await plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      _customAdhanSoundUsable ??= true;
    } catch (value, stack) {
      if (_customAdhanSoundUsable == false) rethrow;
      _customAdhanSoundUsable = false;
      if (!_customAdhanWarningRecorded) {
        _customAdhanWarningRecorded = true;
        DiagnosticLog.recordWarning(
          'Audio adzan bundled tidak dapat dipakai oleh Android; notifikasi dilanjutkan dengan suara sistem.',
          context: 'prayer.notification_sound',
          stack: stack,
        );
      }
      await plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(android: _fallbackDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  Future<void> showAdhanTest() async {
    await initialize();
    final granted = await requestNotificationPermission();
    if (!granted) {
      throw const FileSystemException(
        'Izin notifikasi belum diberikan untuk uji audio adzan.',
      );
    }
    await plugin.show(
      id: 4999,
      title: 'Tes audio adzan',
      body: 'Jika suara aktif, audio adzan akan terdengar sekarang.',
      notificationDetails: NotificationDetails(android: _androidDetails),
    );
  }

  Future<void> schedule(
    PrayerSchedule schedule, {
    int leadMinutes = 0,
    int dayOffset = 0,
    bool clearExisting = true,
  }) async {
    await initialize();
    final granted = await requestNotificationPermission();
    if (!granted) {
      throw const FileSystemException(
        'Izin notifikasi belum diberikan untuk pengingat sholat.',
      );
    }
    if (clearExisting) await plugin.cancelAll();
    final now = _now();
    for (final name in const ['subuh', 'dzuhur', 'ashar', 'maghrib', 'isya']) {
      final parts = schedule.times[name]!.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        throw const FormatException('Komponen waktu sholat tidak valid');
      }
      final base = _atDeviceLocalTime(schedule.date, hour, minute);
      final scheduled = base.subtract(Duration(minutes: leadMinutes));
      if (!scheduled.isAfter(now)) continue;
      await _scheduleNotification(
        id: _notificationId(name, dayOffset),
        title: 'Notifikasi Sholat ${_displayName(name)}',
        body:
            '${_displayName(name)} ${schedule.times[name]} • ${schedule.cityName}',
        scheduledDate: scheduled,
        payload: '${schedule.cityId}|${schedule.date.toIso8601String()}|$name',
      );
    }
    await preferences.setString('prayer_city_id', '${schedule.cityId}');
    await preferences.setString('prayer_city_name', schedule.cityName);
    await preferences.setString(
      'prayer_schedule_date',
      schedule.date.toIso8601String(),
    );
  }

  Future<void> scheduleSevenDays(
    PrayerApiClient api,
    int cityId, {
    int leadMinutes = 0,
  }) async {
    await initialize();
    final granted = await requestNotificationPermission();
    if (!granted) {
      throw const FileSystemException(
        'Izin notifikasi belum diberikan untuk pengingat sholat.',
      );
    }
    await _syncDeviceTimezone();
    await plugin.cancelAll();
    final today = DateTime.now();
    PrayerSchedule? first;
    for (var offset = 0; offset < 7; offset++) {
      final date = DateTime(today.year, today.month, today.day + offset);
      final value = await api.fetchSchedule(cityId, date);
      first ??= value;
      await schedule(
        value,
        leadMinutes: leadMinutes,
        dayOffset: offset,
        clearExisting: false,
      );
    }
    if (first != null) {
      await preferences.setString('prayer_city_id', '$cityId');
      await preferences.setString('prayer_city_name', first.cityName);
    }
  }

  Future<void> cancel() async {
    await initialize();
    await plugin.cancelAll();
  }

  static String _displayName(String name) {
    switch (name) {
      case 'subuh':
        return 'Subuh';
      case 'dzuhur':
        return 'Dzuhur';
      case 'ashar':
        return 'Ashar';
      case 'maghrib':
        return 'Maghrib';
      case 'isya':
        return 'Isya';
      default:
        return name[0].toUpperCase() + name.substring(1);
    }
  }

  void dispose() {}
}
