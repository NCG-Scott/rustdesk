import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';

const _kInstallDeclinedOption = 'ncg-install-declined';
const _kInstallOptions = 'startmenu desktopicon';
const _kInstallErrorOption = 'ncg-install-error';

Future<void> _install() async {
  await bind.mainSetLocalOption(key: _kInstallDeclinedOption, value: '');
  bind.installInstallMe(options: _kInstallOptions, path: '');
}

Future<void> _uninstall() async {
  await bind.mainSetLocalOption(key: _kInstallDeclinedOption, value: '');
  await Process.start(Platform.resolvedExecutable, ['--uninstall'],
      mode: ProcessStartMode.detached);
}

class NcgInstallSection extends StatefulWidget {
  const NcgInstallSection({Key? key}) : super(key: key);

  @override
  State<NcgInstallSection> createState() => _NcgInstallSectionState();
}

class _NcgInstallSectionState extends State<NcgInstallSection> {
  final bool _installed = isWindows && bind.mainIsInstalled();

  @override
  void initState() {
    super.initState();
    if (isWindows &&
        !_installed &&
        bind.mainGetLocalOption(key: _kInstallDeclinedOption) != 'Y') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _offer());
    }
  }

  Future<void> _offer() async {
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(translate('Install NCG Remote on this computer?')),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(translate(
              'Windows will ask for permission once. After that, NCG Remote starts with Windows and your technician does not need you to approve administrator prompts during a repair. You still give your technician the password or accept their request each time. You can remove it any time.')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(translate('Not now'))),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(translate('Install'))),
        ],
      ),
    );
    if (accepted == true) {
      _startInstall();
    } else {
      await bind.mainSetLocalOption(key: _kInstallDeclinedOption, value: 'Y');
    }
  }

  Future<void> _confirmRemove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translate('Remove NCG Remote from this computer?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(translate('Cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(translate('Remove'))),
        ],
      ),
    );
    if (ok == true) {
      _showProgress(
          'Thank you for using the NCG remote assistance tool',
          'It is being removed from this computer now. This window will close by itself.');
      await _uninstall();
    }
  }

  Future<void> _startInstall() async {
    _showProgress('The NCG remote assistance tool is installing',
        'This will take a few seconds. If Windows asks for permission, choose Yes. This window will reopen when it is done.');
    await bind.mainSetLocalOption(key: _kInstallErrorOption, value: '');
    await _install();
    _watchInstall();
  }

  Future<void> _watchInstall() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final error = bind.mainGetLocalOption(key: _kInstallErrorOption);
      if (error.isNotEmpty) {
        Navigator.of(context).pop();
        _showInstallFailed(error);
        return;
      }
    }
  }

  void _showInstallFailed(String detail) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translate('NCG Remote was not installed')),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(translate(
                  'The installation was cancelled or did not finish. Nothing was changed. You can try again with the Install button, or keep using NCG Remote from this window.')),
              const SizedBox(height: 12),
              Text(detail, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(translate('OK'))),
        ],
      ),
    );
  }

  void _showProgress(String title, String body) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(translate(title)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(translate(body)),
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isWindows) return const SizedBox.shrink();
    if (_installed) {
      return TextButton(
          onPressed: _confirmRemove,
          child: Text(translate('Remove NCG Remote from this computer')));
    }
    return OutlinedButton(
        onPressed: _startInstall,
        child: Text(translate('Install NCG Remote on this computer')));
  }
}
