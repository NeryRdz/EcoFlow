import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_options.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (snapshot.hasData && snapshot.data != null) return const HomePage();
          return const LoginPage();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLORES
// ─────────────────────────────────────────────────────────────────────────────

const kUserPrimary      = Color(0xFF2E7D32);
const kUserPrimaryLight = Color(0xFF43A047);
const kUserAccent       = Color(0xFF66BB6A);
const kUserSurface      = Color(0xFFE8F5E9);

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — CREAR NOTIFICACIÓN
// ─────────────────────────────────────────────────────────────────────────────

Future<void> crearNotificacion({
  required String uid,
  required String titulo,
  required String cuerpo,
  required String tipo,
}) async {
  await FirebaseFirestore.instance.collection('notificaciones').add({
    'uid': uid, 'titulo': titulo, 'cuerpo': cuerpo,
    'tipo': tipo, 'leida': false, 'creadoEn': FieldValue.serverTimestamp(),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — BARRA DE PROGRESO DE LOGROS
// ─────────────────────────────────────────────────────────────────────────────

class _LogroStep {
  final String label;
  final int min, max;
  final Color color;
  const _LogroStep({required this.label, required this.min, required this.max, required this.color});
}

class _LogrosProgressBar extends StatelessWidget {
  final int intercambios;
  final bool compact;
  const _LogrosProgressBar({required this.intercambios, this.compact = false});

  static const List<_LogroStep> _steps = [
    _LogroStep(label: '🌱 Nuevo',    min: 0,  max: 5,  color: Color(0xFF66BB6A)),
    _LogroStep(label: '🥉 Avanzado', min: 5,  max: 10, color: Color(0xFF8D6748)),
    _LogroStep(label: '🥈 Experto',  min: 10, max: 20, color: Color(0xFF9E9E9E)),
    _LogroStep(label: '🥇 Maestro',  min: 20, max: 20, color: Color(0xFFD4AF37)),
  ];

  _LogroStep get _currentStep {
    for (final s in _steps.reversed) {
      if (intercambios >= s.min) return s;
    }
    return _steps.first;
  }

  double get _progress {
    final s = _currentStep;
    if (s.min == s.max) return 1.0;
    return ((intercambios - s.min) / (s.max - s.min)).clamp(0.0, 1.0);
  }

  int get _remaining {
    final s = _currentStep;
    if (s.min == s.max) return 0;
    return s.max - intercambios;
  }

  String get _nextLevel {
    for (int i = 0; i < _steps.length - 1; i++) {
      if (_currentStep == _steps[i]) return _steps[i + 1].label;
    }
    return '🥇 Maestro';
  }

  @override
  Widget build(BuildContext context) {
    final step = _currentStep;
    final prog = _progress;
    final isMaestro = intercambios >= 20;

    if (compact) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(step.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: step.color)),
          const Spacer(),
          if (!isMaestro)
            Text('$intercambios/${step.max}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: prog, minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(step.color),
          ),
        ),
        const SizedBox(height: 2),
        if (!isMaestro)
          Text('Faltan $_remaining para $_nextLevel', style: TextStyle(fontSize: 9, color: Colors.grey.shade500))
        else
          Text('¡Nivel máximo alcanzado!', style: TextStyle(fontSize: 9, color: step.color, fontWeight: FontWeight.bold)),
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.emoji_events, color: Color(0xFFD4AF37), size: 20),
          const SizedBox(width: 8),
          const Text('Progreso de Logros', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kUserPrimary)),
        ]),
        const SizedBox(height: 14),
        Row(children: List.generate(_steps.length, (i) {
          final s = _steps[i];
          final done = intercambios >= s.min;
          final isCurrent = _currentStep == s;
          return Expanded(child: Column(children: [
            Row(children: [
              if (i > 0) Expanded(child: Container(height: 2, color: done ? s.color : Colors.grey.shade200)),
              Container(
                width: isCurrent ? 28 : 22, height: isCurrent ? 28 : 22,
                decoration: BoxDecoration(
                  color: done ? s.color : Colors.grey.shade200,
                  shape: BoxShape.circle,
                  border: isCurrent ? Border.all(color: s.color, width: 2) : null,
                  boxShadow: isCurrent ? [BoxShadow(color: s.color.withOpacity(0.4), blurRadius: 6)] : [],
                ),
                child: Center(child: Text(s.label.split(' ').first, style: const TextStyle(fontSize: 12))),
              ),
              if (i < _steps.length - 1)
                Expanded(child: Container(height: 2, color: intercambios >= s.max ? _steps[i + 1].color : Colors.grey.shade200)),
            ]),
            const SizedBox(height: 4),
            Text(s.label.split(' ').last, style: TextStyle(fontSize: 9, color: done ? s.color : Colors.grey.shade400, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
          ]));
        })),
        const SizedBox(height: 14),
        Row(children: [
          Text('Nivel actual: ${step.label}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: step.color)),
          const Spacer(),
          if (!isMaestro)
            Text('$intercambios / ${step.max}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: prog, minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(step.color),
          ),
        ),
        const SizedBox(height: 6),
        if (!isMaestro)
          Text('Faltan $_remaining intercambios para $_nextLevel', style: TextStyle(fontSize: 10, color: Colors.grey.shade500))
        else
          Text('🎉 ¡Nivel máximo alcanzado! Eres un Maestro EcoFlow.', style: TextStyle(fontSize: 10, color: step.color, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — CAMPANA DE NOTIFICACIONES
// ─────────────────────────────────────────────────────────────────────────────

class _BellIcon extends StatelessWidget {
  final String uid;
  const _BellIcon({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('notificaciones').where('uid', isEqualTo: uid).snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.where((d) => (d.data() as Map<String, dynamic>)['leida'] == false).length ?? 0;
        return Stack(children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificacionesPage(uid: uid))),
          ),
          if (count > 0) Positioned(right: 6, top: 6, child: Container(
            width: 18, height: 18,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: Center(child: Text(count > 9 ? '9+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
          )),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA — NOTIFICACIONES
// ─────────────────────────────────────────────────────────────────────────────

class NotificacionesPage extends StatelessWidget {
  final String uid;
  const NotificacionesPage({required this.uid, super.key});

  String _iconoTipo(String tipo) {
    switch (tipo) {
      case 'intercambio_solicitado':  return '🔄';
      case 'intercambio_aceptado':    return '✅';
      case 'intercambio_rechazado':   return '❌';
      case 'intercambio_completado':  return '🎉';
      case 'mensaje':                 return '💬';
      default:                        return '🔔';
    }
  }

  String _formatFecha(dynamic ts) {
    if (ts == null) return '';
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kUserSurface,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: kUserPrimary, foregroundColor: Colors.white, elevation: 0,
        actions: [TextButton(
          onPressed: () async {
            final snap = await FirebaseFirestore.instance.collection('notificaciones').where('uid', isEqualTo: uid).get();
            for (final d in snap.docs) {
              if ((d.data() as Map<String, dynamic>)['leida'] == false) await d.reference.update({'leida': true});
            }
          },
          child: const Text('Leer todas', style: TextStyle(color: Colors.white, fontSize: 12)),
        )],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('notificaciones').where('uid', isEqualTo: uid).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator(color: kUserPrimary));
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.notifications_none, size: 64, color: kUserAccent),
              const SizedBox(height: 12),
              const Text('Sin notificaciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kUserPrimary)),
              Text('Aquí verás las solicitudes de intercambio', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ]));
          }
          final docs = snap.data!.docs.toList()
            ..sort((a, b) {
              final ta = (a.data() as Map<String, dynamic>)['creadoEn'];
              final tb = (b.data() as Map<String, dynamic>)['creadoEn'];
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return (tb as Timestamp).compareTo(ta as Timestamp);
            });
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc   = docs[i];
              final data  = doc.data() as Map<String, dynamic>;
              final leida = data['leida'] as bool? ?? false;
              return Dismissible(
                key: Key(doc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => doc.reference.delete(),
                child: GestureDetector(
                  onTap: () async {
                    if (!leida) await doc.reference.update({'leida': true});
                    final tipo = data['tipo'] as String? ?? '';
                    if (tipo.startsWith('intercambio') && context.mounted)
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const IntercambiosTab()));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: leida ? Colors.white : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                      border: leida ? null : Border.all(color: kUserAccent.withOpacity(0.5)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 44, height: 44, decoration: BoxDecoration(color: leida ? Colors.grey.shade100 : kUserSurface, shape: BoxShape.circle), child: Center(child: Text(_iconoTipo(data['tipo'] ?? ''), style: const TextStyle(fontSize: 22)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(data['titulo'] ?? '', style: TextStyle(fontSize: 13, fontWeight: leida ? FontWeight.normal : FontWeight.bold, color: const Color(0xFF1A1A1A)))),
                          if (!leida) Container(width: 8, height: 8, decoration: const BoxDecoration(color: kUserPrimary, shape: BoxShape.circle)),
                        ]),
                        const SizedBox(height: 3),
                        Text(data['cuerpo'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
                        if (data['creadoEn'] != null) ...[
                          const SizedBox(height: 4),
                          Text(_formatFecha(data['creadoEn']), style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                        ],
                      ])),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — BADGE DE REPUTACIÓN
// ─────────────────────────────────────────────────────────────────────────────

class _ReputacionBadge extends StatelessWidget {
  final int intercambios;
  final bool small;
  const _ReputacionBadge({required this.intercambios, this.small = false});

  Color get _color {
    if (intercambios >= 20) return const Color(0xFFD4AF37);
    if (intercambios >= 10) return const Color(0xFF9E9E9E);
    if (intercambios >= 5)  return const Color(0xFF8D6748);
    return kUserAccent;
  }

  String get _nivel {
    if (intercambios >= 20) return '🥇 Maestro';
    if (intercambios >= 10) return '🥈 Experto';
    if (intercambios >= 5)  return '🥉 Avanzado';
    return '🌱 Nuevo';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 3 : 4),
      decoration: BoxDecoration(color: _color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: _color.withOpacity(0.4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.workspace_premium, size: small ? 11 : 13, color: _color),
        const SizedBox(width: 3),
        Text(
          small ? '$intercambios intercambios' : '$_nivel · $intercambios intercambios',
          style: TextStyle(fontSize: small ? 9 : 10, fontWeight: FontWeight.w700, color: _color),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — AVATAR DE USUARIO (con soporte para foto en base64)
// ─────────────────────────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  final double radius;
  final Color bgColor;
  final Color iconColor;
  final String? fotoBase64;
  const _UserAvatar({
    this.radius = 28,
    this.bgColor = kUserSurface,
    this.iconColor = kUserPrimary,
    this.fotoBase64,
  });

  @override
  Widget build(BuildContext context) {
    if (fotoBase64 != null && fotoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(fotoBase64!);
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Icon(Icons.person, size: radius * 1.2, color: iconColor),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — CAMPO DE TEXTO MINIMALISTA
// ─────────────────────────────────────────────────────────────────────────────

class _MinimalField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? type;
  final bool obscure;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  const _MinimalField({required this.controller, required this.label, required this.icon, this.type, this.obscure = false, this.suffixIcon, this.inputFormatters});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller, keyboardType: type, obscureText: obscure, inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        labelText: label, labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400), suffixIcon: suffixIcon,
        filled: true, fillColor: const Color(0xFFF7F7F7),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kUserPrimary, width: 1.5)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS COMPARTIDOS PARA PÁGINAS LEGALES
// ─────────────────────────────────────────────────────────────────────────────

class _LegalSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _LegalSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: kUserSurface, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: kUserPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)))),
      ]),
    );
  }
}

class _LegalParagraph extends StatelessWidget {
  final String text;
  const _LegalParagraph({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5)),
    );
  }
}

class _LegalBullet extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _LegalBullet({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.5))),
      ]),
    );
  }
}

class _LegalInfoBox extends StatelessWidget {
  final Color bgColor, borderColor, iconColor, textColor;
  final IconData icon;
  final String text;
  const _LegalInfoBox({
    required this.bgColor, required this.borderColor,
    required this.iconColor, required this.textColor,
    required this.icon, required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: textColor, height: 1.5))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA — AVISO DE PRIVACIDAD
// ─────────────────────────────────────────────────────────────────────────────

class AvisoPrivacidadPage extends StatelessWidget {
  const AvisoPrivacidadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Aviso de Privacidad'),
        backgroundColor: kUserPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Encabezado ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.privacy_tip_outlined, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Aviso de Privacidad', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('EcoFlow · Versión 1.0', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
              ]),
              const SizedBox(height: 12),
              const Text('Última actualización: junio de 2025', style: TextStyle(color: Colors.white60, fontSize: 11)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Text(
                  'En cumplimiento con la Ley Federal de Protección de Datos Personales en Posesión de los Particulares (LFPDPPP), EcoFlow pone a tu disposición el siguiente Aviso de Privacidad.',
                  style: TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Sección 1: Responsable ──────────────────────────────────────────
          _LegalSectionTitle(icon: Icons.business_outlined, title: '1. Responsable del Tratamiento'),
          const _LegalParagraph(text: 'El responsable del tratamiento de tus datos personales es el equipo desarrollador de EcoFlow, aplicación dedicada a la economía circular en Aguascalientes, México.'),
          _LegalInfoBox(
            bgColor: kUserSurface,
            borderColor: kUserAccent.withOpacity(0.5),
            iconColor: kUserPrimary,
            textColor: const Color(0xFF1B5E20),
            icon: Icons.mail_outline,
            text: 'Contacto del desarrollador:\necoflow084@gmail.com',
          ),
          const SizedBox(height: 20),

          // ── Sección 2: Qué datos recopilamos ───────────────────────────────
          _LegalSectionTitle(icon: Icons.data_usage_outlined, title: '2. Datos que Recopilamos'),
          const _LegalParagraph(text: 'EcoFlow recopila únicamente los datos necesarios para el funcionamiento de la plataforma:'),

          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FBE7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.lightGreen.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.app_registration, size: 15, color: kUserPrimary),
                const SizedBox(width: 6),
                const Text('Datos que proporcionas al registrarte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kUserPrimary)),
              ]),
              const SizedBox(height: 10),
              _LegalBullet(icon: Icons.person_outline,  color: kUserPrimary, text: 'Nombre completo — para identificarte dentro de la comunidad y mostrarlo en tu perfil, marcadores e intercambios.'),
              _LegalBullet(icon: Icons.email_outlined,  color: kUserPrimary, text: 'Correo electrónico — para autenticación mediante Firebase Authentication e inicio de sesión.'),
              _LegalBullet(icon: Icons.phone_outlined,  color: kUserPrimary, text: 'Número de teléfono — para que otros usuarios puedan contactarte al coordinar un intercambio.'),
              _LegalBullet(icon: Icons.lock_outline,    color: kUserPrimary, text: 'Contraseña — gestionada por Firebase Authentication con cifrado; nunca visible para el equipo desarrollador.'),
            ]),
          ),

          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.tune_outlined, size: 15, color: Color(0xFF6A1B9A)),
                const SizedBox(width: 6),
                const Text('Dato opcional', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A))),
              ]),
              const SizedBox(height: 10),
              _LegalBullet(icon: Icons.photo_camera_outlined, color: const Color(0xFF6A1B9A), text: 'Foto de perfil — imagen seleccionada voluntariamente desde tu cámara o galería. Se convierte a Base64 y se almacena en Firestore.'),
            ]),
          ),

          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.auto_graph, size: 15, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Text('Datos generados por el uso de la app', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
              ]),
              const SizedBox(height: 10),
              _LegalBullet(icon: Icons.location_on_outlined,   color: Colors.blue.shade700, text: 'Coordenadas geográficas — capturadas al crear un marcador o al centrar el mapa. No se rastrean de forma continua.'),
              _LegalBullet(icon: Icons.swap_horiz,             color: Colors.blue.shade700, text: 'Historial de intercambios y donaciones — registro de propuestas enviadas, recibidas y completadas.'),
              _LegalBullet(icon: Icons.emoji_events_outlined,  color: Colors.blue.shade700, text: 'Contador de intercambios completados — determina tu nivel de reputación en la plataforma.'),
              _LegalBullet(icon: Icons.notifications_outlined, color: Colors.blue.shade700, text: 'Notificaciones internas — mensajes sobre el estado de tus intercambios, eliminables por ti.'),
              _LegalBullet(icon: Icons.chat_bubble_outline,    color: Colors.blue.shade700, text: 'Mensajes del chat de intercambio — visibles solo para los dos participantes de cada intercambio.'),
              _LegalBullet(icon: Icons.headset_mic_outlined,   color: Colors.blue.shade700, text: 'Solicitudes de soporte — mensajes enviados a través del formulario de soporte de la app.'),
            ]),
          ),
          // Después de la sección de "Datos generados por el uso de la app" (línea ~200)
// Antes del SizedBox(height: 6)

