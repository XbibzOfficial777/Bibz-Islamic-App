part of '../main.dart';

const _notificationPrayerNames = <String>[
  'subuh',
  'dzuhur',
  'ashar',
  'maghrib',
  'isya',
];

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key, required this.repository});

  final QuranRepository repository;

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  final api = PrayerApiClient();
  final gps = GpsPrayerResolver();
  final locationController = TextEditingController();
  late final PrayerReminderService reminders;
  PrayerCity? selectedCity;
  PrayerSchedule? schedule;
  List<PrayerCity> searchResults = const [];
  String? error;
  String? locationSearchError;
  bool loading = false;
  bool scheduling = false;
  bool testingAdhan = false;
  bool searchingLocations = false;
  DateTime now = DateTime.now();
  Timer? countdownTimer;
  Timer? searchDebounce;

  @override
  void initState() {
    super.initState();
    reminders = PrayerReminderService(widget.repository.store.preferences);
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
    _restoreSavedLocation();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    searchDebounce?.cancel();
    locationController.dispose();
    api.dispose();
    super.dispose();
  }

  Future<void> _restoreSavedLocation() async {
    await reminders.initialize();
    final savedCity = readSavedPrayerCity(widget.repository.store.preferences);
    if (!mounted || savedCity == null) return;
    await _selectCity(savedCity, clearSearch: false);
  }

  Future<void> _showLocationRecovery(Object value) async {
    if (!mounted) return;
    if (value is GpsServiceDisabledException) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Aktifkan lokasi'),
          content: const Text('GPS perangkat nonaktif.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nanti'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
              child: const Text('Buka pengaturan'),
            ),
          ],
        ),
      );
    } else if (value is GpsPermissionDeniedException &&
        value.permanentlyDenied) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Izin lokasi diperlukan'),
          content: const Text('Aktifkan izin lokasi QuranX di Pengaturan.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
              },
              child: const Text('Buka pengaturan'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _useGps() async {
    setState(() {
      loading = true;
      error = null;
      schedule = null;
    });
    try {
      final city = await gps.resolveCity(api);
      await _selectCity(city);
    } catch (value, stack) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = DiagnosticLog.record(value, stack, context: 'prayer.gps');
      });
      await _showLocationRecovery(value);
    }
  }

  void _onLocationQueryChanged(String value) {
    searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        searchResults = const [];
        locationSearchError = null;
        searchingLocations = false;
      });
      return;
    }
    setState(() {
      searchingLocations = true;
      locationSearchError = null;
    });
    searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchLocations(query);
    });
  }

  Future<void> _searchLocations(String query) async {
    try {
      final results = await api.searchCities(query);
      if (!mounted || locationController.text.trim() != query) return;
      setState(() {
        searchResults = results.take(12).toList();
        searchingLocations = false;
      });
    } catch (value, stack) {
      if (!mounted || locationController.text.trim() != query) return;
      setState(() {
        searchingLocations = false;
        searchResults = const [];
        locationSearchError = DiagnosticLog.record(
          value,
          stack,
          context: 'prayer.location_search',
        );
      });
    }
  }

  Future<void> _selectCity(PrayerCity city, {bool clearSearch = true}) async {
    final cityId = int.tryParse(city.id);
    if (cityId == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (clearSearch) locationController.clear();
    setState(() {
      selectedCity = city;
      searchResults = const [];
      locationSearchError = null;
      loading = true;
      error = null;
      schedule = null;
    });
    try {
      final loaded = await api.fetchSchedule(cityId, DateTime.now());
      await savePrayerCity(
        widget.repository.store.preferences,
        city,
        regionName: loaded.regionName,
      );
      if (!mounted) return;
      setState(() {
        schedule = loaded;
        loading = false;
        now = DateTime.now();
      });
    } catch (value, stack) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = DiagnosticLog.record(
          value,
          stack,
          context: 'prayer.schedule.$cityId',
        );
      });
    }
  }

  Future<void> _testAdhan() async {
    setState(() => testingAdhan = true);
    try {
      await reminders.showAdhanTest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifikasi uji audio dikirim.')),
        );
      }
    } catch (value, stack) {
      if (mounted) {
        setState(
          () => error = DiagnosticLog.record(
            value,
            stack,
            context: 'prayer.notification_sound_test',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => testingAdhan = false);
    }
  }

  Future<void> _scheduleReminders() async {
    final value = schedule;
    if (value == null) return;
    setState(() => scheduling = true);
    try {
      await reminders.scheduleSevenDays(api, value.cityId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifikasi sholat aktif.')),
        );
      }
    } catch (value, stack) {
      if (mounted) {
        setState(
          () => error = DiagnosticLog.record(
            value,
            stack,
            context: 'prayer.schedule_notifications',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => scheduling = false);
    }
  }

  PrayerMoment? _nextPrayer() {
    final value = schedule;
    if (value == null) return null;
    return findNextPrayer(value, now);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Jadwal Sholat')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Lokasi'),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: loading ? null : _useGps,
          icon: const Icon(Icons.my_location),
          label: Text(loading ? 'Memperbarui…' : 'Perbarui Lokasi'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: locationController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Cari kota atau kabupaten',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: _onLocationQueryChanged,
        ),
        if (searchingLocations)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (locationSearchError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              locationSearchError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (searchResults.isNotEmpty)
          Card(
            child: Column(
              children: searchResults
                  .map(
                    (city) => ListTile(
                      title: Text(city.name),
                      leading: const Icon(Icons.location_city_outlined),
                      onTap: () => _selectCity(city),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (selectedCity != null) ...[
          const SizedBox(height: 16),
          Text(
            selectedCity!.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (schedule != null) ...[
            Text(
              '${schedule!.regionName} • ${schedule!.date.toIso8601String().substring(0, 10)}',
            ),
            const SizedBox(height: 8),
            _PrayerCountdown(moment: _nextPrayer(), now: now),
            Card(
              child: Column(
                children: _notificationPrayerNames
                    .map((name) => _PrayerTimeRow(name: name))
                    .toList(),
              ),
            ),
            FilledButton.icon(
              onPressed: scheduling ? null : _scheduleReminders,
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(
                scheduling ? 'Menjadwalkan…' : 'Aktifkan notifikasi sholat',
              ),
            ),
            OutlinedButton.icon(
              onPressed: testingAdhan ? null : _testAdhan,
              icon: const Icon(Icons.volume_up_outlined),
              label: Text(testingAdhan ? 'Mengirim…' : 'Uji audio adzan'),
            ),
            const SizedBox(height: 4),
            const Text(
              'Notifikasi memakai audio adzan.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ],
    ),
  );
}

class PrayerMoment {
  const PrayerMoment({required this.name, required this.time});

  final String name;
  final DateTime time;
}

PrayerMoment? findNextPrayer(PrayerSchedule schedule, DateTime now) {
  final currentDate = DateTime(now.year, now.month, now.day);
  final scheduleDate = DateTime(
    schedule.date.year,
    schedule.date.month,
    schedule.date.day,
  );
  if (scheduleDate != currentDate) return null;

  for (final name in _notificationPrayerNames) {
    final parts = schedule.times[name]!.split(':');
    final target = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    if (target.isAfter(now)) {
      return PrayerMoment(name: name, time: target);
    }
  }
  return null;
}

String formatPrayerCountdown(Duration remaining) {
  final seconds = remaining.inSeconds.clamp(0, 86399);
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final secondsText = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours jam $minutes menit $secondsText detik';
}

class _PrayerCountdown extends StatelessWidget {
  const _PrayerCountdown({required this.moment, required this.now});

  final PrayerMoment? moment;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (moment == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.check_circle_outline),
          title: Text('Jadwal sholat hari ini selesai'),
        ),
      );
    }
    final countdown = formatPrayerCountdown(moment!.time.difference(now));
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.timer_outlined),
        title: Text(
          'Adzan berikutnya: ${PrayerReminderService._displayName(moment!.name)}',
        ),
        subtitle: Text(
          '$countdown • ${moment!.time.hour.toString().padLeft(2, '0')}:${moment!.time.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
}

class _PrayerTimeRow extends StatelessWidget {
  const _PrayerTimeRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_PrayerSettingsScreenState>();
    final time = state?.schedule?.times[name] ?? '--:--';
    return ListTile(
      leading: const Icon(Icons.access_time),
      title: Text(PrayerReminderService._displayName(name)),
      trailing: Text(time, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
