part of '../main.dart';

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key, required this.repository});

  final QuranRepository repository;

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  final api = PrayerApiClient();
  final gps = GpsPrayerResolver();
  late final PrayerReminderService reminders;
  PrayerCity? selectedCity;
  PrayerSchedule? schedule;
  String? error;
  bool loading = false;
  bool scheduling = false;

  @override
  void initState() {
    super.initState();
    reminders = PrayerReminderService(widget.repository.store.preferences);
    reminders.initialize();
  }

  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }

  Future<void> _showLocationRecovery(Object value) async {
    if (!mounted) return;
    if (value is GpsServiceDisabledException) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Aktifkan lokasi perangkat'),
          content: const Text(
            'GPS perangkat sedang nonaktif. Aktifkan layanan lokasi agar QuranX dapat membaca wilayah Anda, lalu kembali ke aplikasi dan tekan Gunakan lokasi GPS saya lagi.',
          ),
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
              child: const Text('Buka pengaturan lokasi'),
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
          content: const Text(
            'Izin lokasi QuranX ditolak permanen. Aktifkan izin lokasi dari Pengaturan aplikasi untuk menggunakan jadwal sholat berbasis GPS.',
          ),
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
              child: const Text('Buka pengaturan aplikasi'),
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

  Future<void> _selectCity(PrayerCity city) async {
    final cityId = int.tryParse(city.id);
    if (cityId == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      selectedCity = city;
      loading = true;
      error = null;
      schedule = null;
    });
    try {
      final loaded = await api.fetchSchedule(cityId, DateTime.now());
      if (!mounted) return;
      setState(() {
        schedule = loaded;
        loading = false;
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

  Future<void> _scheduleReminders() async {
    final value = schedule;
    if (value == null) return;
    setState(() => scheduling = true);
    try {
      await reminders.scheduleSevenDays(api, value.cityId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifikasi Subuh, Dzuhur, Ashar, Maghrib, dan Isya dijadwalkan.',
            ),
          ),
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Jadwal Sholat')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Lokasi jadwal sholat diambil dari GPS perangkat, lalu dicocokkan dengan katalog kota pada API QuranX.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: loading ? null : _useGps,
          icon: const Icon(Icons.my_location),
          label: Text(
            loading ? 'Mendapatkan lokasi…' : 'Gunakan lokasi GPS saya',
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'QuranX menggunakan nama wilayah hasil reverse-geocoding hanya untuk mencari cityId; jadwal tetap diambil dari API QuranX yang sama.',
          style: TextStyle(fontSize: 12),
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
          const SizedBox(height: 20),
          Text(
            selectedCity!.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (schedule != null) ...[
            Text(
              '${schedule!.regionName} • ${schedule!.date.toIso8601String().substring(0, 10)}',
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: const [
                  'subuh',
                  'dzuhur',
                  'ashar',
                  'maghrib',
                  'isya',
                ].map((name) => _PrayerTimeRow(name: name)).toList(),
              ),
            ),
            FilledButton.icon(
              onPressed: scheduling ? null : _scheduleReminders,
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(
                scheduling ? 'Menjadwalkan…' : 'Aktifkan notifikasi sholat',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Suara adzan pilihan belum ditampilkan karena API yang sama belum menyediakan katalog audio adzan terverifikasi.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ],
    ),
  );
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