// ── ADVERTENCIA: Permisos de galería en Android ──────────────────────────
Container(
  margin: const EdgeInsets.only(bottom: 14),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: const Color(0xFFFFF8E1),  // Amarillo muy claro
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.orange.shade200),
  ),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Icon(Icons.info_outline, size: 15, color: Colors.orange.shade700),
      const SizedBox(width: 6),
      Text('Importante: Permisos de la galería', 
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
    ]),
    const SizedBox(height: 10),
    _LegalBullet(
      icon: Icons.photo_library_outlined,
      color: Colors.orange.shade700,
      text: 'Para seleccionar una foto de perfil desde tu galería, Android NO mostrará una ventana de permisos. La galería se abrirá directamente porque el sistema operativo lo permite sin necesidad de permiso explícito.',
    ),
    _LegalBullet(
      icon: Icons.camera_alt_outlined,
      color: Colors.orange.shade700,
      text: 'Para tomar una foto con la cámara, SÍ verás una ventana pidiendo permiso. Esto es normal y necesario para proteger tu privacidad.',
    ),
    _LegalBullet(
      icon: Icons.android_outlined,
      color: Colors.orange.shade700,
      text: 'En versiones recientes de Android (10+), puedes acceder a tus fotos sin necesidad de permisos especiales gracias a la función "Almacenamiento con ámbito" (Scoped Storage) que protege tu privacidad.',
    ),
    const SizedBox(height: 6),
    Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, size: 14, color: Colors.orange.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'No solicitamos acceso permanente a tu galería. Solo accedemos a la imagen que tú eliges en el momento.',
              style: TextStyle(fontSize: 10, color: Colors.orange.shade800, height: 1.4),
            ),
          ),
        ],
      ),
    ),
  ]),
),
          const SizedBox(height: 6),

          // ── Sección 3: Para qué se usan ────────────────────────────────────
          _LegalSectionTitle(icon: Icons.analytics_outlined, title: '3. Para qué Usamos tus Datos'),
          const _LegalParagraph(text: 'Tus datos se utilizan exclusivamente para:'),
          _LegalBullet(icon: Icons.people_outline,         color: kUserPrimary, text: 'Crear y gestionar tu cuenta de usuario dentro de EcoFlow.'),
          _LegalBullet(icon: Icons.verified_user_outlined, color: kUserPrimary, text: 'Autenticarte de forma segura cada vez que inicias sesión.'),
          _LegalBullet(icon: Icons.map_outlined,           color: kUserPrimary, text: 'Registrar marcadores de puntos de recolección o intercambio en el mapa interactivo.'),
          _LegalBullet(icon: Icons.swap_horiz,             color: kUserPrimary, text: 'Gestionar y coordinar solicitudes de intercambio y donación entre usuarios.'),
          _LegalBullet(icon: Icons.notifications_outlined, color: kUserPrimary, text: 'Enviarte notificaciones internas sobre el estado de tus intercambios.'),
          _LegalBullet(icon: Icons.emoji_events_outlined,  color: kUserPrimary, text: 'Calcular y mostrar tu nivel de reputación dentro de la plataforma.'),
          _LegalBullet(icon: Icons.support_agent_outlined, color: kUserPrimary, text: 'Atender tus solicitudes de soporte enviadas a través de la app.'),
          _LegalInfoBox(
            bgColor: const Color(0xFFFFF8E1),
            borderColor: Colors.orange.shade200,
            iconColor: Colors.orange.shade700,
            textColor: Colors.orange.shade900,
            icon: Icons.block_outlined,
            text: 'EcoFlow NO vende, comparte ni comercializa tus datos con anunciantes, socios comerciales ni terceros ajenos a los proveedores tecnológicos necesarios para el servicio.',
          ),
          const SizedBox(height: 20),

          // ── Sección 4: Cómo se protegen ────────────────────────────────────
          _LegalSectionTitle(icon: Icons.security_outlined, title: '4. Cómo Protegemos tus Datos'),
          const _LegalParagraph(text: 'Todos los datos se almacenan en Firebase (Google Cloud), con certificaciones ISO 27001 y SOC 2/3. Las medidas implementadas son:'),
          _LegalBullet(icon: Icons.lock_outline,           color: const Color(0xFF00838F), text: 'Cifrado en tránsito mediante TLS/HTTPS en todas las comunicaciones.'),
          _LegalBullet(icon: Icons.verified_user_outlined, color: const Color(0xFF00838F), text: 'Autenticación segura vía Firebase Authentication; las contraseñas nunca son visibles para el equipo.'),
          _LegalBullet(icon: Icons.rule_outlined,          color: const Color(0xFF00838F), text: 'Reglas de seguridad en Firestore que restringen el acceso a tus datos solo a ti y administradores autorizados.'),
          _LegalBullet(icon: Icons.photo_size_select_small_outlined, color: const Color(0xFF00838F), text: 'Las fotos de perfil se redimensionan a 600×600 px y se comprimen al 75 % antes de almacenarse.'),
          _LegalBullet(icon: Icons.admin_panel_settings_outlined, color: const Color(0xFF00838F), text: 'Acceso administrativo limitado: el panel de administración no permite ver contraseñas de usuarios.'),
          const SizedBox(height: 20),

          // ── Sección 5: Geolocalización ─────────────────────────────────────
          _LegalSectionTitle(icon: Icons.location_on_outlined, title: '5. Uso de Geolocalización'),
          const _LegalParagraph(text: 'La ubicación se solicita únicamente cuando accedes al Mapa, para:'),
          _LegalBullet(icon: Icons.my_location,              color: const Color(0xFF1565C0), text: 'Centrar el mapa en tu posición actual.'),
          _LegalBullet(icon: Icons.add_location_alt_outlined, color: const Color(0xFF1565C0), text: 'Registrar coordenadas exactas al crear un marcador.'),
          _LegalInfoBox(
            bgColor: const Color(0xFFE3F2FD),
            borderColor: Colors.blue.shade200,
            iconColor: const Color(0xFF1565C0),
            textColor: const Color(0xFF1A237E),
            icon: Icons.info_outline,
            text: 'Puedes denegar el permiso de ubicación; el mapa usará Aguascalientes por defecto. Tu ubicación NO se almacena de forma continua ni se comparte con terceros.',
          ),
          const SizedBox(height: 20),

          // ── Sección 6: Cámara y galería ────────────────────────────────────
          _LegalSectionTitle(icon: Icons.camera_alt_outlined, title: '6. Acceso a Cámara y Galería'),
          const _LegalParagraph(text: 'Solo se solicita cuando decides cambiar tu foto de perfil, para:'),
          _LegalBullet(icon: Icons.camera_alt_outlined,    color: const Color(0xFF6A1B9A), text: 'Tomar una foto en tiempo real con la cámara del dispositivo.'),
          _LegalBullet(icon: Icons.photo_library_outlined, color: const Color(0xFF6A1B9A), text: 'Seleccionar una imagen existente desde la galería del dispositivo.'),
          _LegalInfoBox(
            bgColor: const Color(0xFFF3E5F5),
            borderColor: Colors.purple.shade200,
            iconColor: const Color(0xFF6A1B9A),
            textColor: const Color(0xFF4A148C),
            icon: Icons.verified_user_outlined,
            text: 'Solo accedemos a la imagen que tú seleccionas. No accedemos a ninguna otra foto ni archivo de tu dispositivo.',
          ),
          const SizedBox(height: 20),

          // ── Sección 7: Tus derechos ARCO ───────────────────────────────────
          _LegalSectionTitle(icon: Icons.person_pin_outlined, title: '7. Tus Derechos ARCO'),
          const _LegalParagraph(text: 'Conforme a la LFPDPPP tienes derecho a:'),
          _LegalBullet(icon: Icons.visibility_outlined,     color: const Color(0xFF1565C0), text: 'Acceso — ver tus datos desde "Ver mis datos".'),
          _LegalBullet(icon: Icons.edit_note_outlined,      color: const Color(0xFF1565C0), text: 'Rectificación — corregir datos desde "Cambiar mis datos".'),
          _LegalBullet(icon: Icons.delete_forever_outlined, color: const Color(0xFF1565C0), text: 'Cancelación — solicitar eliminación de tu cuenta escribiendo a ecoflow084@gmail.com.'),
          _LegalBullet(icon: Icons.block_outlined,          color: const Color(0xFF1565C0), text: 'Oposición — oponerte al tratamiento de datos no esenciales contactando al desarrollador.'),
          _LegalInfoBox(
            bgColor: kUserSurface,
            borderColor: kUserAccent.withOpacity(0.5),
            iconColor: kUserPrimary,
            textColor: const Color(0xFF1B5E20),
            icon: Icons.mail_outline,
            text: 'Escríbenos a ecoflow084@gmail.com. Respondemos en un máximo de 20 días hábiles.',
          ),
          const SizedBox(height: 20),

          // ── Sección 8: Menores ─────────────────────────────────────────────
          _LegalSectionTitle(icon: Icons.child_care_outlined, title: '8. Menores de Edad'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.warning_amber_outlined, color: Colors.red.shade700, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'EcoFlow está destinado a mayores de 18 años. Al registrarte confirmas ser mayor de edad. Si un menor creó una cuenta, contáctanos para eliminarla.',
                style: TextStyle(fontSize: 12, color: Colors.red.shade800, height: 1.5),
              )),
            ]),
          ),
          const SizedBox(height: 28),

          // ── Botón cerrar ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Entendido', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kUserPrimary, foregroundColor: Colors.white,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA — TÉRMINOS Y CONDICIONES (reorganizada; privacidad en su propia página)
// ─────────────────────────────────────────────────────────────────────────────

class TerminosCondicionesPage extends StatelessWidget {
  const TerminosCondicionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Términos y Condiciones'),
        backgroundColor: kUserPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Encabezado ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.gavel_outlined, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Términos y Condiciones', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('EcoFlow · Versión 1.0', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
              ]),
              const SizedBox(height: 12),
              const Text('Última actualización: junio de 2025', style: TextStyle(color: Colors.white60, fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 16),

          // Acceso directo al Aviso de Privacidad
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AvisoPrivacidadPage())),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kUserSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kUserAccent.withOpacity(0.5)),
              ),
              child: Row(children: [
                const Icon(Icons.privacy_tip_outlined, color: kUserPrimary, size: 18),
                const SizedBox(width: 10),
                Expanded(child: RichText(text: const TextSpan(
                  style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32), height: 1.4),
                  children: [
                    TextSpan(text: 'El tratamiento de datos personales se describe en nuestro '),
                    TextSpan(text: 'Aviso de Privacidad', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                    TextSpan(text: '. Toca aquí para leerlo.'),
                  ],
                ))),
                const Icon(Icons.chevron_right, color: kUserPrimary, size: 18),
              ]),
            ),
          ),
          const SizedBox(height: 24),

          // ── Sección 1: Aceptación ──────────────────────────────────────────
          _LegalSectionTitle(icon: Icons.check_circle_outline, title: '1. Aceptación de los Términos'),
          const _LegalParagraph(text: 'Al registrarte y usar EcoFlow confirmas haber leído y aceptado estos Términos y el Aviso de Privacidad. Si no estás de acuerdo, debes abstenerte de usar la aplicación.'),
          const SizedBox(height: 20),

          // ── Sección 2: Descripción del servicio ───────────────────────────
          _LegalSectionTitle(icon: Icons.info_outline, title: '2. Descripción del Servicio'),
          const _LegalParagraph(text: 'EcoFlow es una plataforma de economía circular que permite a sus usuarios:'),
          _LegalBullet(icon: Icons.add_location_alt_outlined, color: kUserPrimary, text: 'Registrar marcadores georreferenciados de puntos de recolección, intercambio o donación.'),
          _LegalBullet(icon: Icons.map_outlined,              color: kUserPrimary, text: 'Explorar un mapa interactivo con los marcadores de la comunidad.'),
          _LegalBullet(icon: Icons.swap_horiz,                color: kUserPrimary, text: 'Proponer y gestionar intercambios o donaciones de materiales.'),
          _LegalBullet(icon: Icons.chat_bubble_outline,       color: kUserPrimary, text: 'Comunicarse mediante un chat integrado para coordinar cada intercambio.'),
          _LegalBullet(icon: Icons.emoji_events_outlined,     color: kUserPrimary, text: 'Acumular reputación y logros por su participación activa.'),
          const SizedBox(height: 20),

          // ── Sección 3: Registro y cuenta ──────────────────────────────────
          _LegalSectionTitle(icon: Icons.person_add_outlined, title: '3. Registro y Responsabilidades'),
          const _LegalParagraph(text: 'Al crear una cuenta te comprometes a:'),
          _LegalBullet(icon: Icons.verified_outlined,    color: kUserPrimary, text: 'Proporcionar información real, precisa y completa.'),
          _LegalBullet(icon: Icons.update_outlined,      color: kUserPrimary, text: 'Mantener actualizada tu información de contacto.'),
          _LegalBullet(icon: Icons.lock_person_outlined, color: kUserPrimary, text: 'Mantener la confidencialidad de tus credenciales.'),
          _LegalBullet(icon: Icons.report_outlined,      color: kUserPrimary, text: 'Notificarnos si detectas un uso no autorizado de tu cuenta.'),
          _LegalBullet(icon: Icons.no_accounts_outlined, color: kUserPrimary, text: 'No crear cuentas falsas ni suplantar la identidad de otra persona.'),
          const SizedBox(height: 20),

          // ── Sección 4: Uso aceptable ───────────────────────────────────────
          _LegalSectionTitle(icon: Icons.rule_outlined, title: '4. Uso Aceptable'),
          const _LegalParagraph(text: 'Queda estrictamente prohibido:'),
          _LegalBullet(icon: Icons.location_off_outlined,  color: Colors.red.shade700, text: 'Registrar marcadores con información falsa o en ubicaciones incorrectas.'),
          _LegalBullet(icon: Icons.block_outlined,         color: Colors.red.shade700, text: 'Proponer intercambios con fines fraudulentos o de mala fe.'),
          _LegalBullet(icon: Icons.chat_bubble_outline,    color: Colors.red.shade700, text: 'Enviar contenido ofensivo, spam o amenazas a través del chat.'),
          _LegalBullet(icon: Icons.bug_report_outlined,    color: Colors.red.shade700, text: 'Intentar vulnerar la seguridad de la plataforma o acceder a datos ajenos.'),
          _LegalBullet(icon: Icons.repeat_outlined,        color: Colors.red.shade700, text: 'Crear solicitudes de intercambio masivas o automatizadas.'),
          const SizedBox(height: 20),

          // ── Sección 5: Marcadores ──────────────────────────────────────────
          _LegalSectionTitle(icon: Icons.location_on_outlined, title: '5. Marcadores en el Mapa'),
          const _LegalParagraph(text: 'Al crear un marcador aceptas que:'),
          _LegalBullet(icon: Icons.public_outlined,            color: kUserPrimary, text: 'La información del marcador será visible para todos los usuarios de EcoFlow.'),
          _LegalBullet(icon: Icons.contact_phone_outlined,     color: kUserPrimary, text: 'Tu nombre, correo y teléfono podrán ser vistos por quienes consulten tus marcadores.'),
          _LegalBullet(icon: Icons.edit_location_alt_outlined, color: kUserPrimary, text: 'Eres responsable de la veracidad y actualización de la información publicada.'),
          _LegalBullet(icon: Icons.delete_forever_outlined,    color: kUserPrimary, text: 'Puedes editar o eliminar tus marcadores en cualquier momento.'),
          const SizedBox(height: 20),

          // ── Sección 6: Intercambios ────────────────────────────────────────
          _LegalSectionTitle(icon: Icons.swap_horiz, title: '6. Intercambios y Donaciones'),
          const _LegalParagraph(text: 'EcoFlow actúa como intermediario tecnológico. Respecto a los intercambios:'),
          _LegalBullet(icon: Icons.handshake_outlined,       color: kUserPrimary, text: 'EcoFlow no garantiza el cumplimiento de los acuerdos entre usuarios.'),
          _LegalBullet(icon: Icons.pending_actions_outlined, color: kUserPrimary, text: 'Un intercambio se completa cuando ambas partes lo confirman en la app.'),
          _LegalBullet(icon: Icons.warning_amber_outlined,   color: Colors.orange.shade700, text: 'EcoFlow no se responsabiliza por el estado de materiales, incumplimientos ni disputas.'),
          _LegalBullet(icon: Icons.timer_outlined,           color: kUserPrimary, text: 'Solo puede existir una solicitud activa entre el mismo par de usuarios.'),
          const SizedBox(height: 20),

          // ── Sección 7: Reputación ──────────────────────────────────────────
          _LegalSectionTitle(icon: Icons.workspace_premium_outlined, title: '7. Sistema de Reputación'),
          const _LegalParagraph(text: 'Los niveles de reputación según intercambios completados son:'),
          _LegalBullet(icon: Icons.emoji_nature_outlined,  color: const Color(0xFF66BB6A), text: '🌱 Nuevo — 0 a 4 intercambios.'),
          _LegalBullet(icon: Icons.military_tech_outlined, color: const Color(0xFF8D6748), text: '🥉 Avanzado — 5 a 9 intercambios.'),
          _LegalBullet(icon: Icons.star_outline,           color: const Color(0xFF9E9E9E), text: '🥈 Experto — 10 a 19 intercambios.'),
          _LegalBullet(icon: Icons.emoji_events_outlined,  color: const Color(0xFFD4AF37), text: '🥇 Maestro — 20 o más intercambios.'),
          const SizedBox(height: 20),

          // ── Sección 8: Limitación de responsabilidad ──────────────────────
          _LegalSectionTitle(icon: Icons.gavel_outlined, title: '8. Limitación de Responsabilidad'),
          const _LegalParagraph(text: 'EcoFlow se proporciona "tal como está". No garantizamos disponibilidad ininterrumpida y no somos responsables por interrupciones del servicio, comportamiento de otros usuarios, calidad de materiales intercambiados ni información incorrecta publicada por usuarios.'),
          const SizedBox(height: 20),

          // ── Sección 9: Contacto ────────────────────────────────────────────
          _LegalSectionTitle(icon: Icons.contact_support_outlined, title: '9. Contacto'),
          const _LegalParagraph(text: 'Para dudas sobre estos Términos o el Aviso de Privacidad:'),
          _LegalInfoBox(
            bgColor: kUserSurface,
            borderColor: kUserAccent.withOpacity(0.5),
            iconColor: kUserPrimary,
            textColor: const Color(0xFF1B5E20),
            icon: Icons.mail_outline,
            text: 'ecoflow084@gmail.com',
          ),
          const SizedBox(height: 28),

          // ── Botón cerrar ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Entendido', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kUserPrimary, foregroundColor: Colors.white,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA — LOGIN
