import 'dart:isolate';
import 'dart:ui';

const _portName = 'taxi_maroc_notification_actions';

/// Les boutons d'une notification arrivent dans un isolate d'arrière-plan : on les renvoie
/// à l'écran chauffeur, qui tourne toujours, par un port nommé.
void listenActions(void Function(String action, String? payload) onAction) {
  final port = ReceivePort();
  IsolateNameServer.removePortNameMapping(_portName);
  IsolateNameServer.registerPortWithName(port.sendPort, _portName);
  port.listen((m) {
    if (m is List && m.length == 2) onAction(m[0] as String, m[1] as String?);
  });
}

void forwardAction(String action, String? payload) =>
    IsolateNameServer.lookupPortByName(_portName)?.send([action, payload]);
