import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
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
        final theme = Theme.of(context);
        return Container(
          color: theme.colorScheme.background,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(translate('Read these two things to your technician'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(
                              translate(
                                  'You do not need to type anything. Your technician connects from their side.'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 24),
                          _NcgField(
                            label: translate('Your ID'),
                            controller: model.serverId,
                            actions: [
                              _NcgButton(
                                  label: translate('Copy'),
                                  filled: false,
                                  onPressed: () => _copy(model.serverId.text)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _NcgField(
                            label: translate('Your password'),
                            controller: model.serverPasswd,
                            actions: [
                              _NcgButton(
                                  label: translate('Copy'),
                                  filled: false,
                                  onPressed: () =>
                                      _copy(model.serverPasswd.text)),
                              _NcgButton(
                                  label: translate('New password'),
                                  filled: true,
                                  onPressed: () =>
                                      bind.mainUpdateTemporaryPassword()),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                              translate(
                                  'A new password is made each time this window opens, and you can make another at any time.'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: OnlineStatusWidget()),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showToast(translate('Copied'));
  }
}

class _NcgField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final List<Widget> actions;
  const _NcgField(
      {required this.label, required this.controller, required this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: TextField(
                  controller: controller,
                  readOnly: true,
                  decoration: const InputDecoration(border: InputBorder.none),
                  style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5),
                ),
              ),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
        ],
      ),
    );
  }
}

class _NcgButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onPressed;
  const _NcgButton(
      {required this.label, required this.filled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
        minimumSize: MaterialStateProperty.all(const Size(0, 44)),
        textStyle: MaterialStateProperty.all(
            const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
    return filled
        ? ElevatedButton(onPressed: onPressed, style: style, child: Text(label))
        : OutlinedButton(onPressed: onPressed, style: style, child: Text(label));
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