// ─────────────────────────────────────────────────────────────────────────────

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();
  bool _obscure = true, _loading = false;

  Future loginUser() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(), password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) { _showError(e.message); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _showError(String? msg) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Error'), content: Text(msg ?? 'Credenciales incorrectas'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: kUserPrimary)))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 60),
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: kUserPrimary, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.eco, color: Colors.white, size: 24)),
            const SizedBox(width: 10),
            const Text('EcoFlow', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kUserPrimary)),
          ]),
          const SizedBox(height: 48),
          const Text('Bienvenido', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 6),
          Text('Inicia sesión para continuar', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          const SizedBox(height: 40),
          _MinimalField(controller: emailController, label: 'Correo electrónico', icon: Icons.mail_outline, type: TextInputType.emailAddress),
          const SizedBox(height: 20),
          _MinimalField(controller: passwordController, label: 'Contraseña', icon: Icons.lock_outline, obscure: _obscure,
            suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade400, size: 20), onPressed: () => setState(() => _obscure = !_obscure))),
          const SizedBox(height: 36),
          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : loginUser,
              style: ElevatedButton.styleFrom(backgroundColor: kUserPrimary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Iniciar sesión', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            )),
          const SizedBox(height: 24),
          Center(child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
            child: RichText(text: TextSpan(text: '¿No tienes cuenta? ', style: TextStyle(color: Colors.grey.shade500, fontSize: 13), children: const [TextSpan(text: 'Regístrate', style: TextStyle(color: kUserPrimary, fontWeight: FontWeight.w600))])),
          )),
          const SizedBox(height: 40),
        ]),
      )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA — REGISTRO
// ─────────────────────────────────────────────────────────────────────────────

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nombreController   = TextEditingController();
  final telefonoController = TextEditingController();
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();
  bool _obscure        = true;
  bool _loading        = false;
  bool _aceptaTerminos = false;

  Future registerUser() async {
    if (nombreController.text.trim().isEmpty || telefonoController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty  || passwordController.text.trim().isEmpty) {
      _showError('Por favor completa todos los campos.'); return;
    }

    if (telefonoController.text.trim().length != 10) {
      _showError('El teléfono debe tener exactamente 10 dígitos.'); return;
    }

    if (!_aceptaTerminos) {
      _showError('Debes aceptar los Términos y Condiciones y el Aviso de Privacidad para continuar.'); return;
    }
    setState(() => _loading = true);
    try {
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(), password: passwordController.text.trim(),
      );
      await FirebaseFirestore.instance.collection('usuarios').doc(cred.user!.uid).set({
        'email'                      : emailController.text.trim(),
        'uid'                        : cred.user!.uid,
        'rol'                        : 'usuario',
        'nombre'                     : nombreController.text.trim(),
        'telefono'                   : telefonoController.text.trim(),
        'intercambiosCompletados'    : 0,
        'reputacion'                 : 0.0,
        'terminosAceptados'          : true,
        'terminosAceptadosEn'        : FieldValue.serverTimestamp(),
        'avisoPrivacidadAceptado'    : true,
        'avisoPrivacidadAceptadoEn'  : FieldValue.serverTimestamp(),
        'fotoPerfil'                 : '',
      });
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) { _showError(e.message); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _showError(String? msg) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Error'), content: Text(msg ?? 'Ocurrió un error'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: kUserPrimary)))],
    ));
  }

  void _abrirTerminos() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TerminosCondicionesPage()));

  void _abrirAvisoPrivacidad() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AvisoPrivacidadPage()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: kUserSurface, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new, size: 16, color: kUserPrimary),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Crear cuenta', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 6),
          Text('Únete a la comunidad EcoFlow', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          const SizedBox(height: 36),
          _MinimalField(controller: nombreController,   label: 'Nombre completo',    icon: Icons.person_outline),
          const SizedBox(height: 18),
          _MinimalField(controller: telefonoController, label: 'Teléfono',            icon: Icons.phone_outlined, type: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
          const SizedBox(height: 18),
          _MinimalField(controller: emailController,    label: 'Correo electrónico', icon: Icons.mail_outline,   type: TextInputType.emailAddress),
          const SizedBox(height: 18),
          _MinimalField(
            controller: passwordController, label: 'Contraseña', icon: Icons.lock_outline, obscure: _obscure,
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade400, size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),

          // ── Checkbox: T&C + Aviso de Privacidad ────────────────────────────
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _aceptaTerminos ? kUserSurface : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _aceptaTerminos ? kUserAccent : Colors.grey.shade300,
                width: _aceptaTerminos ? 1.5 : 1,
              ),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 24, height: 24,
                child: Checkbox(
                  value: _aceptaTerminos,
                  onChanged: (v) => setState(() => _aceptaTerminos = v ?? false),
                  activeColor: kUserPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.6),
                    children: [
                      const TextSpan(text: 'He leído y acepto los '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: _abrirTerminos,
                          child: const Text(
                            'Términos y Condiciones',
                            style: TextStyle(
                              fontSize: 13, color: kUserPrimary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: kUserPrimary,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: ' y el '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: _abrirAvisoPrivacidad,
                          child: const Text(
                            'Aviso de Privacidad',
                            style: TextStyle(
                              fontSize: 13, color: kUserPrimary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: kUserPrimary,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: ' de EcoFlow, incluyendo el uso de mi ubicación, cámara y el tratamiento de mis datos personales.'),
                    ],
                  ),
                ),
              ),
            ]),
          ),

          // Texto de ayuda con accesos directos
          const SizedBox(height: 8),
          if (!_aceptaTerminos)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                    children: [
                      const TextSpan(text: 'Toca '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: _abrirTerminos,
                          child: Text('Términos y Condiciones',
                            style: TextStyle(fontSize: 10, color: kUserPrimaryLight, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const TextSpan(text: ' o '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: _abrirAvisoPrivacidad,
                          child: Text('Aviso de Privacidad',
                            style: TextStyle(fontSize: 10, color: kUserPrimaryLight, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const TextSpan(text: ' para leer cada documento.'),
                    ],
                  ),
                ),
              ),
            ]),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : registerUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: _aceptaTerminos ? kUserPrimary : Colors.grey.shade300,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Crear cuenta', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 24),
          Center(child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: RichText(text: TextSpan(
              text: '¿Ya tienes cuenta? ',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              children: const [TextSpan(text: 'Inicia sesión', style: TextStyle(color: kUserPrimary, fontWeight: FontWeight.w600))],
            )),
          )),
          const SizedBox(height: 40),
        ]),
      )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA — HOME (con drawer y navegación inferior)
// ─────────────────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user    = FirebaseAuth.instance.currentUser;
    final esAdmin = user?.email == 'admin@gmail.com';
    if (esAdmin) return _AdminScaffold(user: user!);

    final List<Widget> pages = [
      const _InicioTab(), const _MapaTab(), const _MarcadoresTab(),
      const IntercambiosTab(), const _MasTab(),
    ];

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(user!.uid).snapshots(),
      builder: (context, drawerSnap) {
        final drawerData   = drawerSnap.data?.data() as Map<String, dynamic>?;
        final drawerEmail  = drawerData?['email']  ?? user.email ?? '';
        final drawerNombre = drawerData?['nombre'] ?? '';
        final intercambios = (drawerData?['intercambiosCompletados'] ?? 0) as int;
        final fotoPerfil   = drawerData?['fotoPerfil'] as String? ?? '';

        return Scaffold(
          backgroundColor: kUserSurface,
          appBar: AppBar(
            title: const Text('🏠 Bienvenido'),
            backgroundColor: kUserPrimary, foregroundColor: Colors.white, elevation: 0,
            actions: [
              _BellIcon(uid: user.uid),
              IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
            ],
          ),
          drawer: Drawer(child: ListView(padding: EdgeInsets.zero, children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: kUserPrimaryLight),
              accountName: Text(drawerNombre.isNotEmpty ? drawerNombre : 'Usuario', style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(drawerEmail),
              currentAccountPicture: _UserAvatar(radius: 28, fotoBase64: fotoPerfil),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _LogrosProgressBar(intercambios: intercambios, compact: true),
            ),
            const Divider(height: 8),
            _drawerTile(icon: Icons.person, label: 'Ver mis datos',     onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => VerDatosPage(uid: user.uid))); }),
            _drawerTile(icon: Icons.edit,   label: 'Cambiar mis datos', onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => CambiarDatosPage(uid: user.uid))); }),
            const Divider(),
            _drawerTile(icon: Icons.logout, label: 'Cerrar sesión', color: Colors.red, onTap: () => FirebaseAuth.instance.signOut()),
          ])),
          body: pages[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: kUserPrimary, unselectedItemColor: kUserAccent,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold), elevation: 10,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined),    activeIcon: Icon(Icons.home),       label: 'Inicio'),
              BottomNavigationBarItem(icon: Icon(Icons.map_outlined),     activeIcon: Icon(Icons.map),        label: 'Mapa'),
              BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline), activeIcon: Icon(Icons.bookmark),   label: 'Marcadores'),
              BottomNavigationBarItem(icon: Icon(Icons.swap_horiz),       activeIcon: Icon(Icons.swap_horiz), label: 'Intercambios'),
              BottomNavigationBarItem(icon: Icon(Icons.more_horiz),       activeIcon: Icon(Icons.more_horiz), label: 'Más'),
            ],
          ),
        );
      },
    );
  }

  ListTile _drawerTile({required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
    final c = color ?? kUserPrimaryLight;
    return ListTile(leading: Icon(icon, color: c), title: Text(label, style: TextStyle(color: color)), onTap: onTap);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB — INICIO (presentación de EcoFlow)
// ─────────────────────────────────────────────────────────────────────────────

class _InicioTab extends StatelessWidget {
  const _InicioTab();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _HeroBanner(),
      const _SectionTitle(title: '¿Quiénes Somos?'),
      const _GridCardSection(cards: [
        _CardData(icon: Icons.recycling,     title: 'Nuestra Misión',   body: 'Reducir el impacto ambiental mediante la promoción de la economía circular, conectando empresas y personas para optimizar el uso de recursos a través del reciclaje, reutilización y reparación.'),
        _CardData(icon: Icons.track_changes, title: 'Nuestra Visión',   body: 'Ser la plataforma líder en economía circular, creando una comunidad global comprometida con la sostenibilidad y la regeneración de nuestros recursos naturales.'),
        _CardData(icon: Icons.handshake,     title: 'Nuestros Valores', body: 'Sostenibilidad, innovación, colaboración y transparencia guían cada una de nuestras acciones para construir un futuro más verde y próspero.'),
      ]),
      const _SectionTitle(title: 'Economía Circular'),
      const _GridCardSection(cards: [
        _CardData(icon: Icons.all_inclusive, title: 'Ciclo Continuo',          body: 'Los productos y materiales se mantienen en uso el mayor tiempo posible mediante reutilización y reciclaje.'),
        _CardData(icon: Icons.factory,       title: 'Producción Responsable',  body: 'Diseño de productos que faciliten el desmontaje y la reutilización de componentes.'),
        _CardData(icon: Icons.eco,           title: 'Regeneración Natural',    body: 'Restauración de sistemas naturales y mejora de los recursos ambientales.'),
      ]),
      const _SectionTitle(title: '¿Cómo Funciona EcoFlow?'),
      const _GridCardSection(cards: [
        _CardData(icon: Icons.add_location_alt,   title: 'Registra tu Ubicación', body: 'Empresas y usuarios registran materiales disponibles en su ubicación para ponerlos a disposición de la comunidad.'),
        _CardData(icon: Icons.search,             title: 'Encuentra Recursos',    body: 'Explora el mapa interactivo para descubrir materiales y recursos disponibles cerca de tu ubicación.', highlighted: true),
        _CardData(icon: Icons.handshake_outlined, title: 'Conecta y Colabora',    body: 'Establece contacto directo con proveedores y coordina el intercambio o adquisición de materiales.'),
      ]),
      const SizedBox(height: 32),
    ]));
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF43A047)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.eco, color: Colors.white, size: 14), SizedBox(width: 6), Text('EcoFlow', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5))])),
        const SizedBox(height: 20),
        const Text('Sonreímos\na lo verde 🌿', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2, letterSpacing: -0.5)),
        const SizedBox(height: 16),
        Container(width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.2), width: 1)),
          child: const Text('Transformamos residuos en recursos, creando un futuro circular donde cada material tiene un propósito y cada acción cuenta.', style: TextStyle(color: Colors.white, fontSize: 13, height: 1.6))),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 28, 16, 4), child: Column(children: [
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
      const SizedBox(height: 6),
      Container(width: 48, height: 3, decoration: BoxDecoration(color: kUserPrimaryLight, borderRadius: BorderRadius.circular(2))),
    ]));
  }
}

class _CardData {
  final IconData icon;
  final String title, body;
  final bool highlighted;
  const _CardData({required this.icon, required this.title, required this.body, this.highlighted = false});
}

class _GridCardSection extends StatelessWidget {
  final List<_CardData> cards;
  const _GridCardSection({required this.cards});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85, children: cards.map((c) => _InfoCard(data: c)).toList()));
  }
}

