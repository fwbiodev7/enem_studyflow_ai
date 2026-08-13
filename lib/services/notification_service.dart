import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  /// Verifica se a permissão de alarme exato está concedida.
  /// Se não estiver, abre a tela de configuração do Android e retorna false.
  Future<bool> requestExactAlarmPermission(BuildContext context) async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return true; // Não é Android, ok.

    final bool? canSchedule = await androidPlugin.canScheduleExactNotifications();
    if (canSchedule == true) return true;

    // Tenta solicitar via flutter_local_notifications
    try {
      await androidPlugin.requestExactAlarmsPermission();
    } catch (_) {}

    // Verifica novamente
    final bool? canScheduleNow =
        await androidPlugin.canScheduleExactNotifications();
    if (canScheduleNow == true) return true;

    // Ainda não concedida: orienta o usuário via diálogo
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.alarm, color: Colors.orange),
            SizedBox(width: 8),
            Text('Permissão de Alarme'),
          ]),
          content: const Text(
            'Para que as notificações de estudo funcionem, o app precisa '
            'da permissão "Alarmes e Lembretes".\n\n'
            'Vá em: Configurações > Aplicativos > ENEM StudyFlow AI '
            '> Alarmes e Lembretes e ative a permissão. '
            'Depois tente gerar o cronograma novamente.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
    return false;
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required BuildContext context,
  }) async {
    // Verificar permissão antes de agendar
    final hasPermission = await requestExactAlarmPermission(context);
    if (!hasPermission) return; // Permissão ainda não concedida, não agenda.

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_channel',
          'Notificações de Estudo',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
