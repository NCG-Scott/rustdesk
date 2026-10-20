import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/pages/ncg_install.dart';
import 'package:flutter_hbb/desktop/pages/ncg_xp.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

const _kDevModeOption = 'ncg-developer-mode';
// sha256("ncg-remote:" + password). Test password is "ncg-test"; replace before release.
const _kDevPasswordSha256 =
    '9094b6a36ba2e4dbe39382ab2a27bbbae2cd4e77639e3b660cf00a29a7d1b019';

final RxBool ncgDeveloperMode =
    (bind.mainGetLocalOption(key: _kDevModeOption) == 'Y').obs;

bool ncgCheckDeveloperPassword(String password) {
  final hash = sha256.convert(utf8.encode('ncg-remote:$password')).toString();
  return hash == _kDevPasswordSha256;
}

Future<void> ncgSetDeveloperMode(bool on) async {
  await bind.mainSetLocalOption(key: _kDevModeOption, value: on ? 'Y' : '');
  ncgDeveloperMode.value = on;
}

List<SettingsTabKey> ncgSettingsTabs(List<SettingsTabKey> tabs) {
  final shown = ncgDeveloperMode.value
      ? tabs
      : tabs.where((t) =>
          t == SettingsTabKey.general ||
          t == SettingsTabKey.safety ||
          t == SettingsTabKey.about);
  return [...shown, SettingsTabKey.ncgDeveloper];
}

class NcgHomePage extends StatelessWidget {
  const NcgHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // The stock page stays mounted while hidden: its initState registers state
    // (e.g. 'stop-service') that the status widget and Settings look up.
    return Obx(() => IndexedStack(
          index: ncgDeveloperMode.value ? 1 : 0,
          children: const [NcgCustomerPage(), DesktopHomePage()],
        ));
  }
}

class NcgCustomerPage extends StatelessWidget {
  const NcgCustomerPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: gFFI.serverModel,
      child: Consumer<ServerModel>(builder: (context, model, _) {
        return Container(
          color: Colors.white,
          child: Column(
            children: [
              const NcgBanner(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: NcgCard(
                                    label: translate('Your ID'),
                                    children: [
                                      const SizedBox(height: 10),
                                      _NcgValue(
                                          controller: model.serverId,
                                          size: 40),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: NcgCard(
                                    label: translate('One-time password'),
                                    children: [
                                      _NcgValue(
                                          controller: model.serverPasswd,
                                          size: 30),
                                      const SizedBox(height: 8),
                                      NcgXpButton(
                                          label: translate('New password'),
                                          primary: true,
                                          onPressed: () => bind
                                              .mainUpdateTemporaryPassword()),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                              translate(
                                  'Contact your Northwoods Computer Guy at $kNcgPhone to start your remote assistance session.'),
                              textAlign: TextAlign.center,
                              style: ncgText(18)),
                          const SizedBox(height: 16),
                          const NcgInstallSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const NcgStatusBar(),
            ],
          ),
        );
      }),
    );
  }
}

class _NcgValue extends StatelessWidget {
  final TextEditingController controller;
  final double size;
  const _NcgValue({required this.controller, required this.size});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
          border: InputBorder.none, filled: false, isDense: true),
      style: ncgText(size, bold: true),
    );
  }
}

class NcgDeveloperSettings extends StatefulWidget {
  const NcgDeveloperSettings({Key? key}) : super(key: key);

  @override
  State<NcgDeveloperSettings> createState() => _NcgDeveloperSettingsState();
}

class _NcgDeveloperSettingsState extends State<NcgDeveloperSettings> {
  final _password = TextEditingController();
  bool _wrong = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (ncgCheckDeveloperPassword(_password.text)) {
      _password.clear();
      setState(() => _wrong = false);
      await ncgSetDeveloperMode(true);
      showToast(translate('Developer mode on. Reopen Settings to see all tabs.'));
    } else {
      setState(() => _wrong = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Obx(() {
          final on = ncgDeveloperMode.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(translate('Developer mode'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                  translate(on
                      ? 'Developer mode is on. The connect box, recent sessions and all settings are available.'
                      : 'For NCG technicians. Enter the developer password to show the connect box and all settings.'),
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              if (on)
                ElevatedButton(
                    onPressed: () => ncgSetDeveloperMode(false),
                    child: Text(translate('Lock developer mode')))
              else ...[
                TextField(
                  controller: _password,
                  obscureText: true,
                  onSubmitted: (_) => _unlock(),
                  decoration: InputDecoration(
                      labelText: translate('Developer password'),
                      errorText:
                          _wrong ? translate('Wrong password') : null),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                    onPressed: _unlock, child: Text(translate('Unlock'))),
              ],
            ],
          );
        }),
      ),
    );
  }
}
