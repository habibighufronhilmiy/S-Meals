import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Layanan notifikasi lokal untuk pengingat makan & minum.
///
/// Ringan: hanya menjadwalkan notifikasi harian berulang, tanpa server
/// push. Pengingat dijadwalkan di zona waktu perangkat.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'sona_reminders';
  static const _channelName = 'Pengingat Sona';
  static const _channelDesc = 'Pengingat makan, minum, dan catat gizi';

  // Id notifikasi tetap supaya bisa dibatalkan/dijadwalkan ulang.
  static const idSarapan = 1001;
  static const idMakanSiang = 1002;
  static const idMakanMalam = 1003;
  static const idAir = 1004;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (_) {
      // Biarkan default bila zona tak tersedia.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  Future<void> _scheduleDaily(
    int id,
    int hour,
    int minute,
    String title,
    String body,
  ) async {
    await init();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOf(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Jadwalkan semua pengingat standar (sarapan, makan siang, makan malam, air).
  Future<void> scheduleDefaults() => scheduleReminders(const {});

  /// Jadwalkan pengingat harian sesuai jam tersimpan.
  ///
  /// [times] memetakan kunci ('sarapan'|'siang'|'malam'|'air') ke 'HH:mm'.
  /// Kunci yang tidak ada memakai jam default. Bila jam kosong/tidak valid,
  /// dipakai jam default per kunci.
  Future<void> scheduleReminders(Map<String, String> times) async {
    Future<void> one(
      int id,
      String key,
      String fallbackHhmm,
      String title,
      String body,
    ) async {
      final hhmm = times[key] ?? fallbackHhmm;
      final parts = hhmm.split(':');
      final hour = int.tryParse(parts[0]) ?? int.parse(fallbackHhmm.split(':')[0]);
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
      await _scheduleDaily(id, hour, minute, title, body);
    }

    await one(idSarapan, 'sarapan', '07:00', 'Waktunya sarapan',
        'Jangan lupa sarapan biar energimu cukup.');
    await one(idMakanSiang, 'siang', '12:30', 'Waktunya makan siang',
        'Luangkan waktu buat makan siang yang seimbang ya.');
    await one(idMakanMalam, 'malam', '19:00', 'Waktunya makan malam',
        'Pilih makan malam ringan & cukup buat kebutuhanmu.');
    await one(idAir, 'air', '10:00', 'Saatnya minum air',
        'Yuk, minum segelas air buat jaga hidrasi.');
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancel(idSarapan);
    await _plugin.cancel(idMakanSiang);
    await _plugin.cancel(idMakanMalam);
    await _plugin.cancel(idAir);
  }
}
