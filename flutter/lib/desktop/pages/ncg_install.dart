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

Future<void> _uninstall({bool erase = false}) async {
  await bind.mainSetLocalOption(key: _kInstallDeclinedOption, value: '');
  await Process.start(Platform.resolvedExecutable, ['--uninstall'],
      environment: erase ? {'NCG_ERASE_SETTINGS': '1'} : null,
      mode: ProcessStartMode.detached);
}

class NcgInstallSection extends StatefulWidget {
  final bool removeOnly;
  const NcgInstallSection({Key? key, this.removeOnly = false})
      : super(key: key);

  @override
  State<NcgInstallSection> createState() => _NcgInstallSectionState();
}

class _NcgInstallSectionState extends State<NcgInstallSection> {
  final bool _installed = isWindows && bind.mainIsInstalled();

  @override
  void initState() {
    super.initState();
    if (isWindows &&
        !widget.removeOnly &&
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

  Future<void> _chooseUninstall() async {
    final choice = await showNcgDialog<String>(
      context,
      heading: translate('Uninstall RA'),
      body: translate(
          'Uninstall keeps this computer\'s ID, saved peers and settings, so a reinstall picks up where you left off. Uninstall and erase deletes them too.'),
      buttons: [
        NcgXpButton(
            label: translate('Uninstall'),
            primary: true,
            large: true,
            onPressed: () => Navigator.of(context).pop('keep')),
        NcgXpButton(
            label: translate('Uninstall and erase'),
            large: true,
            onPressed: () => Navigator.of(context).pop('erase')),
        NcgXpButton(
            label: translate('Cancel'),
            large: true,
            onPressed: () => Navigator.of(context).pop('')),
      ],
    );
    if (choice == 'keep' || choice == 'erase') {
      await _confirmRemove(erase: choice == 'erase');
    }
  }

  Future<void> _confirmRemove({bool erase = false}) async {
    final ok = await showNcgDialog<bool>(
      context,
      heading: translate(
          erase ? 'Remove and erase settings?' : 'Remove from this computer?'),
      body: translate(erase
          ? 'This removes the tool AND deletes its settings: this computer\'s ID, saved peers and folders. Export your peers first if you want to keep them.'
          : 'This takes the NCG remote assistance tool off this computer. You can install it again any time.'),
      buttons: [
        NcgXpButton(
            label: translate(erase ? 'Erase' : 'Remove'),
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
      await _uninstall(erase: erase);
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
    if (!isWindows || (widget.removeOnly && !_installed)) {
      return const SizedBox.shrink();
    }
    if (_installed) {
      if (!widget.removeOnly) {
        return NcgXpButton(
            onPressed: _confirmRemove,
            label: translate('Remove from this computer'));
      }
      return NcgXpButton(
          onPressed: _chooseUninstall, label: translate('Uninstall RA'));
    }
    return NcgXpButton(
        onPressed: _startInstall,
        label: translate('Install on this computer'));
  }
}
