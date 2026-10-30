import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/request_chime.dart';
import '../services/sos.dart';
import '../theme.dart';

/// Caméras du téléphone (remplacées dans les tests, qui n'en ont pas).
@visibleForTesting
Future<List<CameraDescription>> Function() loadCameras = availableCameras;

/// Ouvre l'écran SOS : dès l'ouverture, la caméra filme (image et son) et chaque séquence de quelques
/// secondes part en direct au centre de sécurité Bab Taxi, avec la position.
Future<void> openSos(
  BuildContext context, {
  String? taxiId,
  LatLng Function()? position,
  VoidCallback? onShare,
  bool callPolice = false,
}) =>
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SosScreen(taxiId: taxiId, position: position, onShare: onShare, callPolice: callPolice),
    ));

class SosScreen extends StatefulWidget {
  const SosScreen({
    super.key,
    this.taxiId,
    this.position,
    this.onShare,
    this.callPolice = false,
    this.session,
    this.segmentLength = const Duration(seconds: 8),
  });

  final String? taxiId;
  final LatLng Function()? position;

  /// Partage du trajet aux proches (bouton « Prévenir mes proches »).
  final VoidCallback? onShare;

  /// Parcours vocal : le 19 est appelé juste après le lancement de l'enregistrement.
  final bool callPolice;

  /// Pour les tests (sinon serveur, ou démo sans serveur).
  final SosSession? session;

