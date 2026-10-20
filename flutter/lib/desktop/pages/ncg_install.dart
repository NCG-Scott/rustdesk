import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/pages/ncg_xp.dart';
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
    final accepted = await showNcgDialog<bool>(
      context,
      heading: translate('Install on this computer?'),
      body: translate(
          'Installing this lets Scott help you again without you having to do any of these steps over. A Windows box will pop up asking for your permission – just choose Yes and it will install.'),
      buttons: [
        NcgXpButton(
            label: translate('Install'),
            primary: true,
            large: true,
            onPressed: () => Navigator.of(context).pop(true)),
        NcgXpButton(
            label: translate('Not now'),
            large: true,
            onPressed: () => Navigator.of(context).pop(false)),
      ],
      note: translate('You can remove it any time from this same window.'),
    );
    if (accepted == true) {
      _startInstall();
    } else {
      await bind.mainSetLocalOption(key: _kInstallDeclinedOption, value: 'Y');
    }
  }

  Future<void> _confirmRemove() async {
    final ok = await showNcgDialog<bool>(
      context,
      heading: translate('Remove from this computer?'),
      body: translate(
          'This takes the NCG remote assistance tool off this computer. You can install it again any time.'),
      buttons: [
        NcgXpButton(
            label: translate('Remove'),
            primary: true,
            large: true,
            onPressed: () => Navigator.of(context).pop(true)),
        NcgXpButton(
            label: translate('Cancel'),
            large: true,
            onPressed: () => Navigator.of(context).pop(false)),
      ],
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
    showNcgDialog<void>(
      context,
      heading: translate('NCG Remote was not installed'),
      body: translate(
          'The installation was cancelled or did not finish. Nothing was changed. You can try again with the Install button, or keep using NCG Remote from this window.'),
      extra: Text(detail, style: ncgText(12)),
      buttons: [
        NcgXpButton(
            label: translate('OK'),
            primary: true,
            large: true,
            onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }

  void _showProgress(String title, String body) {
    if (!mounted) return;
    showNcgDialog<void>(
      context,
      heading: translate(title),
      body: translate(body),
      extra: const NcgProgress(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isWindows) return const SizedBox.shrink();
    if (_installed) {
      return NcgXpButton(
          onPressed: _confirmRemove,
          label: translate('Remove from this computer'));
    }
    return NcgXpButton(
        onPressed: _startInstall,
        label: translate('Install on this computer'));
  }
}
