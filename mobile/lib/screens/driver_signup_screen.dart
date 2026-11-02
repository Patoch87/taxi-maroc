import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../services/account.dart';
import '../services/driver_profile.dart';
import '../theme.dart';
import 'driver_home.dart';

/// Application « Bab Taxi Chauffeur » : inscription du chauffeur, puis attente de la validation par
/// Bab Taxi, puis le mode chauffeur. Comme Uber Driver : aucune course sans dossier vérifié.
class DriverGate extends StatefulWidget {
  const DriverGate({super.key, this.api});
  final DriverApi? api;

  @override
  State<DriverGate> createState() => _DriverGateState();
}

class _DriverGateState extends State<DriverGate> {
  late final DriverApi _api = widget.api ?? DriverApi();
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (!driverProfileStore.loaded) await driverProfileStore.load();
    final id = accountStore.account?.id;
    if (id != null) await driverProfileStore.refresh(_api, id);
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: driverProfileStore,
      builder: (context, _) {
        final p = driverProfileStore.profile;
        if (_checking && p.status != DriverStatus.approved) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (p.status == DriverStatus.approved) return const DriverHome(driverApp: true);
        return DriverSignupScreen(api: _api, onRefresh: _check);
      },
    );
  }
}

class DriverSignupScreen extends StatefulWidget {
  const DriverSignupScreen({super.key, required this.api, required this.onRefresh});
  final DriverApi api;
  final Future<void> Function() onRefresh;