class _InfoCard extends StatelessWidget {
  final _CardData data;
  const _InfoCard({required this.data});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: data.highlighted ? Border.all(color: kUserPrimaryLight, width: 2) : null, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: kUserPrimaryLight, borderRadius: BorderRadius.circular(12)), child: Icon(data.icon, color: Colors.white, size: 22)),
        const SizedBox(height: 12),
        Text(data.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
        const SizedBox(height: 6),
        Expanded(child: Text(data.body, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4), overflow: TextOverflow.fade)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB — MAPA
// ─────────────────────────────────────────────────────────────────────────────

class _MapaTab extends StatefulWidget {
  const _MapaTab();
  @override
  State<_MapaTab> createState() => _MapaTabState();
}

class _MapaTabState extends State<_MapaTab> {
  final MapController _mapController = MapController();
  static const Map<String, Color>    _tipoColor = {'Empresa': Color(0xFF1565C0), 'Emprendimiento': Color(0xFFF57F17), 'Personal': Color(0xFF2E7D32)};
  static const Map<String, IconData> _tipoIcon  = {'Empresa': Icons.business,   'Emprendimiento': Icons.storefront,   'Personal': Icons.person_pin_circle};

  LatLng? _ubicacionUsuario;
  LatLng? _coordenadasSeleccionadas;
  bool _cargandoUbicacion = true;

  @override
  void initState() { super.initState(); _obtenerUbicacion(); }

  Future<void> _obtenerUbicacion() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { setState(() => _cargandoUbicacion = false); return; }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) { setState(() => _cargandoUbicacion = false); return; }
      }
      if (perm == LocationPermission.deniedForever) { setState(() => _cargandoUbicacion = false); return; }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() { _ubicacionUsuario = LatLng(pos.latitude, pos.longitude); _cargandoUbicacion = false; });
    } catch (_) { setState(() => _cargandoUbicacion = false); }
  }

  void _onMapTap(TapPosition t, LatLng ll) {
    setState(() => _coordenadasSeleccionadas = ll);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _FormularioMarcador(coordenadas: ll, tipoColor: _tipoColor, onGuardado: () => setState(() => _coordenadasSeleccionadas = null)),
    );
  }

  void _mostrarDetallesMarcador(BuildContext context, Map<String, dynamic> data, String docId) async {
    final tipo       = data['tipo'] as String? ?? 'Personal';
    final color      = _tipoColor[tipo] ?? kUserPrimary;
    final icon       = _tipoIcon[tipo]  ?? Icons.location_pin;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final esPropio   = data['uid'] == currentUid;

    Map<String, dynamic>? usuarioData;
    try {
      final uid = data['uid'] as String? ?? '';
      if (uid.isNotEmpty) {
        final snap = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
        usuarioData = snap.data();
      }
    } catch (_) {}

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.92,
        builder: (ctx, scrollCtrl) => Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(controller: scrollCtrl, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.75)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 24)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['nombre'] ?? 'Sin nombre', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Text(tipo, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
                ])),
              ]),
            ),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((data['descripcion'] ?? '').isNotEmpty) ...[
                _mapaDetalleSeccion(icon: Icons.description_outlined, titulo: 'Descripción', valor: data['descripcion'], color: color),
                const SizedBox(height: 12),
              ],
              if ((data['materiales'] ?? '').isNotEmpty) ...[
                _mapaDetalleSeccion(icon: Icons.recycling, titulo: 'Materiales Aceptados', valor: data['materiales'], color: color),
                const SizedBox(height: 12),
              ],
              if (usuarioData != null) ...[
                Row(children: [Icon(Icons.contact_phone_outlined, size: 14, color: color), const SizedBox(width: 5), Text('Información de Contacto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))]),
                const SizedBox(height: 8),
                if ((usuarioData['nombre']   ?? '').isNotEmpty) _contactoFilaMapa(Icons.person_outline, usuarioData['nombre']),
                if ((usuarioData['email']    ?? '').isNotEmpty) _contactoFilaMapa(Icons.mail_outline,   usuarioData['email']),
                if ((usuarioData['telefono'] ?? '').isNotEmpty) _contactoFilaMapa(Icons.phone_outlined,  usuarioData['telefono']),
                const SizedBox(height: 12),
              ],
              _mapaDetalleSeccion(
                icon: Icons.location_on_outlined, titulo: 'Coordenadas',
                valor: 'Lat: ${(data['lat'] as num).toStringAsFixed(6)},  Lng: ${(data['lng'] as num).toStringAsFixed(6)}', color: color,
              ),
              const SizedBox(height: 16),
              if (!esPropio) SizedBox(width: double.infinity, height: 46,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Proponer Intercambio / Donación', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(backgroundColor: kUserPrimary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ProponerintercambioPage(marcadorReceptorId: docId, marcadorReceptorData: data))); },
                )),
              const SizedBox(height: 20),
            ])),
          ])),
        ),
      ),
    );
  }

  Widget _mapaDetalleSeccion({required IconData icon, required String titulo, required dynamic valor, required Color color}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 5), Text(titulo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))]),
      const SizedBox(height: 4),
      Padding(padding: const EdgeInsets.only(left: 19), child: Text(valor?.toString() ?? '-', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4))),
    ]);
  }

  Widget _contactoFilaMapa(IconData icon, String texto) {
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 5), child: Row(children: [
      Icon(icon, size: 13, color: Colors.grey.shade400), const SizedBox(width: 6),
      Expanded(child: Text(texto, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoUbicacion) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: kUserPrimary), SizedBox(height: 12),
        Text('Obteniendo ubicación...', style: TextStyle(color: kUserPrimary)),
      ]));
    }
    final center = _ubicacionUsuario ?? const LatLng(21.8853, -102.2916);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('marcadores').snapshots(),
      builder: (context, snapshot) {
        final marcadores = <Marker>[];
        if (_ubicacionUsuario != null) {
          marcadores.add(Marker(point: _ubicacionUsuario!, width: 40, height: 40, child: Container(
            decoration: BoxDecoration(color: Colors.blue.shade700, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 8)]),
            child: const Icon(Icons.my_location, color: Colors.white, size: 20),
          )));
        }
        if (_coordenadasSeleccionadas != null) {
          marcadores.add(Marker(point: _coordenadasSeleccionadas!, width: 40, height: 50, child: Column(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.add_location, color: Colors.white, size: 20)),
            Container(width: 2, height: 10, color: Colors.grey.shade400),
          ])));
        }
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final lat  = (data['lat'] as num?)?.toDouble();
            final lng  = (data['lng'] as num?)?.toDouble();
            final tipo = data['tipo'] as String? ?? 'Personal';
            if (lat == null || lng == null) continue;
            final color = _tipoColor[tipo] ?? kUserPrimary;
            final icon  = _tipoIcon[tipo]  ?? Icons.location_pin;
            marcadores.add(Marker(point: LatLng(lat, lng), width: 44, height: 54, child: GestureDetector(
              onTap: () => _mostrarDetallesMarcador(context, data, doc.id),
              child: Column(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))]), child: Icon(icon, color: Colors.white, size: 20)),
                Container(width: 2, height: 10, color: color),
              ]),
            )));
          }
        }
        return Stack(children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 14, onTap: _onMapTap),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.ecoflow.app'),
              MarkerLayer(markers: marcadores),
            ],
          ),
          Positioned(bottom: 20, left: 12, child: _Leyenda(tipoColor: _tipoColor, tipoIcon: _tipoIcon)),
          Positioned(top: 12, right: 12, child: FloatingActionButton.small(
            heroTag: 'miUbicacion', backgroundColor: Colors.white, foregroundColor: kUserPrimary, elevation: 3,
            onPressed: () { if (_ubicacionUsuario != null) { _mapController.move(_ubicacionUsuario!, 15); } else { _obtenerUbicacion(); } },
            child: const Icon(Icons.my_location),
          )),
          Positioned(top: 12, left: 0, right: 60, child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)]),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.touch_app, size: 14, color: kUserPrimary), SizedBox(width: 5), Text('Toca el mapa para agregar un marcador', style: TextStyle(fontSize: 11, color: kUserPrimary))]),
          ))),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — LEYENDA DEL MAPA
// ─────────────────────────────────────────────────────────────────────────────

class _Leyenda extends StatelessWidget {
  final Map<String, Color>    tipoColor;
  final Map<String, IconData> tipoIcon;
  const _Leyenda({required this.tipoColor, required this.tipoIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: tipoColor.entries.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 26, height: 26, decoration: BoxDecoration(color: e.value, shape: BoxShape.circle), child: Icon(tipoIcon[e.key], color: Colors.white, size: 14)),
          const SizedBox(width: 8),
          Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ]))).toList()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — FORMULARIO PARA NUEVO MARCADOR
// ─────────────────────────────────────────────────────────────────────────────

class _FormularioMarcador extends StatefulWidget {
  final LatLng coordenadas;
  final Map<String, Color> tipoColor;
  final VoidCallback onGuardado;
  const _FormularioMarcador({required this.coordenadas, required this.tipoColor, required this.onGuardado});

  @override
  State<_FormularioMarcador> createState() => _FormularioMarcadorState();
}

class _FormularioMarcadorState extends State<_FormularioMarcador> {
  final _nombreCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _matsCtrl   = TextEditingController();
  String _tipoSel   = 'Personal';
  bool _guardando   = false;

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty || _matsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor completa todos los campos'), backgroundColor: Colors.orange)); return;
    }
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance.collection('marcadores').add({
        'nombre': _nombreCtrl.text.trim(), 'descripcion': _descCtrl.text.trim(), 'materiales': _matsCtrl.text.trim(),
        'tipo': _tipoSel, 'lat': widget.coordenadas.latitude, 'lng': widget.coordenadas.longitude,
        'creadoEn': FieldValue.serverTimestamp(), 'uid': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      widget.onGuardado();
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Marcador creado'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _guardando = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(margin: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: kUserSurface, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_location_alt, color: kUserPrimary, size: 20)), const SizedBox(width: 10), const Text('Nuevo marcador', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 6),
          Row(children: [const SizedBox(width: 46), Icon(Icons.location_on, size: 12, color: Colors.grey.shade400), const SizedBox(width: 3), Text('${widget.coordenadas.latitude.toStringAsFixed(5)}, ${widget.coordenadas.longitude.toStringAsFixed(5)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400))]),
          const SizedBox(height: 20),
          _MinimalField(controller: _nombreCtrl, label: 'Nombre del negocio',     icon: Icons.storefront_outlined),
          const SizedBox(height: 14),
          _MinimalField(controller: _descCtrl,   label: 'Descripción',            icon: Icons.description_outlined),
          const SizedBox(height: 14),
          _MinimalField(controller: _matsCtrl,   label: 'Materiales reciclables', icon: Icons.recycling),
          const SizedBox(height: 18),
          Text('Tipo de negocio', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(children: widget.tipoColor.entries.map((e) {
            final sel = _tipoSel == e.key;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _tipoSel = e.key),
              child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: sel ? e.value : e.value.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? e.value : e.value.withOpacity(0.2), width: 1.5)),
                child: Text(e.key, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white : e.value)))));
          }).toList()),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: _guardando ? null : _guardar,
            style: ElevatedButton.styleFrom(backgroundColor: kUserPrimary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _guardando ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Guardar marcador', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          )),
        ])),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB — MARCADORES
// ─────────────────────────────────────────────────────────────────────────────

class _MarcadoresTab extends StatefulWidget {
  const _MarcadoresTab();
  @override
  State<_MarcadoresTab> createState() => _MarcadoresTabState();
}

class _MarcadoresTabState extends State<_MarcadoresTab> {
  bool _soloMios = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  static const Map<String, Color>    _tipoColor = {'Empresa': Color(0xFF1565C0), 'Emprendimiento': Color(0xFFF57F17), 'Personal': Color(0xFF2E7D32)};
  static const Map<String, IconData> _tipoIcon  = {'Empresa': Icons.business,   'Emprendimiento': Icons.storefront,   'Personal': Icons.person_pin_circle};

  @override
  void initState() { super.initState(); _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase())); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  bool _matches(Map<String, dynamic> marcador, Map<String, dynamic>? usuario) {
    if (_query.isEmpty) return true;
    final nombre   = (marcador['nombre']   ?? '').toString().toLowerCase();
    final correo   = (usuario?['email']    ?? '').toString().toLowerCase();
    final telefono = (usuario?['telefono'] ?? '').toString().toLowerCase();
    return nombre.contains(_query) || correo.contains(_query) || telefono.contains(_query);
  }

  void _editarMarcador(BuildContext ctx, String docId, Map<String, dynamic> data) {
    final nCtrl = TextEditingController(text: data['nombre'] ?? '');
    final dCtrl = TextEditingController(text: data['descripcion'] ?? '');
    final mCtrl = TextEditingController(text: data['materiales'] ?? '');
    String tipoSel = data['tipo'] ?? 'Personal';
    bool guardando = false;
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (bsCtx) => StatefulBuilder(builder: (bsCtx, setM) {
      return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(bsCtx).viewInsets.bottom),
        child: Container(margin: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 28), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: kUserSurface, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.edit_location_alt, color: kUserPrimary, size: 20)), const SizedBox(width: 10), const Text('Editar marcador', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 20),
            _MinimalField(controller: nCtrl, label: 'Nombre',      icon: Icons.storefront_outlined), const SizedBox(height: 14),
            _MinimalField(controller: dCtrl, label: 'Descripción', icon: Icons.description_outlined), const SizedBox(height: 14),
            _MinimalField(controller: mCtrl, label: 'Materiales',  icon: Icons.recycling), const SizedBox(height: 18),
            Text('Tipo', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)), const SizedBox(height: 8),
            Row(children: _tipoColor.entries.map((e) {
              final s = tipoSel == e.key;
              return Expanded(child: GestureDetector(onTap: () => setM(() => tipoSel = e.key), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: s ? e.value : e.value.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: s ? e.value : e.value.withOpacity(0.2), width: 1.5)),
                child: Text(e.key, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: s ? Colors.white : e.value)))));
            }).toList()),
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
              onPressed: guardando ? null : () async {
                setM(() => guardando = true);
                try {
                  await FirebaseFirestore.instance.collection('marcadores').doc(docId).update({'nombre': nCtrl.text.trim(), 'descripcion': dCtrl.text.trim(), 'materiales': mCtrl.text.trim(), 'tipo': tipoSel});
                  if (bsCtx.mounted) Navigator.pop(bsCtx);
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('✅ Marcador actualizado'), backgroundColor: Colors.green));
                } catch (e) { setM(() => guardando = false); }
              },
              style: ElevatedButton.styleFrom(backgroundColor: kUserPrimary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: guardando ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w600)),
            )),
          ])),
        ),
      );
    }));
  }

  void _eliminarMarcador(BuildContext ctx, String docId) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('¿Eliminar?'), content: const Text('Esta acción no se puede deshacer.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        TextButton(onPressed: () async { Navigator.pop(ctx); await FirebaseFirestore.instance.collection('marcadores').doc(docId).delete(); }, child: const Text('Eliminar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
      ],
    ));
  }

  Future<Map<String, Map<String, dynamic>>> _fetchUsuariosMap(List<QueryDocumentSnapshot> docs) async {
    final uids = docs.map((d) => (d.data() as Map<String, dynamic>)['uid'] as String? ?? '').where((u) => u.isNotEmpty).toSet().toList();
    final Map<String, Map<String, dynamic>> result = {};
    for (final uid in uids) {
      final snap = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (snap.exists) result[uid] = snap.data() as Map<String, dynamic>;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: kUserSurface,
      body: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: Column(children: [
          Container(decoration: BoxDecoration(color: kUserSurface, borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.all(4),
            child: Row(children: [
              _SegmentBtn(label: 'Mis marcadores', icon: Icons.person_pin_circle_outlined, active: _soloMios,  onTap: () => setState(() => _soloMios = true)),
              _SegmentBtn(label: 'Todos',          icon: Icons.public,                    active: !_soloMios, onTap: () => setState(() => _soloMios = false)),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(controller: _searchCtrl, style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, correo o teléfono…', hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade400),
              suffixIcon: _query.isNotEmpty ? IconButton(icon: Icon(Icons.close, size: 18, color: Colors.grey.shade400), onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); }) : null,
              filled: true, fillColor: const Color(0xFFF7F7F7), contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kUserPrimary, width: 1.5)),
            )),
          const SizedBox(height: 12),
        ])),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('marcadores').orderBy('creadoEn', descending: true).snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kUserPrimary));
            if (!snap.hasData || snap.data!.docs.isEmpty) return _EmptyState(soloMios: _soloMios);
            final docs = snap.data!.docs.where((d) { final data = d.data() as Map<String, dynamic>; return !(_soloMios && data['uid'] != currentUid); }).toList();
            if (docs.isEmpty) return _EmptyState(soloMios: _soloMios);
            return FutureBuilder<Map<String, Map<String, dynamic>>>(
              future: _fetchUsuariosMap(docs),
              builder: (ctx, userSnap) {
                final usuariosMap = userSnap.data ?? {};
                final filtered = docs.where((d) { final data = d.data() as Map<String, dynamic>; final uid = data['uid'] as String? ?? ''; return _matches(data, usuariosMap[uid]); }).toList();
                if (filtered.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.search_off, size: 56, color: kUserAccent), const SizedBox(height: 12), Text('Sin resultados para "$_query"', style: const TextStyle(color: kUserPrimary, fontWeight: FontWeight.bold))]));
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final doc = filtered[i]; final data = doc.data() as Map<String, dynamic>;
                    final uid = data['uid'] as String? ?? ''; final usuario = usuariosMap[uid]; final esMio = uid == currentUid;
                    return _MarcadorCard(docId: doc.id, data: data, usuario: usuario, esMio: esMio && _soloMios, tipoColor: _tipoColor, tipoIcon: _tipoIcon,
                      onEditar: () => _editarMarcador(context, doc.id, data), onEliminar: () => _eliminarMarcador(context, doc.id),
                      onIntercambiar: esMio ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProponerintercambioPage(marcadorReceptorId: doc.id, marcadorReceptorData: data))));
                  },
                );
              },
            );
          },
        )),
      ]),
    );
  }
}

class _SegmentBtn extends StatelessWidget {
  final String label; final IconData icon; final bool active; final VoidCallback onTap;
  const _SegmentBtn({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 220), padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: active ? kUserPrimary : Colors.transparent, borderRadius: BorderRadius.circular(10), boxShadow: active ? [BoxShadow(color: kUserPrimary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : []),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 15, color: active ? Colors.white : Colors.grey.shade600), const SizedBox(width: 5), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : Colors.grey.shade600))]))));
  }
}

class _MarcadorCard extends StatelessWidget {
  final String docId; final Map<String, dynamic> data; final Map<String, dynamic>? usuario;
  final bool esMio; final Map<String, Color> tipoColor; final Map<String, IconData> tipoIcon;
  final VoidCallback onEditar, onEliminar; final VoidCallback? onIntercambiar;
  const _MarcadorCard({required this.docId, required this.data, required this.usuario, required this.esMio, required this.tipoColor, required this.tipoIcon, required this.onEditar, required this.onEliminar, this.onIntercambiar});

  @override
  Widget build(BuildContext context) {
    final tipo = data['tipo'] as String? ?? 'Personal'; final color = tipoColor[tipo] ?? kUserPrimary; final icon = tipoIcon[tipo] ?? Icons.location_pin;
    final contactNombre = usuario?['nombre'] ?? ''; final contactEmail = usuario?['email'] ?? ''; final contactTelefono = usuario?['telefono'] ?? '';
    final intercambios = (usuario?['intercambiosCompletados'] ?? 0) as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.75)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['nombre'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Text(tipo, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))), const SizedBox(width: 6), _ReputacionBadge(intercambios: intercambios, small: true)]),
            ])),
            if (esMio) ...[
              IconButton(icon: const Icon(Icons.edit_outlined,  color: Colors.white, size: 20), onPressed: onEditar,   visualDensity: VisualDensity.compact),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20), onPressed: onEliminar, visualDensity: VisualDensity.compact),
            ],
          ])),
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CardSection(icon: Icons.description_outlined,   iconColor: color, title: 'Descripción',            child: Text(data['descripcion'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4))),
          const SizedBox(height: 12),
          _CardSection(icon: Icons.recycling,              iconColor: color, title: 'Materiales Aceptados',   child: Text(data['materiales'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4))),
          const SizedBox(height: 12),
          _CardSection(icon: Icons.contact_phone_outlined, iconColor: color, title: 'Información de Contacto', child: Column(children: [
            if (contactNombre.isNotEmpty)   _ContactRow(icon: Icons.person_outline, value: contactNombre,   color: color),
            if (contactEmail.isNotEmpty)    _ContactRow(icon: Icons.email_outlined,  value: contactEmail,    color: color),
            if (contactTelefono.isNotEmpty) _ContactRow(icon: Icons.phone_outlined,  value: contactTelefono, color: color),
            if (contactNombre.isEmpty && contactEmail.isEmpty && contactTelefono.isEmpty) Text('Sin información', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ])),
          const SizedBox(height: 12),
          _CardSection(icon: Icons.location_on_outlined, iconColor: color, title: 'Ubicación', child: Row(children: [Icon(Icons.pin_drop_outlined, size: 14, color: color), const SizedBox(width: 4), Text('Lat: ${(data['lat'] as num?)?.toStringAsFixed(6) ?? '-'},  Lng: ${(data['lng'] as num?)?.toStringAsFixed(6) ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))])),
          if (onIntercambiar != null) ...[
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, height: 42, child: ElevatedButton.icon(icon: const Icon(Icons.swap_horiz, size: 16), label: const Text('Proponer Intercambio / Donación', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), style: ElevatedButton.styleFrom(backgroundColor: kUserPrimary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: onIntercambiar)),
          ],
        ])),
      ]),
    );
  }
}

