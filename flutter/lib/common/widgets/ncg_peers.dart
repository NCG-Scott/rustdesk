// NCG: peer folders, and export / import of the saved peer list.
// Kept in its own file so upstream merges only touch a few thin hooks in
// peers_view.dart, peer_card.dart and peer_tab_page.dart.
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'peer_card.dart';

const String _kFolderKey = 'ncg-folder';
const String _kNoFolder = '-'; // explicit "no folder", beats the alias rule
const String _kCollapsedKey = 'ncg-folders-collapsed';
const String _kAliasSplit = ' - '; // "Schultz Heating - Smith, John" -> "Schultz Heating"

final Map<String, String> _folderCache = {};

/// Folder of a peer: the explicit choice, else the part of the alias before " - ".
String ncgFolderOf(Peer peer) {
  var f = _folderCache[peer.id];
  if (f == null) {
    f = bind.mainGetPeerOptionSync(id: peer.id, key: _kFolderKey);
    _folderCache[peer.id] = f;
  }
  if (f == _kNoFolder) return '';
  if (f.isNotEmpty) return f;
  final i = peer.alias.indexOf(_kAliasSplit);
  return i > 0 ? peer.alias.substring(0, i).trim() : '';
}

void ncgSetFolder(String id, String folder) {
  bind.mainSetPeerOptionSync(
      id: id, key: _kFolderKey, value: folder.isEmpty ? _kNoFolder : folder);
  _folderCache.remove(id);
  bind.mainLoadRecentPeers();
}

bool ncgAnyFolders(List<Peer> peers) => peers.any((p) => ncgFolderOf(p).isNotEmpty);

void ncgFolderDialog(Peer peer) {
  final existing = <String>{};
  for (final p in gFFI.recentPeersModel.peers) {
    final f = ncgFolderOf(p);
    if (f.isNotEmpty) existing.add(f);
  }
  final names = existing.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final controller = TextEditingController(text: ncgFolderOf(peer));
  gFFI.dialogManager.show((setState, close, context) {
    submit() {
      ncgSetFolder(peer.id, controller.text.trim());
      close();
    }

    return CustomAlertDialog(
      title: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.folder_rounded, color: MyTheme.accent),
        Text(translate('Move to folder')).paddingOnly(left: 10),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
                labelText: translate('Folder name'),
                helperText: translate('Leave empty for no folder')),
          ),
          if (names.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
                spacing: 8,
                runSpacing: 4,
                children: names
                    .map((n) => ActionChip(
                        label: Text(n),
                        onPressed: () => controller.text = n))
                    .toList()),
          ],
        ],
      ),
      actions: [
        dialogButton('Cancel',
            icon: Icon(Icons.close_rounded), onPressed: close, isOutline: true),
        dialogButton('OK', icon: Icon(Icons.done_rounded), onPressed: submit),
      ],
      onSubmit: submit,
      onCancel: close,
    );
  });
}

/// Peer cards grouped under collapsible folder headers. Loose peers come first.
class NcgFolderView extends StatefulWidget {
  final List<Peer> peers;
  final Widget Function(Peer peer, bool isPortrait) buildOne;
  const NcgFolderView({super.key, required this.peers, required this.buildOne});

  @override
  State<NcgFolderView> createState() => _NcgFolderViewState();
}

class _NcgFolderViewState extends State<NcgFolderView> {
  late Set<String> _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed = bind
        .mainGetLocalOption(key: _kCollapsedKey)
        .split('|')
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  void _toggle(String folder) {
    setState(() {
      _collapsed.contains(folder)
          ? _collapsed.remove(folder)
          : _collapsed.add(folder);
    });
    bind.mainSetLocalOption(key: _kCollapsedKey, value: _collapsed.join('|'));
  }

  Widget _cards(List<Peer> peers, bool list) {
    if (list) {
      return Column(
          children: peers
              .map((p) => widget.buildOne(p, false).marginOnly(right: 12, top: 3, bottom: 3))
              .toList());
    }
    return Wrap(
        spacing: 12,
        runSpacing: 6,
        children: peers.map((p) => widget.buildOne(p, false)).toList());
  }

