import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../sos/sos_contacts_screen.dart';
import '../../services/notification_services.dart';
import '../../data/repositories/repositories.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  // Hold logic
  static const _holdMs = 3000;
  bool _pressing = false;
  double _progress = 0.0;
  Timer? _holdTimer;
  DateTime? _pressStart;
  int _contactCount = 0;

  // Animations
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _rotCtrl;

  @override
  void initState() {
    super.initState();
    _loadContactCount();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _rotCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulseCtrl.dispose();
    _rotCtrl.dispose();
    super.dispose();
  }

  // ── Hold press handlers ────────────────────────────────────────
  void _onPressStart() {
    final sos = context.read<SosProvider>();
    if (sos.active) { _cancelSos(); return; }
    setState(() { _pressing = true; _progress = 0.0; });
    _pressStart = DateTime.now();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted) { t.cancel(); return; }
      final elapsed = DateTime.now().difference(_pressStart!).inMilliseconds;
      final p = (elapsed / _holdMs).clamp(0.0, 1.0);
      setState(() => _progress = p);
      if (p >= 1.0) { t.cancel(); _activateSos(); }
    });
  }

  void _onPressEnd() {
    if (context.read<SosProvider>().active) return;
    _holdTimer?.cancel();
    setState(() { _pressing = false; _progress = 0.0; });
  }

  Future<void> _activateSos() async {
    setState(() { _pressing = false; _progress = 0.0; });
    final user = context.read<AuthProvider>().user;
    await context.read<SosProvider>().activateSos(
      userId:    user?.uid   ?? 'anonymous',
      userName:  user?.fullName ?? '',
      userEmail: user?.email ?? '',
      userPhone: user?.phone  ?? '',
    );
    _vibrateEmergency();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 ALERTA SOS ACTIVADA'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 4),
        ),
      );
    }

    final sos = context.read<SosProvider>();
    notificationServices.openWhatsapp(
    userName: user?.fullName ?? '', 
    address: sos.lastAddress, 
    latitude: (sos.lastLat).toString(), 
    longitude: (sos.lastLon).toString());
  }

  Future<void> _cancelSos() async {
    await context.read<SosProvider>().cancelSos();
    _pulseCtrl.stop();
    _pulseCtrl.value = 0;
    _pulseCtrl.repeat(reverse: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alerta SOS cancelada'),
            backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _loadContactCount() async{
    try{
      final uid = context.read<AuthProvider>().user?.uid ?? '';
      final repo = SosRepository();
      final contacts = await repo.getSosContacts(uid);
      if(mounted) setState(() => _contactCount = contacts.length);
    } catch(_){}
  }

  Future<void> _vibrateEmergency() async {
    if (await Vibration.hasVibrator() ?? false) {
      // SOS Morse: ... --- ...
      Vibration.vibrate(
        pattern: [0,200,100,200,100,200,100,500,100,500,100,500,100,200,100,200,100,200],
        intensities: [0,255,0,255,0,255,0,255,0,255,0,255,0,255,0,255,0,255],
      );
    }
  }

  Future<void> _callEmergency() async {
    final uri = Uri.parse('tel:911');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final sos = context.watch<SosProvider>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text('Alerta de emergencia',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                sos.active
                    ? 'Tocá el botón para cancelar'
                    : 'Mantené presionado 3 segundos',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 24),
              // SOS Button
              _buildSosButton(sos.active),
              const SizedBox(height: 6),
              // Progress bar
              if (!sos.active)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 4,
                      backgroundColor: AppColors.borderColor,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              // Info cards
              Row(
                children: [
                  _InfoCard(label: 'Ubicación', value: '📍', sublabel: 'GPS activo'),
                  const SizedBox(width: 8),
                  _InfoCard(label: 'GPS', value: 'ON',
                      valueColor: AppColors.success, sublabel: 'Online'),
                  const SizedBox(width: 8),
                  _InfoCard(label: 'Contactos', value: '2', sublabel: 'SOS'),
                ],
              ),
              const SizedBox(height: 14),
              // SOS info box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sosInfoBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('¿Qué hace el SOS?',
                        style: TextStyle(color: AppColors.secondary,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...const [
                      'Envía tu ubicación en tiempo real',
                      'Notifica a tus contactos de emergencia',
                      'Activa vibración de alerta',
                      'Crea un reporte automático en la app',
                    ].map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check, color: AppColors.success, size: 14),
                          const SizedBox(width: 8),
                          Text(t, style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Status
              Text(
                sos.active ? 'Estado: ALERTA ACTIVA' : 'Estado: Inactivo',
                style: TextStyle(
                  color: sos.active ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: sos.active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 14),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('Llamar 911'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 0.5),
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: _callEmergency,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.contacts, size: 16),
                      label: const Text('Contactos SOS'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.borderColor, width: 0.5),
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SosContactsScreen())),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSosButton(bool active) {
    return GestureDetector(
      onTapDown: (_) => _onPressStart(),
      onTapUp:   (_) => _onPressEnd(),
      onTapCancel:   _onPressEnd,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnim, _rotCtrl]),
        builder: (_, __) {
          return SizedBox(
            width: 200, height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Rotating dashed ring
                Transform.rotate(
                  angle: _rotCtrl.value * 2 * math.pi,
                  child: Container(
                    width: 196, height: 196,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.primary.withValues(alpha: 0.18),
                        width: 1,
                      ),
                    ),
                  ),
                ),
                // Outer ring (solid)
                Container(
                  width: 172, height: 172,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active
                          ? AppColors.primary.withValues(alpha: 0.6)
                          : AppColors.primary.withValues(alpha: 0.25),
                      width: 2,
                    ),
                    boxShadow: active
                        ? [BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 24, spreadRadius: 4)]
                        : null,
                  ),
                ),
                // Core button
                Transform.scale(
                  scale: active ? _pulseAnim.value : (_pressing ? 0.93 : 1.0),
                  child: Container(
                    width: 136, height: 136,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: active
                            ? [AppColors.primary, AppColors.secondary]
                            : [const Color(0xFFB71C1C), AppColors.primary],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: active ? 0.6 : 0.4),
                          blurRadius: active ? 32 : 20,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                              shadows: active ? [const Shadow(color: Colors.white24, blurRadius: 8)] : null,
                            )),
                        Text(
                          active ? 'ACTIVO' : 'EMERGENCIA',
                          style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                ),
                // Progress arc overlay while pressing
                if (_pressing && !active)
                  CustomPaint(
                    size: const Size(172, 172),
                    painter: _ArcPainter(_progress),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Progress arc ──────────────────────────────────────────────
class _ArcPainter extends CustomPainter {
  final double progress;
  const _ArcPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.progress != progress;
}

// ── Info card ─────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String label, value;
  final String? sublabel;
  final Color? valueColor;
  const _InfoCard({required this.label, required this.value, this.sublabel, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderColor, width: 0.5),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: valueColor ?? AppColors.textPrimary,
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
            if (sublabel != null)
              Text(sublabel!,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 8)),
          ],
        ),
      ),
    );
  }
}