class _CardSection extends StatelessWidget {
  final IconData icon; final Color iconColor; final String title; final Widget child;
  const _CardSection({required this.icon, required this.iconColor, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 15, color: iconColor), const SizedBox(width: 5), Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: iconColor))]),
      const SizedBox(height: 6),
      Padding(padding: const EdgeInsets.only(left: 20), child: child),
    ]);
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon; final String value; final Color color;
  const _ContactRow({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: Colors.grey.shade700), maxLines: 1, overflow: TextOverflow.ellipsis))]));
  }
}

class _EmptyState extends StatelessWidget {
  final bool soloMios;
  const _EmptyState({required this.soloMios});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(soloMios ? Icons.person_pin_circle_outlined : Icons.bookmark_border, size: 64, color: kUserAccent),
      const SizedBox(height: 16),
      Text(soloMios ? 'Aún no tienes marcadores' : 'No hay marcadores aún', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kUserPrimary)),
      const SizedBox(height: 8),
      Text(soloMios ? 'Ve al Mapa y toca para agregar uno' : 'Sé el primero en agregar uno', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
    ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA — PROPONER INTERCAMBIO / DONACIÓN
// ─────────────────────────────────────────────────────────────────────────────

class ProponerintercambioPage extends StatefulWidget {
  final String marcadorReceptorId;
  final Map<String, dynamic> marcadorReceptorData;
  const ProponerintercambioPage({required this.marcadorReceptorId, required this.marcadorReceptorData, super.key});

  @override
  State<ProponerintercambioPage> createState() => _ProponerintercambioPageState();
}

class _ProponerintercambioPageState extends State<ProponerintercambioPage> {
  List<Map<String, dynamic>> _misMarcadores = [];
  String? _marcadorSeleccionadoId;
  Map<String, dynamic>? _marcadorSeleccionadoData;
  bool _cargando = true, _enviando = false, _esDonacion = false;

  @override
  void initState() { super.initState(); _cargarMisMarcadores(); }

  Future<void> _cargarMisMarcadores() async {
    final uid  = FirebaseAuth.instance.currentUser?.uid ?? '';
    final snap = await FirebaseFirestore.instance.collection('marcadores').where('uid', isEqualTo: uid).get();
    setState(() { _misMarcadores = snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList(); _cargando = false; });
  }

  Future<bool> _yaExisteIntercambio(String currentUid, String receptorUid) async {
    final snap = await FirebaseFirestore.instance.collection('intercambios').where('solicitanteUid', isEqualTo: currentUid).where('receptorUid', isEqualTo: receptorUid).get();
    for (final doc in snap.docs) { final estado = (doc.data())['estado'] as String? ?? ''; if (estado == 'pendiente' || estado == 'aceptado') return true; }
    return false;
  }

  Future<void> _enviarSolicitud() async {
    if (!_esDonacion && (_marcadorSeleccionadoId == null || _marcadorSeleccionadoData == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un marcador o activa el modo donación'), backgroundColor: Colors.orange)); return;
    }
    setState(() => _enviando = true);
    try {
      final currentUser  = FirebaseAuth.instance.currentUser!;
      final miSnap       = await FirebaseFirestore.instance.collection('usuarios').doc(currentUser.uid).get();
      final miData       = miSnap.data() as Map<String, dynamic>? ?? {};
      final receptorUid  = widget.marcadorReceptorData['uid'] as String? ?? '';
      final existeDup    = await _yaExisteIntercambio(currentUser.uid, receptorUid);
      if (existeDup) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya tienes una solicitud activa con este usuario.'), backgroundColor: Colors.orange, duration: Duration(seconds: 4))); setState(() => _enviando = false); return; }
      final receptorSnap = await FirebaseFirestore.instance.collection('usuarios').doc(receptorUid).get();
      final receptorData = receptorSnap.data() as Map<String, dynamic>? ?? {};
      await FirebaseFirestore.instance.collection('intercambios').add({
        'solicitanteUid': currentUser.uid, 'solicitanteNombre': miData['nombre'] ?? '', 'solicitanteEmail': miData['email'] ?? '',
        'receptorUid': receptorUid, 'receptorNombre': receptorData['nombre'] ?? '', 'receptorEmail': receptorData['email'] ?? '',
        'marcadorIdSolicitante': _esDonacion ? null : _marcadorSeleccionadoId,
        'marcadorNombreSolicitante': _esDonacion ? 'Sin marcador (donación)' : (_marcadorSeleccionadoData?['nombre'] ?? ''),
        'materialesSolicitante': _esDonacion ? '' : (_marcadorSeleccionadoData?['materiales'] ?? ''),
        'marcadorIdReceptor': widget.marcadorReceptorId, 'marcadorNombreReceptor': widget.marcadorReceptorData['nombre'] ?? '',
        'materialesReceptor': widget.marcadorReceptorData['materiales'] ?? '',
        'esDonacion': _esDonacion, 'estado': 'pendiente',
        'aceptadoSolicitante': false, 'aceptadoReceptor': false,
        'creadoEn': FieldValue.serverTimestamp(), 'actualizadoEn': FieldValue.serverTimestamp(),
      });
      final modoTexto = _esDonacion ? 'donación' : 'intercambio';
      await crearNotificacion(uid: receptorUid, titulo: '🔄 Nueva solicitud de $modoTexto', cuerpo: '${miData['nombre'] ?? 'Alguien'} quiere ${_esDonacion ? 'solicitar una donación de' : 'intercambiar por'} "${widget.marcadorReceptorData['nombre']}".', tipo: 'intercambio_solicitado');
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Solicitud de $modoTexto enviada'), backgroundColor: Colors.green)); Navigator.pop(context); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => _enviando = false); }
  }

  @override
  Widget build(BuildContext context) {
    final receptorNombre     = widget.marcadorReceptorData['nombre'] ?? '';
    final receptorMateriales = widget.marcadorReceptorData['materiales'] ?? '';
    return Scaffold(
      backgroundColor: kUserSurface,
      appBar: AppBar(title: const Text('Proponer Intercambio / Donación'), backgroundColor: kUserPrimary, foregroundColor: Colors.white, elevation: 0),
      body: _cargando ? const Center(child: CircularProgressIndicator(color: kUserPrimary)) : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF43A047)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ellos ofrecen:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(receptorNombre, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [const Icon(Icons.recycling, color: Colors.white70, size: 14), const SizedBox(width: 6), Expanded(child: Text(receptorMateriales, style: const TextStyle(color: Colors.white, fontSize: 13)))]),
          ])),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _esDonacion ? Colors.orange.shade300 : Colors.grey.shade200)),
          child: Row(children: [
            Icon(_esDonacion ? Icons.volunteer_activism : Icons.swap_horiz, color: _esDonacion ? Colors.orange : kUserPrimary, size: 20), const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_esDonacion ? 'Modo: Donación' : 'Modo: Intercambio', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _esDonacion ? Colors.orange.shade800 : kUserPrimary)),
              Text(_esDonacion ? 'Sin marcador propio. Coordina en el chat.' : 'Selecciona un marcador para ofrecer.', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ])),
            Switch(value: _esDonacion, onChanged: (v) => setState(() { _esDonacion = v; if (v) { _marcadorSeleccionadoId = null; _marcadorSeleccionadoData = null; } }), activeColor: Colors.orange),
          ])),
        const SizedBox(height: 16),
        if (!_esDonacion) ...[
          const Text('¿Qué ofreces tú?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
          const SizedBox(height: 12),
          if (_misMarcadores.isEmpty)
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)), child: Row(children: [Icon(Icons.warning_amber_outlined, color: Colors.orange.shade600), const SizedBox(width: 10), const Expanded(child: Text('No tienes marcadores. Activa modo donación o agrega uno.', style: TextStyle(fontSize: 13)))]))
          else ..._misMarcadores.map((m) {
            final sel = _marcadorSeleccionadoId == m['id'];
            return GestureDetector(onTap: () => setState(() { _marcadorSeleccionadoId = m['id']; _marcadorSeleccionadoData = m; }),
              child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: sel ? kUserSurface : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: sel ? kUserPrimary : Colors.grey.shade200, width: sel ? 2 : 1)),
                child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: sel ? kUserPrimary : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.location_on, color: sel ? Colors.white : Colors.grey.shade400, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m['nombre'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: sel ? kUserPrimary : const Color(0xFF1A1A1A))), Text(m['materiales'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis)])), if (sel) const Icon(Icons.check_circle, color: kUserPrimary, size: 22)])));
          }),
          const SizedBox(height: 16),
        ],
        if (_esDonacion || _marcadorSeleccionadoData != null)
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kUserAccent.withOpacity(0.5))),
            child: Column(children: [
              Text(_esDonacion ? 'Resumen de donación' : 'Resumen del intercambio', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kUserPrimary)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(children: [Icon(_esDonacion ? Icons.volunteer_activism : Icons.person_outline, color: _esDonacion ? Colors.orange : kUserPrimary, size: 20), const SizedBox(height: 4), Text(_esDonacion ? 'Tú solicitas' : 'Tú ofreces', style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(_esDonacion ? 'Donación' : (_marcadorSeleccionadoData!['nombre'] ?? ''), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)])),
                Icon(_esDonacion ? Icons.arrow_forward : Icons.swap_horiz, color: kUserPrimaryLight, size: 28),
                Expanded(child: Column(children: [const Icon(Icons.storefront_outlined, color: kUserPrimary, size: 20), const SizedBox(height: 4), const Text('Ellos ofrecen', style: TextStyle(fontSize: 10, color: Colors.grey)), Text(receptorNombre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)])),
              ]),
            ])),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
          child: Row(children: [const Icon(Icons.info_outline, color: Colors.orange, size: 18), const SizedBox(width: 8), Expanded(child: Text(_esDonacion ? 'En modo donación coordina los detalles en el chat una vez aceptada.' : 'El intercambio se concreta cuando AMBAS partes acepten.', style: const TextStyle(fontSize: 11, color: Color(0xFF5D4037), height: 1.4)))])),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
          icon: _enviando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(_esDonacion ? Icons.volunteer_activism : Icons.send, size: 18),
          label: Text(_enviando ? 'Enviando...' : (_esDonacion ? 'Enviar solicitud de donación' : 'Enviar solicitud de intercambio'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(backgroundColor: _esDonacion ? Colors.orange.shade700 : kUserPrimary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _enviando ? null : _enviarSolicitud,
        )),
        const SizedBox(height: 24),
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB — INTERCAMBIOS
// ─────────────────────────────────────────────────────────────────────────────

class IntercambiosTab extends StatefulWidget {
  const IntercambiosTab({super.key});
  @override
  State<IntercambiosTab> createState() => _IntercambiosTabState();
}

class _IntercambiosTabState extends State<IntercambiosTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() { super.initState(); _tabController = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: kUserSurface,
      body: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: Column(children: [
          Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: kUserSurface, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.swap_horiz, color: kUserPrimary, size: 20)), const SizedBox(width: 10), const Text('Mis Intercambios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)))]),
          const SizedBox(height: 12),
          TabBar(controller: _tabController, labelColor: kUserPrimary, unselectedLabelColor: Colors.grey.shade500, indicatorColor: kUserPrimary, indicatorWeight: 2, labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), tabs: const [Tab(text: 'Pendientes'), Tab(text: 'Historial')]),
        ])),
        Expanded(child: TabBarView(controller: _tabController, children: [
          _IntercambiosList(uid: uid, estados: const ['pendiente', 'aceptado']),
          _IntercambiosList(uid: uid, estados: const ['completado', 'rechazado', 'cancelado']),
        ])),
      ]),
    );
  }
}

class _IntercambiosList extends StatelessWidget {
  final String uid; final List<String> estados;
  const _IntercambiosList({required this.uid, required this.estados});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('intercambios').orderBy('creadoEn', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kUserPrimary));
        if (!snap.hasData) return const SizedBox();
        final docs = snap.data!.docs.where((d) { final data = d.data() as Map<String, dynamic>; return (data['solicitanteUid'] == uid || data['receptorUid'] == uid) && estados.contains(data['estado'] as String? ?? ''); }).toList();
        if (docs.isEmpty) {
          final esPendientes = estados.contains('pendiente');
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.swap_horiz, size: 56, color: kUserAccent), const SizedBox(height: 12), Text(esPendientes ? 'Sin solicitudes activas' : 'Sin historial aún', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kUserPrimary)), const SizedBox(height: 8), Text('Ve al Mapa y propone un intercambio', style: TextStyle(color: Colors.grey.shade500, fontSize: 12))]));
        }
        return ListView.builder(padding: const EdgeInsets.all(12), itemCount: docs.length, itemBuilder: (ctx, i) {
          final doc = docs[i]; final data = doc.data() as Map<String, dynamic>;
          return _IntercambioCard(intercambioId: doc.id, data: data, currentUid: uid);
        });
      },
    );
  }
}

class _IntercambioCard extends StatelessWidget {
  final String intercambioId; final Map<String, dynamic> data; final String currentUid;
  const _IntercambioCard({required this.intercambioId, required this.data, required this.currentUid});

  Color get _estadoColor { switch (data['estado']) { case 'pendiente': return const Color(0xFFF57F17); case 'aceptado': return const Color(0xFF1565C0); case 'completado': return const Color(0xFF2E7D32); case 'rechazado': return Colors.red; default: return Colors.grey; } }
  String get _estadoLabel { switch (data['estado']) { case 'pendiente': return '⏳ Pendiente'; case 'aceptado': return '🤝 En curso'; case 'completado': return '✅ Completado'; case 'rechazado': return '❌ Rechazado'; default: return '🚫 Cancelado'; } }
  bool get _soySolicitante => data['solicitanteUid'] == currentUid;
  bool get _esDonacion => data['esDonacion'] as bool? ?? false;

  @override
  Widget build(BuildContext context) {
    final miMarcador   = _soySolicitante ? (data['marcadorNombreSolicitante'] ?? '') : (data['marcadorNombreReceptor'] ?? '');
    final otroMarcador = _soySolicitante ? (data['marcadorNombreReceptor']    ?? '') : (data['marcadorNombreSolicitante'] ?? '');
    final otroNombre   = _soySolicitante ? (data['receptorNombre']    ?? '') : (data['solicitanteNombre'] ?? '');

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetallIntercambioPage(intercambioId: intercambioId))),
      child: Container(margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))]),
        child: Column(children: [
          Container(height: 5, decoration: BoxDecoration(color: _estadoColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(18)))),
          Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _estadoColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Text(_estadoLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _estadoColor))),
              Row(children: [
                if (_esDonacion) Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)), child: Text('Donación', style: TextStyle(fontSize: 9, color: Colors.orange.shade800, fontWeight: FontWeight.w600))),
                Text(_soySolicitante ? 'Tú solicitaste' : 'Te solicitaron', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ]),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _MiniMarcadorChip(nombre: _esDonacion && _soySolicitante ? 'Donación' : miMarcador, label: 'Tú', color: kUserPrimary)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Column(children: [Icon(_esDonacion ? Icons.arrow_forward : Icons.swap_horiz, color: kUserPrimaryLight, size: 24), Text(_esDonacion ? 'solicita' : 'con', style: TextStyle(fontSize: 9, color: Colors.grey.shade400))])),
              Expanded(child: _MiniMarcadorChip(nombre: otroMarcador, label: otroNombre, color: const Color(0xFF1565C0))),
            ]),
            if (data['estado'] == 'pendiente' || data['estado'] == 'aceptado') ...[
              const SizedBox(height: 10),
              Row(children: [Icon(Icons.info_outline, size: 12, color: Colors.grey.shade400), const SizedBox(width: 4), Text('Toca para ver detalles y chatear', style: TextStyle(fontSize: 10, color: Colors.grey.shade400))]),
            ],
          ])),
        ]),
      ),
    );
  }
}

