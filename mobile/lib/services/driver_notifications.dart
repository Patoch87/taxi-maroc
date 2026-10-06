import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'background/action_port_stub.dart' if (dart.library.isolate) 'background/action_port_io.dart';

const acceptAction = 'accept';
const declineAction = 'decline';

/// Bouton touché dans la notification alors que l'application est en arrière-plan (Waze, Google Maps).
@pragma('vm:entry-point')
void onBackgroundNotificationAction(NotificationResponse r) {
  if (r.actionId != null) forwardAction(r.actionId!, r.payload);
}

/// Notifications système du chauffeur quand il navigue dans Waze ou Google Maps : nouvelle demande
/// sur sa route (avec Accepter / Refuser directement dans la notification) et feux de détresse à 50 m.
/// Dans l'application, les fenêtres habituelles suffisent : rien n'est envoyé.
class DriverNotifications with WidgetsBindingObserver {
  DriverNotifications._();
  static final instance = DriverNotifications._();

  static const requestId = 1;
  static const hazardId = 2;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _observing = false;
  AppLifecycleState _state = AppLifecycleState.resumed;

  /// Reçoit « accept » ou « decline » et l'identifiant de la demande.
  void Function(String action, String? payload)? onAction;

  /// Remplaçable dans les tests : notifications envoyées (titre, texte, avec boutons).
  @visibleForTesting
  void Function(int id, String title, String body, bool withActions)? debugShow;
  @visibleForTesting
  AppLifecycleState? debugState;

  bool get inBackground => (debugState ?? _state) != AppLifecycleState.resumed;

  Future<void> init() async {
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    if (_ready || kIsWeb || defaultTargetPlatform != TargetPlatform.android || debugShow != null) return;
    _ready = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (r) {
          if (r.actionId != null) onAction?.call(r.actionId!, r.payload);
        },
        onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationAction,
      );
      listenActions((a, p) => onAction?.call(a, p));
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {
      _ready = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _state = state;

  Future<void> showRequest({
    required String key,
    required String title,
    required String body,
    required String accept,
    required String decline,
  }) =>
      _show(requestId, title, body, payload: key, actions: [
        AndroidNotificationAction(acceptAction, accept, cancelNotification: true),
        AndroidNotificationAction(declineAction, decline, cancelNotification: true),
      ]);

  Future<void> showHazard({required String title, required String body}) => _show(hazardId, title, body);

  Future<void> _show(int id, String title, String body,
      {String? payload, List<AndroidNotificationAction>? actions}) async {
    if (!inBackground) return;
    final test = debugShow;
    if (test != null) return test(id, title, body, actions != null);
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'driver_requests',
            'Demandes sur ma route',
            channelDescription: 'Passagers à prendre pendant la navigation dans Waze ou Google Maps',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.call,
            // Le son doux et la voix arabe de l'application jouent déjà.
            playSound: false,
            timeoutAfter: 30000,
            actions: actions,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }
}