  /// Durée de chaque séquence envoyée.
  final Duration segmentLength;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with WidgetsBindingObserver {
  late final SosSession _session = widget.session ?? SosSession();
  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _noCamera = false;
  bool _closing = false;

  /// Caméra en cours d'ouverture (la demande d'autorisation met l'application en pause un instant).
  bool _starting = false;
  Timer? _segmentTimer;
  Timer? _positionTimer;
  Timer? _clock;
  Future<void> _cycle = Future.value();

  @override
  void initState() {
    super.initState();
    // Pendant le SOS, aucun son de demande (chauffeur).
    sosActive = true;
    WidgetsBinding.instance.addObserver(this);
    _session.addListener(_refresh);
    _session.start(taxiId: widget.taxiId, position: widget.position?.call());
    _positionTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final p = widget.position?.call();
      if (p != null) _session.updatePosition(p);
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    _startCamera().then((_) {
      if (widget.callPolice && mounted) {
        Future.delayed(const Duration(seconds: 3), () => _call('19'));
      }
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _startCamera() async {
    if (_starting) return;
    _starting = true;
    try {
      if (_cameras.isEmpty) {
        _cameras = await loadCameras();
        // Caméra arrière d'abord : elle filme la scène (le passager peut basculer).
        final back = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
        _cameraIndex = back < 0 ? 0 : back;
      }
      if (_cameras.isEmpty) throw StateError('aucune caméra');
      final c = CameraController(_cameras[_cameraIndex], ResolutionPreset.medium, enableAudio: true);
      await c.initialize();
      if (!mounted || _closing) {
        await c.dispose();
        return;
      }
      await c.startVideoRecording();
      _camera = c;
      _noCamera = false;
      _segmentTimer?.cancel();
      _segmentTimer = Timer.periodic(widget.segmentLength, (_) => _cycle = _cycle.then((_) => _rollSegment()));
    } catch (_) {
      // Pas d'autorisation, pas de caméra (version web, tests) : l'alerte et la position partent quand même.
      _noCamera = true;
    } finally {
      _starting = false;
    }
    _refresh();
  }

  /// Termine la séquence en cours, l'envoie, et repart aussitôt (le trou est d'une fraction de seconde).
  Future<void> _rollSegment({bool restart = true}) async {
    final c = _camera;
    if (c == null || !c.value.isRecordingVideo) return;
    try {
      final file = await c.stopVideoRecording();
      if (restart && !_closing) await c.startVideoRecording();
      _session.addSegment(await file.readAsBytes(), type: videoMime(file.path));
    } catch (_) {}
  }

  Future<void> _stopCamera() async {
    _segmentTimer?.cancel();
    _segmentTimer = null;
    await (_cycle = _cycle.then((_) => _rollSegment(restart: false)));
    final c = _camera;
    _camera = null;
    _refresh();
    await c?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Appel du 19 ou écran éteint : la séquence en cours part ; la caméra reprend au retour.
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_camera != null) _stopCamera();
    } else if (state == AppLifecycleState.resumed && _camera == null && !_noCamera && !_closing) {
      _startCamera();
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    await _stopCamera();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startCamera();
  }

  Future<void> _call(String n) async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: n));
    } catch (_) {}
  }

  Future<void> _finish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('sosStopAsk')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('cancel'))),
          FilledButton(
            key: const ValueKey('sosStopConfirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('sosStop')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _closing = true;
    await _stopCamera();
    await _session.stop();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.pop(context);
    messenger?.showSnackBar(SnackBar(content: Text(s.t('sosEnded'))));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _segmentTimer?.cancel();
    _positionTimer?.cancel();
    _clock?.cancel();
    _session.removeListener(_refresh);
    // Écran fermé sans « Je suis en sécurité » (retour système) : la dernière séquence part quand même.
    final c = _camera;
    _camera = null;
    if (c != null) {
      _cycle.then((_) async {
        try {
          if (c.value.isRecordingVideo) {
            final f = await c.stopVideoRecording();
            _session.addSegment(await f.readAsBytes(), type: videoMime(f.path));
          }
        } catch (_) {}
        await c.dispose();
      });
    }
    if (!_session.ended) _session.stop();
    sosActive = false;
    super.dispose();
  }

  String get _elapsed {
    final d = DateTime.now().difference(_session.startedAt);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = _camera;
    return PopScope(
      // Le retour ne ferme pas l'alerte par erreur : il faut « Je suis en sécurité ».
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(fit: StackFit.expand, children: [
          if (c != null && c.value.isInitialized)
            Center(child: CameraPreview(c))
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_noCamera ? Icons.videocam_off : Icons.videocam, color: Colors.white54, size: 56),
                  const SizedBox(height: 12),
                  Text(s.t(_noCamera ? 'sosNoCamera' : 'sosStarting'),
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                ]),
              ),
            ),
          SafeArea(
            child: Column(children: [
              _banner(),
              const Spacer(),
              _controls(),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _banner() => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: AppColors.taxiRed, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${s.t('sosLive')} · $_elapsed',
                  key: const ValueKey('sosLive'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            ),
          ]),
          Text('${_session.sent} ${s.t('sosSegments')}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          Text(s.t('sosRecording'), style: const TextStyle(color: Colors.white, fontSize: 14)),
          if (_session.failed) ...[
            const SizedBox(height: 4),
            Text(s.t('sosWaitingNetwork'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
          if (_session.demo) ...[
            const SizedBox(height: 4),
            Text(s.t('sosDemo'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ]),
      );

  Widget _controls() => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: const BoxDecoration(
          color: Color(0xCC000000),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.taxiRed, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => _call('19'),
                icon: const Icon(Icons.local_police),
                label: Text(s.t('police')),
              ),
            ),
            if (_cameras.length > 1) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: s.t('switchCamera'),
                onPressed: _switchCamera,
                icon: const Icon(Icons.cameraswitch),
              ),
            ],
          ]),
          if (widget.onShare != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
              onPressed: widget.onShare,
              icon: const Icon(Icons.share_location),
              label: Text(s.t('sosWarnContacts')),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('sosStop'),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.moroccoGreen, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _finish,
            icon: const Icon(Icons.verified_user),
            label: Text(s.t('sosStop')),
          ),
          const SizedBox(height: 8),
          Text(s.t('sosNotice'), style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ]),
      );
}