class _MiniMarcadorChip extends StatelessWidget {
  final String nombre, label; final Color color;
  const _MiniMarcadorChip({required this.nombre, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.25))),
      child: Column(children: [Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)), const SizedBox(height: 3), Text(nombre, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA — DETALLE DEL INTERCAMBIO
// ─────────────────────────────────────────────────────────────────────────────

class DetallIntercambioPage extends StatefulWidget {
  final String intercambioId;
  const DetallIntercambioPage({required this.intercambioId, super.key});

  @override
  State<DetallIntercambioPage> createState() => _DetallIntercambioPageState();
}

class _DetallIntercambioPageState extends State<DetallIntercambioPage> {
  final _chatCtrl = TextEditingController();
  bool _enviandoMensaje = false, _procesando = false;
  bool _chatVisible = false;

  Future<void> _aceptarIntercambio(Map<String, dynamic> data) async {
    setState(() => _procesando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final esSol = data['solicitanteUid'] == uid;
      final campoPropio = esSol ? 'aceptadoSolicitante' : 'aceptadoReceptor';
      final campoOtro   = esSol ? 'aceptadoReceptor' : 'aceptadoSolicitante';
      final yaAceptoOtro = data[campoOtro] as bool? ?? false;
      final uidOtro      = esSol ? data['receptorUid'] : data['solicitanteUid'];
      final nombreOtro   = esSol ? data['receptorNombre'] : data['solicitanteNombre'];
      final miSnap   = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final miNombre = (miSnap.data() as Map<String, dynamic>?)?['nombre'] ?? 'Usuario';
      if (yaAceptoOtro) {
        await FirebaseFirestore.instance.collection('intercambios').doc(widget.intercambioId).update({'estado': 'completado', campoPropio: true, 'actualizadoEn': FieldValue.serverTimestamp()});
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({'intercambiosCompletados': FieldValue.increment(1)});
        await FirebaseFirestore.instance.collection('usuarios').doc(uidOtro as String).update({'intercambiosCompletados': FieldValue.increment(1)});
        await crearNotificacion(uid: uid,     titulo: '🎉 ¡Intercambio completado!', cuerpo: 'El intercambio con $nombreOtro ha sido completado.', tipo: 'intercambio_completado');
        await crearNotificacion(uid: uidOtro, titulo: '🎉 ¡Intercambio completado!', cuerpo: 'El intercambio con $miNombre ha sido completado.', tipo: 'intercambio_completado');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 ¡Intercambio completado!'), backgroundColor: Colors.green, duration: Duration(seconds: 3)));
      } else {
        await FirebaseFirestore.instance.collection('intercambios').doc(widget.intercambioId).update({campoPropio: true, 'estado': 'aceptado', 'actualizadoEn': FieldValue.serverTimestamp()});
        await crearNotificacion(uid: uidOtro as String, titulo: '✅ $miNombre aceptó', cuerpo: 'Ahora tú también debes aceptar para completar.', tipo: 'intercambio_aceptado');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Aceptaste. Esperando a la otra parte.'), backgroundColor: Colors.blue));
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => _procesando = false); }
  }

  Future<void> _rechazarIntercambio(Map<String, dynamic> data) async {
    final uid   = FirebaseAuth.instance.currentUser?.uid ?? '';
    final esSol = data['solicitanteUid'] == uid;
    final uidOtro = esSol ? data['receptorUid'] : data['solicitanteUid'];
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('¿Rechazar?'), content: const Text('El otro usuario será notificado.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Rechazar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))]));
    if (confirm != true) return;
    setState(() => _procesando = true);
    try {
      final miSnap   = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final miNombre = (miSnap.data() as Map<String, dynamic>?)?['nombre'] ?? 'Usuario';
      await FirebaseFirestore.instance.collection('intercambios').doc(widget.intercambioId).update({'estado': 'rechazado', 'actualizadoEn': FieldValue.serverTimestamp()});
      await crearNotificacion(uid: uidOtro as String, titulo: '❌ Intercambio rechazado', cuerpo: '$miNombre rechazó la propuesta.', tipo: 'intercambio_rechazado');
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intercambio rechazado'), backgroundColor: Colors.red)); Navigator.pop(context); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => _procesando = false); }
  }

  Future<void> _cancelarIntercambio(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final esSol = data['solicitanteUid'] == uid;
    final uidOtro = esSol ? data['receptorUid'] : data['solicitanteUid'];
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('¿Cancelar?'), content: const Text('Podrás iniciar uno nuevo.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No', style: TextStyle(color: Colors.grey))), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, cancelar', style: TextStyle(color: Colors.red)))]));
    if (confirm != true) return;
    setState(() => _procesando = true);
    try {
      final miSnap   = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final miNombre = (miSnap.data() as Map<String, dynamic>?)?['nombre'] ?? 'Usuario';
      await FirebaseFirestore.instance.collection('intercambios').doc(widget.intercambioId).update({'estado': 'cancelado', 'actualizadoEn': FieldValue.serverTimestamp()});
      await crearNotificacion(uid: uidOtro as String, titulo: '🚫 Intercambio cancelado', cuerpo: '$miNombre canceló el intercambio.', tipo: 'intercambio_rechazado');
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Intercambio cancelado'), backgroundColor: Colors.grey)); Navigator.pop(context); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => _procesando = false); }
  }

  Future<void> _enviarMensaje(String id, String nombre) async {
    final texto = _chatCtrl.text.trim();
    if (texto.isEmpty) return;
    setState(() => _enviandoMensaje = true);
    try {
      await FirebaseFirestore.instance.collection('intercambios').doc(id).collection('mensajes').add({'uid': FirebaseAuth.instance.currentUser?.uid ?? '', 'nombre': nombre, 'texto': texto, 'timestamp': FieldValue.serverTimestamp()});
      _chatCtrl.clear();
    } finally { if (mounted) setState(() => _enviandoMensaje = false); }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('intercambios').doc(widget.intercambioId).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator(color: kUserPrimary)));
        if (!snap.hasData || !snap.data!.exists) return const Scaffold(body: Center(child: Text('No encontrado')));
        final data = snap.data!.data() as Map<String, dynamic>;
        final estado = data['estado'] as String? ?? '';
        final esSol  = data['solicitanteUid'] == currentUid;
        final esDon  = data['esDonacion'] as bool? ?? false;
        final miNombre   = esSol ? (data['solicitanteNombre'] ?? '') : (data['receptorNombre'] ?? '');
        final otroNombre = esSol ? (data['receptorNombre']    ?? '') : (data['solicitanteNombre'] ?? '');
        final miMarcador   = esSol ? (data['marcadorNombreSolicitante'] ?? '') : (data['marcadorNombreReceptor'] ?? '');
        final otroMarcador = esSol ? (data['marcadorNombreReceptor']    ?? '') : (data['marcadorNombreSolicitante'] ?? '');
        final misMats  = esSol ? (data['materialesSolicitante'] ?? '') : (data['materialesReceptor'] ?? '');
        final otrosMats = esSol ? (data['materialesReceptor'] ?? '') : (data['materialesSolicitante'] ?? '');
        final yoAcepte  = esSol ? (data['aceptadoSolicitante'] as bool? ?? false) : (data['aceptadoReceptor'] as bool? ?? false);
        final otroAcepto = esSol ? (data['aceptadoReceptor']  as bool? ?? false) : (data['aceptadoSolicitante'] as bool? ?? false);
        final chatActivo = estado == 'pendiente' || estado == 'aceptado';

        Color estadoColor; String estadoLabel;
        switch (estado) {
          case 'pendiente':  estadoColor = const Color(0xFFF57F17); estadoLabel = '⏳ Pendiente'; break;
          case 'aceptado':   estadoColor = const Color(0xFF1565C0); estadoLabel = '🤝 En curso';  break;
          case 'completado': estadoColor = const Color(0xFF2E7D32); estadoLabel = '✅ Completado'; break;
          case 'rechazado':  estadoColor = Colors.red;              estadoLabel = '❌ Rechazado';  break;
          default:           estadoColor = Colors.grey;             estadoLabel = '🚫 Cancelado';
        }

        return Scaffold(
          backgroundColor: kUserSurface,
          appBar: AppBar(
            title: Text(esDon ? 'Detalle de Donación' : 'Detalle del Intercambio'),
            backgroundColor: kUserPrimary, foregroundColor: Colors.white, elevation: 0,
            actions: chatActivo ? [
              IconButton(
                icon: Icon(_chatVisible ? Icons.info_outline : Icons.chat_bubble_outline),
                tooltip: _chatVisible ? 'Ver detalles' : 'Ver chat',
                onPressed: () => setState(() => _chatVisible = !_chatVisible),
              ),
            ] : [],
          ),
          body: Column(children: [
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), color: estadoColor.withOpacity(0.12),
              child: Center(child: Text(estadoLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: estadoColor)))),
            Expanded(child: LayoutBuilder(builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 600;
              Widget chatWidget = _ChatPanel(intercambioId: widget.intercambioId, chatCtrl: _chatCtrl, enviandoMensaje: _enviandoMensaje, miNombre: miNombre, onSend: () => _enviarMensaje(widget.intercambioId, miNombre));
              Widget mainContent = SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (esDon) Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
                  child: Row(children: [Icon(Icons.volunteer_activism, color: Colors.orange.shade700, size: 16), const SizedBox(width: 8), Expanded(child: Text('Modo donación: coordina los detalles en el chat.', style: TextStyle(fontSize: 11, color: Colors.orange.shade800, height: 1.4)))])),
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
                  child: Row(children: [
                    Expanded(child: _PartidaCard(nombre: miNombre,   marcador: esDon && esSol ? 'Donación' : miMarcador,   materiales: misMats,  color: kUserPrimary,             label: 'Tú')),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Column(children: [Icon(esDon ? Icons.arrow_forward : Icons.swap_horiz, color: kUserPrimaryLight, size: 26), Text('intercambio', style: TextStyle(fontSize: 8, color: Colors.grey.shade400))])),
                    Expanded(child: _PartidaCard(nombre: otroNombre, marcador: otroMarcador, materiales: otrosMats, color: const Color(0xFF1565C0), label: 'Contraparte')),
                  ])),
                const SizedBox(height: 14),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)]),
                  child: Column(children: [
                    const Text('Estado de aceptación', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kUserPrimary)),
                    const SizedBox(height: 8),
                    Row(children: [Expanded(child: _AceptacionChip(nombre: 'Tú', aceptado: yoAcepte)), const SizedBox(width: 8), Expanded(child: _AceptacionChip(nombre: otroNombre, aceptado: otroAcepto))]),
                  ])),
                const SizedBox(height: 14),
                _AccionesIntercambio(estado: estado, yoAcepte: yoAcepte, procesando: _procesando,
                  onAceptar: () => _aceptarIntercambio(data), onRechazar: () => _rechazarIntercambio(data), onCancelar: () => _cancelarIntercambio(data)),
                if (chatActivo && !isWide) ...[
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, height: 44, child: OutlinedButton.icon(
                    icon: Icon(_chatVisible ? Icons.info_outline : Icons.chat_bubble_outline, size: 16),
                    label: Text(_chatVisible ? 'Ver detalles' : 'Abrir chat', style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(foregroundColor: kUserPrimary, side: const BorderSide(color: kUserPrimary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => setState(() => _chatVisible = !_chatVisible),
                  )),
                ],
                const SizedBox(height: 8),
              ]));

              if (isWide) {
                return Row(children: [
                  Expanded(flex: 6, child: mainContent),
                  if (chatActivo) Container(width: 220, color: Colors.white, child: chatWidget),
                ]);
              } else {
                if (_chatVisible && chatActivo) return Container(color: Colors.white, child: chatWidget);
                return mainContent;
              }
            })),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — PANEL DE CHAT
// ─────────────────────────────────────────────────────────────────────────────

class _ChatPanel extends StatelessWidget {
  final String intercambioId, miNombre;
  final TextEditingController chatCtrl;
  final bool enviandoMensaje;
  final VoidCallback onSend;
  const _ChatPanel({required this.intercambioId, required this.miNombre, required this.chatCtrl, required this.enviandoMensaje, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Column(children: [
      Container(padding: const EdgeInsets.all(10), color: kUserSurface, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.chat_bubble_outline, size: 16, color: kUserPrimary), const SizedBox(width: 6), const Text('Chat del intercambio', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kUserPrimary))])),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('intercambios').doc(intercambioId).collection('mensajes').orderBy('timestamp').snapshots(),
        builder: (ctx, msgSnap) {
          final msgs = msgSnap.data?.docs ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: msgs.length,
            itemBuilder: (ctx, i) {
              final m = msgs[i].data() as Map<String, dynamic>;
              final esMio = m['uid'] == currentUid;
              return Align(
                alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.7),
                  decoration: BoxDecoration(color: esMio ? kUserPrimary : Colors.grey.shade100, borderRadius: BorderRadius.only(topLeft: const Radius.circular(14), topRight: const Radius.circular(14), bottomLeft: Radius.circular(esMio ? 14 : 4), bottomRight: Radius.circular(esMio ? 4 : 14))),
                  child: Column(crossAxisAlignment: esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                    if (!esMio) Text(m['nombre'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kUserPrimaryLight)),
                    Text(m['texto'] ?? '', style: TextStyle(fontSize: 13, color: esMio ? Colors.white : Colors.black87)),
                  ]),
                ),
              );
            },
          );
        },
      )),
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
        child: Row(children: [
          Expanded(child: TextField(controller: chatCtrl, style: const TextStyle(fontSize: 13), maxLines: 3, minLines: 1,
            decoration: InputDecoration(hintText: 'Escribe un mensaje…', hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400), filled: true, fillColor: const Color(0xFFF7F7F7), contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: kUserPrimary, width: 1.5))))),
          const SizedBox(width: 8),
          GestureDetector(onTap: enviandoMensaje ? null : onSend,
            child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: kUserPrimary, shape: BoxShape.circle),
              child: enviandoMensaje ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, color: Colors.white, size: 18))),
        ])),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — ACCIONES DEL INTERCAMBIO
// ─────────────────────────────────────────────────────────────────────────────

class _AccionesIntercambio extends StatelessWidget {
  final String estado; final bool yoAcepte, procesando;
  final VoidCallback onAceptar, onRechazar, onCancelar;
  const _AccionesIntercambio({required this.estado, required this.yoAcepte, required this.procesando, required this.onAceptar, required this.onRechazar, required this.onCancelar});

  @override
  Widget build(BuildContext context) {
    if (estado == 'pendiente' && !yoAcepte) {
      return Row(children: [
        Expanded(child: ElevatedButton.icon(icon: procesando ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check, size: 16), label: const Text('Aceptar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), style: ElevatedButton.styleFrom(backgroundColor: kUserPrimary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: procesando ? null : onAceptar)),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.close, size: 16), label: const Text('Rechazar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: procesando ? null : onRechazar)),
      ]);
    }
    if (estado == 'pendiente' && yoAcepte) {
      return Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)), child: const Row(children: [Icon(Icons.hourglass_top, color: Color(0xFF1565C0), size: 16), SizedBox(width: 8), Text('Esperando que la otra parte acepte...', style: TextStyle(fontSize: 12, color: Color(0xFF1565C0)))]));
    }
    if (estado == 'aceptado') {
      return Column(children: [
        SizedBox(width: double.infinity, height: 44, child: ElevatedButton.icon(icon: procesando ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.workspace_premium, size: 16), label: const Text('Marcar como completado', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), style: ElevatedButton.styleFrom(backgroundColor: kUserPrimary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: procesando ? null : onAceptar)),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, height: 40, child: OutlinedButton.icon(icon: const Icon(Icons.cancel_outlined, size: 16), label: const Text('Cancelar intercambio', style: TextStyle(fontSize: 12)), style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade600, side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: procesando ? null : onCancelar)),
      ]);
    }
    if (estado == 'completado') {
      return Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF43A047)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(12)),
        child: const Column(children: [Text('🎉', style: TextStyle(fontSize: 28)), SizedBox(height: 6), Text('¡Completado!', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)), SizedBox(height: 4), Text('Tu reputación ha sido actualizada.', style: TextStyle(color: Colors.white70, fontSize: 11))]));
    }
    return const SizedBox.shrink();
  }
}

class _PartidaCard extends StatelessWidget {
  final String nombre, marcador, materiales, label; final Color color;
  const _PartidaCard({required this.nombre, required this.marcador, required this.materiales, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,    style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(nombre,   style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(marcador, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Row(children: [Icon(Icons.recycling, size: 10, color: color), const SizedBox(width: 2), Expanded(child: Text(materiales, style: TextStyle(fontSize: 9, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis))]),
      ]));
  }
}

class _AceptacionChip extends StatelessWidget {
  final String nombre; final bool aceptado;
  const _AceptacionChip({required this.nombre, required this.aceptado});

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: aceptado ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8), border: Border.all(color: aceptado ? kUserAccent : Colors.orange.shade200)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(aceptado ? Icons.check_circle : Icons.hourglass_top, size: 14, color: aceptado ? kUserPrimary : Colors.orange), const SizedBox(width: 4), Expanded(child: Text(nombre, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: aceptado ? kUserPrimary : Colors.orange.shade800), overflow: TextOverflow.ellipsis))]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB — MÁS
// ─────────────────────────────────────────────────────────────────────────────

class _MasTab extends StatefulWidget {
  const _MasTab();
  @override
  State<_MasTab> createState() => _MasTabState();
}

class _MasTabState extends State<_MasTab> {
  int _subIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kUserSurface,
      body: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Container(decoration: BoxDecoration(color: kUserSurface, borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.all(4),
            child: Row(children: [
              _SubTabBtn(label: 'Impacto', icon: Icons.eco_outlined,        active: _subIndex == 0, onTap: () => setState(() => _subIndex = 0)),
              _SubTabBtn(label: 'Soporte', icon: Icons.headset_mic_outlined, active: _subIndex == 1, onTap: () => setState(() => _subIndex = 1)),
            ]))),
        Expanded(child: IndexedStack(index: _subIndex, children: const [_ImpactoSection(), _SoporteSection()])),
      ]),
    );
  }
}

class _SubTabBtn extends StatelessWidget {
  final String label; final IconData icon; final bool active; final VoidCallback onTap;
  const _SubTabBtn({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 220), padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: active ? kUserPrimary : Colors.transparent, borderRadius: BorderRadius.circular(10), boxShadow: active ? [BoxShadow(color: kUserPrimary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : []),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: active ? Colors.white : Colors.grey.shade600), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : Colors.grey.shade600))]))));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECCIÓN — ESTADÍSTICAS DE IMPACTO (igual que antes, sin cambios)
// ─────────────────────────────────────────────────────────────────────────────