  @override
  Widget build(BuildContext context) {
    final loose = <Peer>[];
    final byFolder = <String, List<Peer>>{};
    for (final p in widget.peers) {
      final f = ncgFolderOf(p);
      f.isEmpty ? loose.add(p) : byFolder.putIfAbsent(f, () => []).add(p);
    }
    final folders = byFolder.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Obx(() {
      final list = peerCardUiType.value == PeerUiType.list;
      return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (loose.isNotEmpty) _cards(loose, list),
          for (final f in folders) ...[
            InkWell(
              onTap: () => _toggle(f),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(_collapsed.contains(f)
                      ? Icons.chevron_right_rounded
                      : Icons.expand_more_rounded),
                  const Icon(Icons.folder_rounded, size: 20),
                  const SizedBox(width: 6),
                  Text('$f (${byFolder[f]!.length})',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            if (!_collapsed.contains(f)) _cards(byFolder[f]!, list),
          ],
        ]),
      );
    });
  }
}

// ---- export / import ----------------------------------------------------

Directory _peersDir() => Directory(
    '${Platform.environment['APPDATA']}\\${bind.mainGetAppNameSync()}\\config\\peers');

Future<void> _exportPeers() async {
  final dir = _peersDir();
  if (!dir.existsSync()) {
    showToast(translate('No saved peers to export'));
    return;
  }
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.toml'))
      .toList();
  final entries = files.map((f) {
    final name = f.uri.pathSegments.last;
    return {
      'file': name,
      'modified': f.lastModifiedSync().millisecondsSinceEpoch,
      'toml': f.readAsStringSync(),
    };
  }).toList();
  final now = DateTime.now();
  final stamp =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final out = await FilePicker.platform.saveFile(
      dialogTitle: translate('Export peers'),
      fileName: 'NCG_Peers_$stamp.json',
      type: FileType.custom,
      allowedExtensions: ['json']);
  if (out == null) return;
  File(out).writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
    'format': 'ncg-peers',
    'version': 1,
    'exported': now.toIso8601String(),
    'peers': entries,
  }));
  showToast('${translate('Exported')} ${entries.length}');
}

Future<void> _importPeers() async {
  final res = await FilePicker.platform.pickFiles(
      dialogTitle: translate('Import peers'),
      type: FileType.custom,
      allowedExtensions: ['json']);
  final path = res?.files.single.path;
  if (path == null) return;
  try {
    final data = jsonDecode(File(path).readAsStringSync());
    if (data is! Map || data['format'] != 'ncg-peers') {
      throw 'not a peer export file';
    }
    final dir = _peersDir();
    dir.createSync(recursive: true);
    final entries = (data['peers'] as List).cast<Map>()
      ..sort((a, b) => (a['modified'] as int).compareTo(b['modified'] as int));
    var added = 0, skipped = 0;
    for (final e in entries) {
      // plain file names only, so a hand-edited file cannot write elsewhere
      final name = (e['file'] as String);
      if (name.contains(RegExp(r'[\\/:]')) || !name.endsWith('.toml')) continue;
      final f = File('${dir.path}\\$name');
      if (f.existsSync()) {
        skipped++;
        continue;
      }
      f.writeAsStringSync(e['toml'] as String);
      f.setLastModifiedSync(
          DateTime.fromMillisecondsSinceEpoch(e['modified'] as int));
      added++;
    }
    _folderCache.clear();
    bind.mainLoadRecentPeers();
    showToast('${translate('Imported')} $added, ${translate('already present')} $skipped');
  } catch (e) {
    showToast('${translate('Import failed')}: $e');
  }
}

/// Toolbar button: export / import the saved peer list.
class NcgPeerTools extends StatelessWidget {
  const NcgPeerTools({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: translate('Export / import peers'),
      icon: const Icon(Icons.import_export_rounded, size: 18),
      padding: EdgeInsets.zero,
      onSelected: (v) => v == 'export' ? _exportPeers() : _importPeers(),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'export', child: Text(translate('Export peers...'))),
        PopupMenuItem(value: 'import', child: Text(translate('Import peers...'))),
      ],
    );
  }
}
