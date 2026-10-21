import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

// Windows XP "Luna" look shared by the NCG customer page and dialogs.
// Palette and layout follow the NCG XP Window kit (ncg_xpshell.py / ncg_xpsetup.py).

const kNcgFont = 'AtkinsonHyperlegible';
const kNcgPhone = '715-623-2468';

const _luna = Color(0xFF0A4FE0);
const _lunaDark = Color(0xFF0831D9);
const _beige = Color(0xFFECE9D8);
const _heading = Color(0xFF0A3A9A);
const _ink = Color(0xFF111111);
const _green = Color(0xFF3C9A2B);
const _red = Color(0xFFC01818);
const _cardBorder = Color(0xFF7F9DB9);

// Server the customer must be able to reach (same host and port as src/ncg_defaults.rs).
const _kServerHost = 'rust.northwoodscomputerguy.com';
const _kServerPort = 21116;

TextStyle ncgText(double size,
        {bool bold = false, Color color = _ink, bool italic = false}) =>
    TextStyle(
        fontFamily: kNcgFont,
        fontSize: size,
        color: color,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        decoration: TextDecoration.none);

/// Wallpaper banner with the NCG badge and product name.
/// Shown bottom-right of the banner; bump with each NCG release.
const kNcgVersion = 'v1.5.0.7';

class NcgBanner extends StatelessWidget {
  const NcgBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Color(0xFF0A2A8A), offset: Offset(1, 1))];
    return SizedBox(
      height: 92,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/ncg_hill.jpg',
              fit: BoxFit.cover, alignment: const Alignment(0, 0.25)),
          Row(
            children: [
              const SizedBox(width: 14),
              Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: ClipOval(
                    child: Image.asset('assets/ncg_badge.png',
                        fit: BoxFit.cover)),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NCG Remote Assistance',
                        style: ncgText(30, bold: true, color: Colors.white, italic: true)
                            .copyWith(shadows: shadow)),
                    Text('Northwoods Computer Guy  •  Antigo, WI',
                        style: ncgText(15, bold: true, color: Colors.white)
                            .copyWith(shadows: shadow)),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 12,
            bottom: 8,
            child: Text(kNcgVersion,
                style: ncgText(12, bold: true, color: Colors.white)
                    .copyWith(shadows: shadow)),
          ),
        ],
      ),
    );
  }
}

/// XP button: green for the main action, beige for the rest.
class NcgXpButton extends StatelessWidget {
  final String label;
  final bool primary;
  final bool large;
  final VoidCallback onPressed;
  const NcgXpButton(
      {Key? key,
      required this.label,
      required this.onPressed,
      this.primary = false,
      this.large = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith((s) => primary
            ? (s.contains(MaterialState.hovered)
                ? const Color(0xFF4AAE38)
                : _green)
            : (s.contains(MaterialState.hovered)
                ? const Color(0xFFF7F5EA)
                : const Color(0xFFF1EFE2))),
        foregroundColor:
            MaterialStateProperty.all(primary ? Colors.white : _ink),
        shape: MaterialStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3),
            side: BorderSide(
                color: primary ? const Color(0xFF2C7A20) : const Color(0xFF003C74)))),
        padding: MaterialStateProperty.all(EdgeInsets.symmetric(
            horizontal: large ? 30 : 18, vertical: large ? 14 : 10)),
        minimumSize: MaterialStateProperty.all(Size(large ? 110 : 0, 0)),
      ),
      child: Text(label, style: ncgText(large ? 18 : 15, bold: true, color: primary ? Colors.white : _ink)),
    );
  }
}

/// White card with a bold blue label, used for the ID and password boxes.
class NcgCard extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const NcgCard({Key? key, required this.label, required this.children})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 26),
      decoration: BoxDecoration(
          color: Colors.white, border: Border.all(color: _cardBorder)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: ncgText(24, bold: true, color: _heading)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// Bottom status bar. Green when the NCG server answers, red when it does not.
/// Probes with a short TCP connect every few seconds, so turning the server off
/// (or losing the internet) flips it without any user action.
class NcgStatusBar extends StatefulWidget {
  const NcgStatusBar({Key? key}) : super(key: key);

  @override
  State<NcgStatusBar> createState() => _NcgStatusBarState();
}

class _NcgStatusBarState extends State<NcgStatusBar> {
  bool? _online;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _probe();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _probe());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _probe() async {
    bool ok;
    try {
      final s = await Socket.connect(_kServerHost, _kServerPort,
          timeout: const Duration(seconds: 3));
      s.destroy();
      ok = true;
    } catch (_) {
      ok = false;
    }
    if (mounted && ok != _online) setState(() => _online = ok);
  }

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    if (_online == null) {
      text = 'Checking connection...';
      color = const Color(0xFF555555);
    } else if (_online!) {
      text = '● Ready – waiting for your technician';
      color = const Color(0xFF2F7D1F);
    } else {
      text = '● Not ready – Northwoods Computer Guy is currently offline';
      color = _red;
    }
    return Container(
      width: double.infinity,
      color: _beige,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Text(text, style: ncgText(15, bold: true, color: color)),
    );
  }
}

/// XP dialog frame: Luna title bar, white body, optional icon, centred buttons.
Future<T?> showNcgDialog<T>(
  BuildContext context, {
  required String heading,
  required String body,
  List<Widget> buttons = const [],
  String? note,
  Widget? extra,
  bool barrierDismissible = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => Dialog(
      backgroundColor: _lunaDark,
      insetPadding: const EdgeInsets.all(24),
      shape: const RoundedRectangleBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 30,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.centerLeft,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0A5AF0),
                    Color(0xFF3D95FF),
                    Color(0xFF2A86FF),
                    Color(0xFF0A57E8),
                    Color(0xFF0831D9),
                    Color(0xFF0A2FB8),
                  ],
                  stops: [0, .08, .2, .5, .9, 1],
                ),
              ),
              child: Text('NCG Remote Assistance',
                  style: ncgText(15, bold: true, color: Colors.white)
                      .copyWith(shadows: const [
                    Shadow(color: Color(0xFF0F1089), offset: Offset(1, 1))
                  ])),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 0, 3, 3),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset('assets/ncg_info.png',
                            width: 80, height: 80),
                        const SizedBox(width: 22),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(heading,
                                  style: ncgText(24, bold: true, color: _heading)),
                              const SizedBox(height: 10),
                              Text(body, style: ncgText(18)),
                              if (extra != null) ...[
                                const SizedBox(height: 12),
                                extra,
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (buttons.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 14,
                          runSpacing: 10,
                          children: buttons),
                    ],
                    if (note != null) ...[
                      const SizedBox(height: 14),
                      Text(note,
                          textAlign: TextAlign.center,
                          style: ncgText(14, color: const Color(0xFF666666))),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Green marching progress bar for the install/remove dialogs.
class NcgProgress extends StatelessWidget {
  const NcgProgress({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 18,
        child: LinearProgressIndicator(
            color: _green, backgroundColor: const Color(0xFFE4E4E4)),
      );
}

const ncgLunaBlue = _luna;
