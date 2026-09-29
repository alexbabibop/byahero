import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/journey.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/journey_store.dart';
import '../services/journey_tracker.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'pdf_preview_screen.dart';

/// Trips tab: LAHAT ng nasesave na byahe — offline o online, may account
/// man o wala. Dito nakikita ang sync status at pwede ring i-export ang PDF.
class JourneyHistoryScreen extends StatefulWidget {
  const JourneyHistoryScreen({super.key});

  @override
  State<JourneyHistoryScreen> createState() => _JourneyHistoryScreenState();
}

class _JourneyHistoryScreenState extends State<JourneyHistoryScreen> {
  List<Journey> _trips = const [];
  int _pending = 0;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _uid {
    final u = context.read<AuthService>().current()?.uid;
    return (u == null || u.isEmpty) ? JourneyStore.guestId : u;
  }

  Future<void> _load() async {
    final store = context.read<JourneyTracker>().store;
    final uid = _uid;
    final trips = await store.listFor(uid);
    final pending = await store.pendingCount(uid);
    if (!mounted) return;
    setState(() {
      _trips = trips;
      _pending = pending;
      _loading = false;
    });
  }

  Future<void> _sync() async {
    if (_syncing) return;
    final uid = _uid;
    if (uid == JourneyStore.guestId) {
      _toast('Mag-login muna para ma-sync sa cloud.');
      return;
    }
    setState(() => _syncing = true);
    final n = await SyncService.sync(
      store: context.read<JourneyTracker>().store,
      fs: context.read<FirestoreService>(),
      uid: uid,
    );
    await _load();
    if (!mounted) return;
    setState(() => _syncing = false);
    _toast(n > 0
        ? 'Naka-sync ang $n na byahe sa account mo.'
        : 'Wala nang bagong byahe na i-sync (pwede na ring offline).');
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _openPdf(Journey j) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PdfPreviewScreen(journey: j)),
    );
    if (mounted) _load();
  }

  Future<void> _details(Journey j) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _tripSheet(j),
    );
    if (mounted) _load();
  }

  Future<void> _delete(Journey j) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Burahin ang byahe?'),
        content: const Text('Hindi na maibabalik ang record na ito.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Bail out')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Burahin'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await context.read<JourneyTracker>().store.remove(j.id);
    await _load();
    if (mounted) _toast('Nabura ang byahe.');
  }

  String _dur(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final guest = _uid == JourneyStore.guestId;
    return Scaffold(
      appBar: AppBar(title: const Text('Mga Byahe')),
      body: RefreshIndicator(
        onRefresh: () async {
          await _load();
          if (!guest) await _sync();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [
            _statusCard(guest),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_trips.isEmpty)
              _emptyState()
            else
              ..._trips.map(_tile),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(bool guest) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.midnight, Color(0xFF4A1414)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_trips.length} na-saved na byahe',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          guest
              ? 'Guest mode — nasa phone mo lang ito. Mag-login sa Account tab '
                  'para ma-sync sa cloud (walang mawawala kahit offline).'
              : (_pending > 0
                  ? '$_pending na byahe ang naghihintay na ma-sync sa cloud.'
                  : 'Naka-sync na lahat sa iyong account.'),
          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
        ),
        if (!guest) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.brandRed,
                  minimumSize: const Size(0, 44),
                ),
                icon: _syncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.brandRed))
                    : const Icon(Icons.cloud_upload_rounded, size: 18),
                label: Text(_syncing ? 'Nagsa-sync…' : 'Sync ngayon'),
                onPressed: _syncing ? null : _sync,
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _emptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: const [
          Icon(Icons.route_rounded, size: 46, color: AppTheme.line),
          SizedBox(height: 12),
          Text('Wala pang naseserve na byahe',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          SizedBox(height: 6),
          Text(
            'Pumunta sa Tracker tab, pindutin ang Start Journey. '
            'Automatic na ito sese-save dito kahit offline o walang account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
          ),
        ]),
      ),
    );
  }

  Widget _tile(Journey j) {
    final when = DateFormat('EEE, MMM d • h:mm a').format(j.startedAt);
    final modeColor = j.points.isEmpty
        ? AppTheme.brandRed
        : j.points.last.mode.color;
    final done = j.endedAt != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _details(j),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: modeColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.navigation_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(when,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(
                      'Total ${_dur(j.totalTime)}'
                      '${j.waitingTime.inSeconds > 0 ? '  •  Pila ${_dur(j.waitingTime)}' : ''}'
                      '  •  ${j.points.length} pts',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              if (!done)
                const Tooltip(
                  message: 'Hindi natapos (interrupted)',
                  child: Icon(Icons.warning_amber_rounded,
                      size: 18, color: Colors.orange),
                ),
              IconButton(
                tooltip: 'PDF report',
                icon: const Icon(Icons.picture_as_pdf_rounded),
                color: AppTheme.brandRed,
                onPressed: () => _openPdf(j),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tripSheet(Journey j) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.line, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 16),
          Text(DateFormat('EEEE, MMMM d • h:mm a').format(j.startedAt),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          if (j.destLabel != null) ...[
            const SizedBox(height: 4),
            Text('Destination: ${j.destLabel}',
                style: const TextStyle(color: AppTheme.muted, fontSize: 12.5)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            _box('TOTAL', _dur(j.totalTime), AppTheme.brandRed),
            const SizedBox(width: 10),
            _box('PILA', _dur(j.waitingTime), Colors.amber.shade700),
            const SizedBox(width: 10),
            _box('POINTS', '${j.points.length}', AppTheme.midnight),
          ]),
          if (j.autoLogs.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Auto-detected na paghintigil',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 6),
            ...j.autoLogs.take(5).map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Icon(Icons.place, size: 14, color: AppTheme.brandRed),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(l,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.muted))),
                  ]),
                )),
          ],
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('PDF'),
                onPressed: () {
                  Navigator.pop(context);
                  _openPdf(j);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Burahin'),
                onPressed: () {
                  Navigator.pop(context);
                  _delete(j);
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _box(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.muted,
                  letterSpacing: .8)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        ]),
      ),
    );
  }
}