  @override
  State<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends State<DriverSignupScreen> {
  DriverProfile get _p => driverProfileStore.profile;
  final _thumbs = <String, Uint8List>{};
  final _uploading = <String>{};
  final _failed = <String>{};
  bool _sending = false;
  bool _refreshing = false;
  String? _error;

  /// Dossier envoyé et en attente : écran d'attente, sauf si le chauffeur veut le modifier.
  bool _editing = false;

  late final _cin = TextEditingController(text: _p.cin);
  late final _license = TextEditingController(text: _p.license);
  late final _proCard = TextEditingController(text: _p.proCard);
  late final _taxiNumber = TextEditingController(text: _p.taxiNumber);
  late final _plate = TextEditingController(text: _p.plate);

  static const _languages = {
    'dr': '🇲🇦 Darija',
    'ar': 'العربية',
    'zgh': 'ⵜⴰⵎⴰⵣⵉⵖⵜ',
    'fr': '🇫🇷 Français',
    'en': '🇬🇧 English',
    'es': '🇪🇸 Español',
  };

  @override
  void dispose() {
    for (final c in [_cin, _license, _proCard, _taxiNumber, _plate]) {
      c.dispose();
    }
    super.dispose();
  }

  String _label(String piece) => s.t(switch (piece) {
        'photo' => 'dsPhoto',
        'cinRecto' => 'dsCinFront',
        'cinVerso' => 'dsCinBack',
        'permis' => 'dsLicensePhoto',
        'cartePro' => 'dsProCardPhoto',
        'casier' => 'dsRecord',
        _ => 'dsVehiclePhoto',
      });

  void _saveFields() {
    _p
      ..cin = _cin.text
      ..license = _license.text
      ..proCard = _proCard.text
      ..taxiNumber = _taxiNumber.text
      ..plate = _plate.text;
    driverProfileStore.save();
  }

  Future<void> _pick(String piece) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(s.t('dsTakePhoto')),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(s.t('dsFromGallery')),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final XFile? f;
    try {
      f = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
        preferredCameraDevice: piece == 'photo' ? CameraDevice.front : CameraDevice.rear,
      );
    } catch (_) {
      return;
    }
    if (f == null || !mounted) return;
    final bytes = await f.readAsBytes();
    setState(() {
      _thumbs[piece] = bytes;
      _uploading.add(piece);
      _failed.remove(piece);
    });
    await _upload(piece, bytes);
  }

  Future<void> _upload(String piece, Uint8List bytes) async {
    final id = accountStore.account?.id;
    if (id == null) return;
    try {
      final fid = await widget.api.uploadPiece(id, piece, bytes);
      _p.pieces[piece] = fid;
      await driverProfileStore.save();
    } catch (_) {
      _failed.add(piece);
    }
    if (mounted) setState(() => _uploading.remove(piece));
  }

  Future<void> _submit() async {
    _saveFields();
    final a = accountStore.account;
    if (a == null || !_p.complete) {
      setState(() => _error = s.t('dsMissing'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final r = await widget.api.submit(a.id, _p.toServer(a.firstName, a.lastName));
      _p
        ..status = r['statut'] == 'valide' ? DriverStatus.approved : DriverStatus.pending
        ..reason = null;
      await driverProfileStore.save();
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      final msg = '$e';
      // Une pièce a disparu du serveur (base remise à zéro) : on la redemande.
      for (final piece in driverPieces) {
        if (msg.contains(piece)) _p.pieces.remove(piece);
      }
      await driverProfileStore.save();
      if (mounted) setState(() => _error = s.t('dsSendFailed'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await widget.onRefresh();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _p.status == DriverStatus.pending && !_editing;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('driverSignupTitle')),
        backgroundColor: AppColors.sand,
        actions: [
          IconButton(
            tooltip: s.t('dsRefresh'),
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: pending ? _pendingView() : _form()),
    );
  }

  Widget _pendingView() => ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 24),
        const Icon(Icons.hourglass_top_rounded, size: 72, color: AppColors.gold),
        const SizedBox(height: 16),
        Text(s.t('dsPendingTitle'),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(s.t('dsPendingBody'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.4)),
        const SizedBox(height: 28),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: _refreshing ? null : _refresh,
          icon: _refreshing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.refresh),
          label: Text(s.t('dsRefresh')),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: () => setState(() => _editing = true),
          icon: const Icon(Icons.edit_outlined),
          label: Text(s.t('dsEdit')),
        ),
      ]);

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      );

  Widget _field(TextEditingController c, String label, {String? hint, TextCapitalization caps = TextCapitalization.characters}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          textCapitalization: caps,
          onChanged: (_) => _saveFields(),
          decoration: InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: Colors.white),
        ),
      );

  Widget _tile(String piece, {String? hint}) {
    final done = _p.pieces.containsKey(piece);
    final busy = _uploading.contains(piece);
    final failed = _failed.contains(piece);
    final thumb = _thumbs[piece];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('piece-$piece'),
          borderRadius: BorderRadius.circular(14),
          onTap: busy ? null : () => _pick(piece),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: failed ? AppColors.taxiRed : (done ? AppColors.moroccoGreen : AppColors.line), width: 1.5),
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 56,
                  height: 56,
                  color: AppColors.sandDeep,
                  child: thumb != null
                      ? Image.memory(thumb, fit: BoxFit.cover)
                      : Icon(piece == 'photo' ? Icons.face_outlined : Icons.add_a_photo_outlined, color: AppColors.muted),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_label(piece), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  if (failed)
                    Text(s.t('dsUploadFailed'), style: const TextStyle(color: AppColors.taxiRed, fontSize: 13))
                  else if (hint != null)
                    Text(hint, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ]),
              ),
              if (busy)
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              else
                Icon(done ? Icons.check_circle : Icons.chevron_right,
                    color: done ? AppColors.moroccoGreen : AppColors.muted),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final a = accountStore.account;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      if (_p.status == DriverStatus.rejected)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.redSoft, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.t('dsRejectedTitle'),
                style: const TextStyle(color: AppColors.taxiRed, fontWeight: FontWeight.w800, fontSize: 16)),
            if ((_p.reason ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_p.reason!, style: const TextStyle(fontSize: 15)),
            ],
          ]),
        ),
      Text(s.t('driverSignupIntro'), style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.muted)),
      _section(s.t('dsYou')),
      if (a != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('${a.firstName} ${a.lastName} · ${a.phone}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      _tile('photo', hint: s.t('dsPhotoHint')),
      Text(s.t('dsLanguages'), style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in _languages.entries)
          FilterChip(
            label: Text(e.value),
            selected: _p.languages.contains(e.key),
            onSelected: (v) {
              setState(() => v ? _p.languages.add(e.key) : _p.languages.remove(e.key));
              driverProfileStore.save();
            },
          ),
      ]),
      _section(s.t('dsIdentity')),
      _field(_cin, s.t('dsCin'), hint: 'BE123456'),
      _tile('cinRecto'),
      _tile('cinVerso'),
      _field(_license, s.t('dsLicense')),
      _tile('permis'),
      _field(_proCard, s.t('dsProCard')),
      _tile('cartePro'),
      _tile('casier', hint: s.t('dsRecordHint')),
      _section(s.t('dsTaxi')),
      SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: false, label: Text(s.t('petitTaxi'))),
          ButtonSegment(value: true, label: Text(s.t('grandTaxi'))),
        ],
        selected: {_p.grand},
        onSelectionChanged: (v) {
          setState(() => _p.grand = v.first);
          driverProfileStore.save();
        },
      ),
      const SizedBox(height: 10),
      _field(_taxiNumber, s.t('dsTaxiNumber'), hint: '2417'),
      _field(_plate, s.t('dsPlate'), hint: '12345 | أ | 6'),
      _tile('vehicule'),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: const TextStyle(color: AppColors.taxiRed, fontWeight: FontWeight.w600)),
        ),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const ValueKey('submitDriver'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        onPressed: _sending || _uploading.isNotEmpty ? null : _submit,
        icon: _sending
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send_rounded),
        label: Text(s.t('dsSubmit'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: 10),
      Text(s.t('dsPrivacy'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    ]);
  }
}