class _StatData {
  final String valor, etiqueta, fuente, anio; final IconData icon; final Color color;
  const _StatData({required this.valor, required this.etiqueta, required this.fuente, required this.anio, required this.icon, required this.color});
}

const List<_StatData> _statsAgs = [
  _StatData(valor: '14.6 t',  etiqueta: 'Materiales reciclables recibidos al día en centros de acopio',        fuente: 'INEGI — Censo Nacional de Gobiernos Municipales 2023', anio: '2022', icon: Icons.recycling,              color: Color(0xFF2E7D32)),
  _StatData(valor: '46.3 %',  etiqueta: 'Del total nacional de materiales reciclados en centros de acopio',    fuente: 'INEGI — Censo Nacional de Gobiernos Municipales 2023', anio: '2022', icon: Icons.emoji_events_outlined,  color: Color(0xFFF57F17)),
  _StatData(valor: '99.1 %',  etiqueta: 'De la población con acceso al servicio de recolección de residuos',   fuente: 'SEMARNAT — Informe del Medio Ambiente en México',       anio: '2022', icon: Icons.local_shipping_outlined, color: Color(0xFF1565C0)),
  _StatData(valor: '11',      etiqueta: 'Centros de acopio municipales operados por Servicios Públicos',        fuente: 'H. Ayuntamiento de Aguascalientes',                     anio: '2024', icon: Icons.location_on_outlined,   color: Color(0xFF00838F)),
  _StatData(valor: '104 t',   etiqueta: 'De papel, cartón, PET, aluminio y otros materiales recibidos en el año', fuente: 'H. Ayuntamiento de Aguascalientes — Programa Punto Limpio', anio: '2024', icon: Icons.scale_outlined, color: Color(0xFF6A1B9A)),
  _StatData(valor: '948,990', etiqueta: 'Habitantes beneficiados por el programa de limpia del municipio',      fuente: 'CONEVAL / municipio 2023',                             anio: '2023', icon: Icons.people_outline,         color: Color(0xFFAD1457)),
];

class _ImpactoSection extends StatelessWidget {
  const _ImpactoSection();

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      _ImpactoHeader(),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: kUserSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kUserAccent.withOpacity(0.5))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.verified_outlined, color: kUserPrimaryLight, size: 18), const SizedBox(width: 10), Expanded(child: Text('Las siguientes cifras provienen de fuentes gubernamentales oficiales de Aguascalientes.', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.5)))])),
      const SizedBox(height: 22),
      const _SectionLabel(text: 'Aguascalientes en cifras'), const SizedBox(height: 12),
      ..._statsAgs.map((s) => _StatCard(data: s)),
      const SizedBox(height: 24),
      const _SectionLabel(text: 'Posición nacional'), const SizedBox(height: 12),
      _NationalRankCard(),
      const SizedBox(height: 24),
      const _SectionLabel(text: 'Materiales más reciclados'), const SizedBox(height: 12),
      _MaterialesGrid(),
      const SizedBox(height: 24),
      _FuentesCard(),
    ]);
  }
}

class _ImpactoHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF43A047)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: kUserPrimary.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.emoji_events, color: Colors.amber, size: 14), SizedBox(width: 5), Text('Líder nacional en reciclaje', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))])),
        const SizedBox(height: 16),
        Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('Aguascalientes', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.1)), SizedBox(height: 4), Text('Impacto ambiental real', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500))])), Container(width: 72, height: 72, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.eco, color: Colors.white, size: 38))]),
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.2), width: 1)),
          child: Row(children: const [Icon(Icons.star_rounded, color: Colors.amber, size: 20), SizedBox(width: 8), Expanded(child: Text('46.3 % del total nacional de materiales reciclados en centros de acopio provienen de Aguascalientes.', style: TextStyle(color: Colors.white, fontSize: 12, height: 1.4, fontWeight: FontWeight.w500)))])),
      ]));
  }
}

class _StatCard extends StatelessWidget {
  final _StatData data; const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(children: [
        Container(height: 4, decoration: BoxDecoration(color: data.color, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: data.color.withOpacity(0.10), borderRadius: BorderRadius.circular(12)), child: Icon(data.icon, color: data.color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data.valor, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: data.color, height: 1)),
            const SizedBox(height: 4),
            Text(data.etiqueta, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(6)),
              child: Row(children: [Icon(Icons.link, size: 10, color: Colors.grey.shade500), const SizedBox(width: 4), Expanded(child: Text('${data.fuente} · ${data.anio}', style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis))])),
          ])),
        ])),
      ]));
  }
}

class _NationalRankCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [_RankItem('Centros de acopio activos', '# 1 nacional', const Color(0xFF2E7D32)), _RankItem('Cobertura de recolección', '99.1 % pob.', const Color(0xFF1565C0)), _RankItem('Reciclaje diario en acopio', '14.6 t / día', const Color(0xFF00838F)), _RankItem('% del total nacional reciclado', '46.3 %', const Color(0xFFF57F17))];
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.bar_chart_rounded, color: kUserPrimary, size: 18), const SizedBox(width: 6), const Text('Indicadores clave — Aguascalientes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kUserPrimary))]),
        const SizedBox(height: 12),
        ...items.map((item) => _RankRow(item: item)),
        const SizedBox(height: 8),
        Text('Fuente: INEGI, Censo Nacional de Gobiernos Municipales 2023.', style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
      ]));
  }
}

class _RankItem { final String label, valor; final Color color; const _RankItem(this.label, this.valor, this.color); }
class _RankRow extends StatelessWidget {
  final _RankItem item; const _RankRow({required this.item});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)), const SizedBox(width: 10), Expanded(child: Text(item.label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: item.color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(item.valor, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: item.color)))]));
  }
}

class _MaterialesGrid extends StatelessWidget {
  static const List<_MaterialItem> _materiales = [
    _MaterialItem('Papel y cartón', Icons.article_outlined,    Color(0xFF795548), '79.9 % del total'),
    _MaterialItem('PET',            Icons.water_drop_outlined, Color(0xFF1565C0), 'Plástico tipo 1'),
    _MaterialItem('Vidrio',         Icons.wine_bar_outlined,   Color(0xFF00838F), 'Reutilizable 100 %'),
    _MaterialItem('Aluminio',       Icons.layers_outlined,     Color(0xFF546E7A), 'Alta valorización'),
  ];
  @override
  Widget build(BuildContext context) {
    return GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2, children: _materiales.map((m) => _MaterialChip(item: m)).toList());
  }
}

class _MaterialItem { final String nombre, nota; final IconData icon; final Color color; const _MaterialItem(this.nombre, this.icon, this.color, this.nota); }
class _MaterialChip extends StatelessWidget {
  final _MaterialItem item; const _MaterialChip({required this.item});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: item.color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: item.color.withOpacity(0.25))),
      child: Row(children: [Icon(item.icon, color: item.color, size: 22), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(item.nombre, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: item.color)), Text(item.nota, style: TextStyle(fontSize: 9, color: Colors.grey.shade500))]))]));
  }
}

class _FuentesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kUserAccent.withOpacity(0.4), width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.info_outline, size: 16, color: kUserPrimaryLight), const SizedBox(width: 8), const Text('Fuentes de información', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kUserPrimary))]),
        const SizedBox(height: 10),
        _FuenteRow(numero: '1', texto: 'INEGI. Censo Nacional de Gobiernos Municipales 2023. Módulo: Residuos Sólidos Urbanos.', color: const Color(0xFF2E7D32)),
        _FuenteRow(numero: '2', texto: 'SEMARNAT. Informe de la Situación del Medio Ambiente en México. Capítulo 7: Residuos (2022).', color: const Color(0xFF1565C0)),
        _FuenteRow(numero: '3', texto: 'H. Ayuntamiento de Aguascalientes. Programa Punto Limpio Sur y centros de acopio municipales (2024).', color: const Color(0xFF00838F)),
        _FuenteRow(numero: '4', texto: 'CONEVAL / Municipio. Evaluación de Diseño del Programa Servicios Públicos — Limpia y Aseo 2024.', color: const Color(0xFFF57F17)),
      ]));
  }
}

class _FuenteRow extends StatelessWidget {
  final String numero, texto; final Color color;
  const _FuenteRow({required this.numero, required this.texto, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 18, height: 18, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Center(child: Text(numero, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))), const SizedBox(width: 8), Expanded(child: Text(texto, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, height: 1.5)))]));
  }
}

class _SectionLabel extends StatelessWidget {
  final String text; const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(children: [Container(width: 4, height: 16, decoration: BoxDecoration(color: kUserPrimary, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))))]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECCIÓN — SOPORTE
// ─────────────────────────────────────────────────────────────────────────────

class _SoporteSection extends StatefulWidget {
  const _SoporteSection();
  @override
  State<_SoporteSection> createState() => _SoporteSectionState();
}

class _SoporteSectionState extends State<_SoporteSection> {
  final _asuntoCtrl  = TextEditingController();
  final _mensajeCtrl = TextEditingController();
  String _categoria  = 'Duda general';
  bool _enviando = false, _enviado = false;
  static const String _correoSoporte = 'ecoflow084@gmail.com';
  static const List<String> _categorias = ['Duda general', 'Problema técnico', 'Sugerencia', 'Reporte de marcador', 'Otro'];

  @override
  void dispose() { _asuntoCtrl.dispose(); _mensajeCtrl.dispose(); super.dispose(); }

  Future<void> _enviarMensaje() async {
    if (_asuntoCtrl.text.trim().isEmpty || _mensajeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor completa todos los campos'), backgroundColor: Colors.orange)); return;
    }
    setState(() => _enviando = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      Map<String, dynamic>? userData;
      if (user != null) { final snap = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get(); userData = snap.data(); }
      await FirebaseFirestore.instance.collection('soporte').add({'uid': user?.uid ?? '', 'nombreUsuario': userData?['nombre'] ?? '', 'emailUsuario': userData?['email'] ?? user?.email ?? '', 'telefonoUsuario': userData?['telefono'] ?? '', 'categoria': _categoria, 'asunto': _asuntoCtrl.text.trim(), 'mensaje': _mensajeCtrl.text.trim(), 'destinatario': _correoSoporte, 'creadoEn': FieldValue.serverTimestamp(), 'estado': 'pendiente'});
      setState(() => _enviado = true); _asuntoCtrl.clear(); _mensajeCtrl.clear();
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar: $e'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => _enviando = false); }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF43A047)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
        child: Row(children: [Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.headset_mic, color: Colors.white, size: 28)), const SizedBox(width: 16), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Centro de soporte', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)), SizedBox(height: 4), Text('Estamos aquí para ayudarte', style: TextStyle(color: Colors.white70, fontSize: 12))]))])),
      const SizedBox(height: 20),
      const _SectionLabel(text: 'Canales de contacto'), const SizedBox(height: 12),
      _CanalCard(icon: Icons.email_outlined,        titulo: 'Email directo',      subtitulo: _correoSoporte,              color: const Color(0xFF1565C0)),
      const SizedBox(height: 10),
      const _CanalCard(icon: Icons.chat_bubble_outline, titulo: 'Formulario en app', subtitulo: 'Respuesta en 24–48 h hábiles', color: Color(0xFF2E7D32)),
      const SizedBox(height: 24),
      const _SectionLabel(text: 'Enviar un mensaje'), const SizedBox(height: 12),
      if (_enviado) _SuccessBanner(correo: _correoSoporte, onReset: () => setState(() => _enviado = false))
      else ...[
        Container(padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _categoria, isExpanded: true, icon: const Icon(Icons.expand_more, color: kUserPrimary), style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)), items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _categoria = v!)))),
        const SizedBox(height: 12),
        _MinimalField(controller: _asuntoCtrl, label: 'Asunto', icon: Icons.subject_outlined),
        const SizedBox(height: 12),
        TextField(controller: _mensajeCtrl, maxLines: 5, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
          decoration: InputDecoration(labelText: 'Mensaje', labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400), prefixIcon: Padding(padding: const EdgeInsets.only(bottom: 64), child: Icon(Icons.message_outlined, size: 20, color: Colors.grey.shade400)), filled: true, fillColor: const Color(0xFFF7F7F7), contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kUserPrimary, width: 1.5)))),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
          onPressed: _enviando ? null : _enviarMensaje,
          icon: _enviando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_outlined, size: 18),
          label: Text(_enviando ? 'Enviando…' : 'Enviar mensaje', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(backgroundColor: kUserPrimary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        )),
      ],
      const SizedBox(height: 24),
      const _SectionLabel(text: 'Preguntas frecuentes'), const SizedBox(height: 12),
      const _FaqItem(pregunta: '¿Cómo agrego un marcador?',                    respuesta: 'Ve a la pestaña Mapa y toca cualquier punto en él.'),
      const _FaqItem(pregunta: '¿Cómo propongo un intercambio o donación?',    respuesta: 'Toca cualquier marcador en el Mapa o en la lista. Aparecerá el botón "Proponer Intercambio / Donación".'),
      const _FaqItem(pregunta: '¿Qué es el modo donación?',                    respuesta: 'Permite solicitar materiales sin necesidad de ofrecer un marcador. Coordina los detalles en el chat.'),
      const _FaqItem(pregunta: '¿Por qué no puedo enviar otra solicitud?',     respuesta: 'Para evitar spam, solo puedes tener una solicitud activa o pendiente por usuario.'),
      const _FaqItem(pregunta: '¿Qué es el sistema de reputación?',            respuesta: 'Cada intercambio completado aumenta tu contador. Visible en tarjetas y en tu perfil.'),
      const _FaqItem(pregunta: '¿Cómo veo mis notificaciones?',                respuesta: 'Toca el ícono de campana 🔔 en la barra superior.'),
    ]);
  }
}

class _CanalCard extends StatelessWidget {
  final IconData icon; final String titulo, subtitulo; final Color color;
  const _CanalCard({required this.icon, required this.titulo, required this.subtitulo, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 20, color: color)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(subtitulo, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))])), Icon(Icons.chevron_right, color: color.withOpacity(0.5), size: 20)]));
  }
}

class _SuccessBanner extends StatelessWidget {
  final VoidCallback onReset; final String correo;
  const _SuccessBanner({required this.onReset, required this.correo});

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(16), border: Border.all(color: kUserAccent, width: 1)),
      child: Column(children: [const Icon(Icons.check_circle, color: kUserPrimary, size: 48), const SizedBox(height: 12), const Text('¡Mensaje enviado!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kUserPrimary)), const SizedBox(height: 6), Text('Tu mensaje fue registrado y será atendido en $correo.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), const SizedBox(height: 16), TextButton(onPressed: onReset, child: const Text('Enviar otro mensaje', style: TextStyle(color: kUserPrimary)))]));
  }
}

class _FaqItem extends StatefulWidget {
  final String pregunta, respuesta;
  const _FaqItem({required this.pregunta, required this.respuesta});
  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Material(color: Colors.transparent, child: InkWell(onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 12, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(widget.pregunta, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1B5E20)))), AnimatedRotation(turns: _expanded ? 0.5 : 0, duration: const Duration(milliseconds: 200), child: const Icon(Icons.expand_more, color: kUserPrimary))]),
          AnimatedCrossFade(duration: const Duration(milliseconds: 220), firstChild: const SizedBox.shrink(), secondChild: Padding(padding: const EdgeInsets.only(top: 10), child: Text(widget.respuesta, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.5))), crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst),
        ]))))));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCAFFOLD — PANEL DE ADMINISTRADOR
// ─────────────────────────────────────────────────────────────────────────────

class _AdminScaffold extends StatelessWidget {
  final User user;
  const _AdminScaffold({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ Panel Admin'), backgroundColor: const Color.fromARGB(255, 61, 255, 78), foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())]),
      drawer: Drawer(child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?; final email = data?['email'] ?? user.email ?? '';
          return ListView(padding: EdgeInsets.zero, children: [
            UserAccountsDrawerHeader(decoration: const BoxDecoration(color: Color.fromARGB(255, 140, 192, 80)), accountName: const Text('Administrador'), accountEmail: Text(email), currentAccountPicture: const CircleAvatar(child: Icon(Icons.admin_panel_settings, size: 35))),
            _tile(Icons.person_add, 'Crear usuario',      () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => CrearUsuarioPage())); }),
            _tile(Icons.people,     'Ver usuarios',       () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => VerUsuariosPage())); }),
            _tile(Icons.edit,       'Actualizar usuario', () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ActualizarUsuarioPage())); }),
            _tile(Icons.delete,     'Borrar usuario',     () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => BorrarUsuarioPage())); }),
            const Divider(),
            _tile(Icons.logout, 'Cerrar sesión', () => FirebaseAuth.instance.signOut(), color: Colors.red),
          ]);
        },
      )),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
        builder: (context, snap) { final data = snap.data?.data() as Map<String, dynamic>?; final email = data?['email'] ?? user.email ?? ''; return Center(child: Text('Sesión iniciada como:\n$email\nRol: Admin', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16))); },
      ),
    );
  }
  ListTile _tile(IconData icon, String label, VoidCallback onTap, {Color color = Colors.green}) =>
      ListTile(leading: Icon(icon, color: color), title: Text(label, style: TextStyle(color: color == Colors.red ? Colors.red : null)), onTap: onTap);
}

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA — VER DATOS DEL USUARIO
// ─────────────────────────────────────────────────────────────────────────────

