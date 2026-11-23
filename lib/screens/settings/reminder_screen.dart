import 'package:flutter/material.dart';

import '../../data/sona_store.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sona_components.dart';

/// Layar pengaturan pengingat (notifikasi lokal).
class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key, required this.store});

  final SonaStore store;

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  bool _enabled = false;
  late Map<String, String> _times;

  @override
  void initState() {
    super.initState();
    _enabled = widget.store.remindersEnabled;
    _times = widget.store.reminderTimes;
  }

  Future<void> _toggle(bool value) async {
    final svc = NotificationService.instance;
    if (value) {
      final granted = await svc.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin notifikasi ditolak. Aktifkan di pengaturan HP.'),
          ),
        );
        return;
      }
      await svc.cancelAll();
      await svc.scheduleReminders(widget.store.reminderTimes);
    } else {
      await svc.cancelAll();
    }
    await widget.store.setRemindersEnabled(value);
    if (mounted) setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Pengingat'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(SonaSpacing.margin),
        children: [
          SonaCard(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: SonaColors.emeraldTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active,
                      color: SonaColors.primary),
                ),
                const SizedBox(width: SonaSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pengingat harian',
                          style: Theme.of(context).textTheme.titleSmall),
                      Text('Sarapan, makan siang, makan malam & minum air',
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: _toggle,
                  activeThumbColor: SonaColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: SonaSpacing.md),
          if (_enabled) ...[
            _reminderTile(Icons.wb_twilight, 'Sarapan', 'sarapan'),
            _reminderTile(Icons.lunch_dining, 'Makan siang', 'siang'),
            _reminderTile(Icons.dinner_dining, 'Makan malam', 'malam'),
            _reminderTile(Icons.water_drop, 'Minum air', 'air'),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: SonaSpacing.md),
              child: Text(
                'Nyalakan pengingat agar Sona mengingatkanmu makan & minum '
                'setiap hari. Pengingat berjalan di HP, tanpa internet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _reminderTile(IconData icon, String label, String key) {
    final time = _times[key] ?? SonaStore.defaultReminderTimes[key] ?? '07:00';
    return Padding(
      padding: const EdgeInsets.only(bottom: SonaSpacing.sm),
      child: SonaCard(
        onTap: () => _pickTime(key, label, time),
        child: Row(
          children: [
            Icon(icon,
                color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: SonaSpacing.sm),
            Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      )),
            ),
            Text(time,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(String key, String label, String current) async {
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 7,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null || !mounted) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await widget.store.setReminderTime(key, formatted);
    if (!mounted) return;
    setState(() => _times = widget.store.reminderTimes);
    if (_enabled) {
      // Jadwalkan ulang langsung agar waktu baru berlaku tanpa restart.
      final svc = NotificationService.instance;
      await svc.cancelAll();
      await svc.scheduleReminders(widget.store.reminderTimes);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label diatur ke $formatted.')),
    );
  }
}