class VerDatosPage extends StatelessWidget {
  final String uid;
  const VerDatosPage({required this.uid, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis datos'), backgroundColor: kUserPrimary, foregroundColor: Colors.white),
      backgroundColor: kUserSurface,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          if (data == null) return const Center(child: Text('No se encontraron datos'));
          final intercambios = (data['intercambiosCompletados'] ?? 0) as int;
          final fotoPerfil   = data['fotoPerfil'] as String? ?? '';
          return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
            Center(child: _UserAvatar(radius: 48, fotoBase64: fotoPerfil)),
            const SizedBox(height: 16),
            Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 3, child: Column(mainAxisSize: MainAxisSize.min, children: [
              _infoTile(Icons.person,  'Nombre completo', data['nombre']),
              _infoTile(Icons.phone,   'Teléfono',        data['telefono']),
              _infoTile(Icons.email,   'Correo',          data['email']),
              _infoTile(Icons.shield,  'Rol',             data['rol'] ?? 'usuario'),
              _infoTile(Icons.key,     'UID',             data['uid']),
            ])),
            const SizedBox(height: 20),
            _LogrosProgressBar(intercambios: intercambios),
            const SizedBox(height: 20),
            Container(width: double.infinity, padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF43A047)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: kUserPrimary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
              child: Column(children: [
                const Icon(Icons.workspace_premium, color: Colors.amber, size: 40),
                const SizedBox(height: 8),
                const Text('Mi Reputación EcoFlow', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _ReputacionBadge(intercambios: intercambios),
                const SizedBox(height: 12),
                Text(intercambios == 0 ? 'Completa tu primer intercambio para ganar reputación' : '¡Excelente! Has completado $intercambios intercambio${intercambios != 1 ? 's' : ''}.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
              ]),
            ),
          ]));
        },
      ),
    );
  }
  ListTile _infoTile(IconData icon, String title, String? subtitle) => ListTile(leading: Icon(icon, color: kUserPrimaryLight), title: Text(title), subtitle: Text(subtitle ?? ''));
}

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINA — CAMBIAR DATOS DEL USUARIO (con foto de perfil)
// ─────────────────────────────────────────────────────────────────────────────

class CambiarDatosPage extends StatefulWidget {
  final String uid;
  const CambiarDatosPage({required this.uid, super.key});
  @override
  State<CambiarDatosPage> createState() => _CambiarDatosPageState();
}

class _CambiarDatosPageState extends State<CambiarDatosPage> {
  final nombreController     = TextEditingController();
  final telefonoController   = TextEditingController();
  final emailController      = TextEditingController();
  final passActualController = TextEditingController();
  final passNuevaController  = TextEditingController();
  bool cargando    = false;
  bool _cargandoFoto = false;

  // ── NUEVO: foto de perfil ──
  String? _fotoBase64Actual; // base64 guardado en Firestore
  String? _fotoBase64Nueva;  // base64 recién seleccionado (preview)

  final _picker = ImagePicker();

  @override
  void initState() { super.initState(); _cargarDatos(); }

  Future _cargarDatos() async {
    final doc  = await FirebaseFirestore.instance.collection('usuarios').doc(widget.uid).get();
    final data = doc.data() as Map<String, dynamic>?;
    if (data != null) {
      nombreController.text   = data['nombre']     ?? '';
      telefonoController.text = data['telefono']   ?? '';
      emailController.text    = data['email']      ?? '';
      setState(() => _fotoBase64Actual = data['fotoPerfil'] as String? ?? '');
    }
  }

  // ── Seleccionar foto desde galería o cámara ──
  Future<void> _seleccionarFoto(ImageSource fuente) async {
    Navigator.pop(context); // cierra el bottom sheet de opciones
    setState(() => _cargandoFoto = true);
    try {
      final XFile? imagen = await _picker.pickImage(
        source: fuente,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );
      if (imagen == null) { setState(() => _cargandoFoto = false); return; }
      final bytes  = await imagen.readAsBytes();
      final b64    = base64Encode(bytes);
      setState(() { _fotoBase64Nueva = b64; _cargandoFoto = false; });
    } catch (e) {
      setState(() => _cargandoFoto = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al acceder: $e'), backgroundColor: Colors.red));
    }
  }

  // ── Mostrar opciones: cámara o galería ──
  void _mostrarOpcionesFoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: kUserSurface, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.photo_camera_outlined, color: kUserPrimary, size: 20)),
            const SizedBox(width: 10),
            const Text('Cambiar foto de perfil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text('Elige cómo quieres seleccionar tu foto.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 20),
          // Botón: Tomar foto
          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt_outlined, size: 20),
              label: const Text('Tomar una foto', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(backgroundColor: kUserPrimary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => _seleccionarFoto(ImageSource.camera),
            )),
          const SizedBox(height: 10),
          // Botón: Elegir de galería
          SizedBox(width: double.infinity, height: 50,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              label: const Text('Elegir de la galería', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(foregroundColor: kUserPrimary, side: const BorderSide(color: kUserPrimary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => _seleccionarFoto(ImageSource.gallery),
            )),
          const SizedBox(height: 10),
          // Botón: Eliminar foto (solo si hay una)
          if ((_fotoBase64Nueva ?? _fotoBase64Actual ?? '').isNotEmpty)
            SizedBox(width: double.infinity, height: 44,
              child: TextButton.icon(
                icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                label: Text('Eliminar foto de perfil', style: TextStyle(fontSize: 13, color: Colors.red.shade400)),
                onPressed: () { Navigator.pop(context); setState(() { _fotoBase64Nueva = ''; }); },
              )),
        ]),
      ),
    );
  }

  Future guardarCambios() async {
    setState(() => cargando = true);
    try {
      final user        = FirebaseAuth.instance.currentUser!;
      final nuevoEmail  = emailController.text.trim();
      final passActual  = passActualController.text.trim();
      final passNueva   = passNuevaController.text.trim();
      final emailCambia = nuevoEmail.isNotEmpty && nuevoEmail != user.email;
      final passCambia  = passNueva.isNotEmpty;
      final Map<String, dynamic> updates = {};

      if (emailCambia || passCambia) {
        if (passActual.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa tu contraseña actual.'), backgroundColor: Colors.orange));
          setState(() => cargando = false); return;
        }
        final cred = EmailAuthProvider.credential(email: user.email!, password: passActual);
        await user.reauthenticateWithCredential(cred);
        if (emailCambia) { await user.updateEmail(nuevoEmail); updates['email'] = nuevoEmail; }
        if (passCambia) await user.updatePassword(passNueva);
        passActualController.clear(); passNuevaController.clear();
      }

      if (nombreController.text.trim().isNotEmpty)   updates['nombre']   = nombreController.text.trim();
      if (telefonoController.text.trim().isNotEmpty) updates['telefono'] = telefonoController.text.trim();

      // ── Guardar foto en Firestore (campo fotoPerfil como String base64) ──
      // Compatible con Firestore: el campo es un String estándar (texto base64).
      if (_fotoBase64Nueva != null) {
        updates['fotoPerfil'] = _fotoBase64Nueva!;
      }

      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance.collection('usuarios').doc(widget.uid).update(updates);
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Datos actualizados'), backgroundColor: Colors.green));
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential': msg = 'Contraseña actual incorrecta.'; break;
        case 'email-already-in-use': msg = 'Ese correo ya está en uso.'; break;
        case 'invalid-email': msg = 'Formato de correo inválido.'; break;
        default: msg = e.message ?? 'Error de autenticación.';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  // Widget que muestra el avatar con botón de edición encima
  Widget _buildAvatarEditor() {
    final fotoActiva = _fotoBase64Nueva ?? _fotoBase64Actual ?? '';
    return Center(
      child: Stack(
        children: [
          // Avatar
          _cargandoFoto
              ? Container(
                  width: 104, height: 104,
                  decoration: BoxDecoration(color: kUserSurface, shape: BoxShape.circle),
                  child: const Center(child: CircularProgressIndicator(color: kUserPrimary, strokeWidth: 2)),
                )
              : _UserAvatar(radius: 52, fotoBase64: fotoActiva),
          // Botón de edición
          Positioned(
            bottom: 0, right: 0,
            child: GestureDetector(
              onTap: _mostrarOpcionesFoto,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: kUserPrimary, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [BoxShadow(color: kUserPrimary.withOpacity(0.4), blurRadius: 6)],
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar mis datos'), backgroundColor: kUserPrimary, foregroundColor: Colors.white),
      backgroundColor: kUserSurface,
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        // Avatar con botón de edición
        _buildAvatarEditor(),
        const SizedBox(height: 8),
        // Etiqueta de ayuda
        GestureDetector(
          onTap: _mostrarOpcionesFoto,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.edit_outlined, size: 13, color: kUserPrimaryLight),
            const SizedBox(width: 4),
            Text('Toca para cambiar la foto', style: TextStyle(fontSize: 12, color: kUserPrimaryLight, fontWeight: FontWeight.w500)),
          ]),
        ),
        // Badge de "foto nueva seleccionada"
        if (_fotoBase64Nueva != null && _fotoBase64Nueva!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: kUserSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kUserAccent)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_outline, size: 13, color: kUserPrimary),
                const SizedBox(width: 4),
                Text('Nueva foto lista para guardar', style: TextStyle(fontSize: 11, color: kUserPrimary)),
              ]),
            ),
          ),
        if (_fotoBase64Nueva == '' && (_fotoBase64Actual ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.delete_outline, size: 13, color: Colors.red.shade500),
                const SizedBox(width: 4),
                Text('La foto se eliminará al guardar', style: TextStyle(fontSize: 11, color: Colors.red.shade500)),
              ]),
            ),
          ),
        const SizedBox(height: 24),
        _MinimalField(controller: nombreController,     label: 'Nombre completo',            icon: Icons.person_outline),               const SizedBox(height: 16),
        _MinimalField(controller: telefonoController,   label: 'Teléfono',                   icon: Icons.phone_outlined, type: TextInputType.phone), const SizedBox(height: 16),
        _MinimalField(controller: emailController,      label: 'Correo',                     icon: Icons.mail_outline, type: TextInputType.emailAddress), const SizedBox(height: 16),
        _MinimalField(controller: passActualController, label: 'Contraseña actual',           icon: Icons.lock_outline, obscure: true),               const SizedBox(height: 16),
        _MinimalField(controller: passNuevaController,  label: 'Nueva contraseña (opcional)', icon: Icons.lock_outline, obscure: true),               const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: cargando ? null : guardarCambios,
          style: ElevatedButton.styleFrom(backgroundColor: kUserPrimary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: cargando ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Guardar cambios', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        )),
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PÁGINAS — ADMINISTRACIÓN DE USUARIOS (crear / ver / actualizar / borrar)
// ─────────────────────────────────────────────────────────────────────────────

class CrearUsuarioPage extends StatefulWidget {
  @override
  State<CrearUsuarioPage> createState() => _CrearUsuarioPageState();
}

class _CrearUsuarioPageState extends State<CrearUsuarioPage> {
  final nCtrl = TextEditingController(); final tCtrl = TextEditingController();
  final eCtrl = TextEditingController(); final pCtrl = TextEditingController();
  bool cargando = false;

  Future crearUsuario() async {
    if (nCtrl.text.trim().isEmpty || tCtrl.text.trim().isEmpty || eCtrl.text.trim().isEmpty || pCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor completa todos los campos'), backgroundColor: Colors.orange)); return;
    }
    setState(() => cargando = true);
    try {
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: eCtrl.text.trim(), password: pCtrl.text.trim());
      await FirebaseFirestore.instance.collection('usuarios').doc(cred.user!.uid).set({
        'email': eCtrl.text.trim(), 'uid': cred.user!.uid, 'rol': 'usuario',
        'nombre': nCtrl.text.trim(), 'telefono': tCtrl.text.trim(),
        'intercambiosCompletados': 0, 'reputacion': 0.0, 'fotoPerfil': '',
      });
      nCtrl.clear(); tCtrl.clear(); eCtrl.clear(); pCtrl.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Usuario creado'), backgroundColor: Colors.green));
    } on FirebaseAuthException catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => cargando = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear usuario'), backgroundColor: const Color.fromARGB(255, 61, 255, 78), foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        _f(nCtrl, 'Nombre completo', Icons.person), const SizedBox(height: 16),
        _f(tCtrl, 'Teléfono',        Icons.phone,  type: TextInputType.phone), const SizedBox(height: 16),
        _f(eCtrl, 'Correo',          Icons.email,  type: TextInputType.emailAddress), const SizedBox(height: 16),
        _f(pCtrl, 'Contraseña',      Icons.lock,   obscure: true), const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: cargando ? null : crearUsuario, style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 61, 255, 78), foregroundColor: Colors.white), child: cargando ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Crear usuario'))),
      ])),
    );
  }
  Widget _f(TextEditingController c, String label, IconData icon, {TextInputType? type, bool obscure = false}) =>
      TextField(controller: c, keyboardType: type, obscureText: obscure, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()));
}

class VerUsuariosPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ver usuarios'), backgroundColor: const Color.fromARGB(255, 61, 255, 78), foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay usuarios registrados'));
          return ListView.builder(itemCount: snapshot.data!.docs.length, itemBuilder: (context, index) {
            final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final ic   = data['intercambiosCompletados'] ?? 0;
            final foto = data['fotoPerfil'] as String? ?? '';
            return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: ListTile(
              leading: _UserAvatar(radius: 22, bgColor: const Color(0xFFE8F5E9), iconColor: Colors.green, fotoBase64: foto),
              title: Text(data['nombre'] ?? data['email'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['email'] ?? ''), if ((data['telefono'] ?? '').isNotEmpty) Text('📞 ${data['telefono']}'), Text('Rol: ${data['rol'] ?? 'usuario'}'), _ReputacionBadge(intercambios: ic, small: true)]),
              isThreeLine: true,
            ));
          });
        },
      ),
    );
  }
}

class ActualizarUsuarioPage extends StatefulWidget {
  @override
  State<ActualizarUsuarioPage> createState() => _ActualizarUsuarioPageState();
}

class _ActualizarUsuarioPageState extends State<ActualizarUsuarioPage> {
  final buscarCtrl   = TextEditingController();
  final nombreCtrl   = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final emailCtrl    = TextEditingController();
  String? uidEncontrado; bool cargando = false;

  Future buscarUsuario() async {
    setState(() => cargando = true);
    try {
      final q = await FirebaseFirestore.instance.collection('usuarios').where('email', isEqualTo: buscarCtrl.text.trim()).get();
      if (q.docs.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario no encontrado'), backgroundColor: Colors.orange)); setState(() { uidEncontrado = null; nombreCtrl.clear(); telefonoCtrl.clear(); emailCtrl.clear(); }); }
      else { final data = q.docs.first.data() as Map<String, dynamic>; setState(() { uidEncontrado = q.docs.first.id; nombreCtrl.text = data['nombre'] ?? ''; telefonoCtrl.text = data['telefono'] ?? ''; emailCtrl.text = data['email'] ?? ''; }); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Usuario encontrado'), backgroundColor: Colors.green)); }
    } finally { if (mounted) setState(() => cargando = false); }
  }

  Future actualizarUsuario() async {
    if (uidEncontrado == null) return;
    setState(() => cargando = true);
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uidEncontrado).update({'nombre': nombreCtrl.text.trim(), 'telefono': telefonoCtrl.text.trim(), 'email': emailCtrl.text.trim()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Usuario actualizado'), backgroundColor: Colors.green));
      buscarCtrl.clear(); nombreCtrl.clear(); telefonoCtrl.clear(); emailCtrl.clear(); setState(() => uidEncontrado = null);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => cargando = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Actualizar usuario'), backgroundColor: const Color.fromARGB(255, 61, 255, 78), foregroundColor: Colors.white),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        TextField(controller: buscarCtrl, decoration: InputDecoration(labelText: 'Buscar por correo', prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder(), suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: buscarUsuario))),
        const SizedBox(height: 16),
        TextField(controller: nombreCtrl,   enabled: uidEncontrado != null, decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextField(controller: telefonoCtrl, enabled: uidEncontrado != null, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder())),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: (cargando || uidEncontrado == null) ? null : actualizarUsuario, style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 61, 255, 78), foregroundColor: Colors.white), child: cargando ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Actualizar'))),
      ])),
    );
  }
}

class BorrarUsuarioPage extends StatefulWidget {
  @override
  State<BorrarUsuarioPage> createState() => _BorrarUsuarioPageState();
}

class _BorrarUsuarioPageState extends State<BorrarUsuarioPage> {
  final emailController = TextEditingController();
  bool cargando = false;

  Future borrarUsuario() async {
    setState(() => cargando = true);
    try {
      final q = await FirebaseFirestore.instance.collection('usuarios').where('email', isEqualTo: emailController.text.trim()).get();
      if (q.docs.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario no encontrado'), backgroundColor: Colors.orange)); return; }
      await q.docs.first.reference.delete(); emailController.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Usuario eliminado'), backgroundColor: Colors.green));
    } finally { if (mounted) setState(() => cargando = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Borrar usuario'), backgroundColor: const Color.fromARGB(255, 61, 255, 78), foregroundColor: Colors.white),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo del usuario', prefixIcon: Icon(Icons.search), border: OutlineInputBorder())),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: cargando ? null : () => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('¿Confirmar?'), content: const Text('¿Seguro que deseas borrar este usuario?'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), TextButton(onPressed: () { Navigator.pop(context); borrarUsuario(); }, child: const Text('Borrar', style: TextStyle(color: Colors.red)))])),
          style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 61, 255, 78), foregroundColor: Colors.white),
          child: cargando ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Borrar usuario'),
        )),
      ])),
    );
  }
}