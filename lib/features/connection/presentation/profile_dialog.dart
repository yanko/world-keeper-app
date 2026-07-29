import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:world_keeper/app/breakpoints.dart';
import 'package:world_keeper/core/config/models.dart';
import 'package:world_keeper/l10n/l10n.dart';

/// Creates or edits a connection profile.
///
/// Editing **starts from the existing profile object** and only replaces the fields this
/// form shows, so auth method, key path, saved-password flag and cached discovery all
/// survive an edit. The store writes whole profiles, so building a fresh one here would
/// silently wipe everything the form doesn't display.
Future<Profile?> showProfileDialog(BuildContext context, {Profile? existing}) {
  final isCompact = context.windowSize.isCompact;
  return showDialog<Profile>(
    context: context,
    // A phone gets a full-screen dialog: the fields plus keyboard don't fit an inset one.
    useSafeArea: true,
    builder: (context) =>
        _ProfileDialog(existing: existing, fullScreen: isCompact),
  );
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.existing, required this.fullScreen});

  final Profile? existing;
  final bool fullScreen;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _keyPath;
  late AuthMethod _auth;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _host = TextEditingController(text: p?.host ?? '');
    _port = TextEditingController(text: '${p?.port ?? 22}');
    _user = TextEditingController(text: p?.user ?? 'root');
    _keyPath = TextEditingController(text: p?.keyPath ?? '');
    _auth = p?.auth ?? AuthMethod.password;
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _keyPath.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final existing = widget.existing;
    final keyPath = _keyPath.text.trim();

    final profile =
        (existing ??
                Profile(
                  id: _newId(),
                  name: '',
                  host: '',
                  user: '',
                  auth: AuthMethod.password,
                ))
            .copyWith(
              name: _name.text.trim(),
              host: _host.text.trim(),
              port: int.tryParse(_port.text.trim()) ?? 22,
              user: _user.text.trim(),
              auth: _auth,
              keyPath: _auth == AuthMethod.key && keyPath.isNotEmpty
                  ? keyPath
                  : null,
            );

    Navigator.pop(context, profile);
  }

  /// A UUID v4, matching the id format the Rust app's `crypto.randomUUID()` produces so
  /// profiles from either app look alike in the shared config.
  static String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = UniqueKey().hashCode.toRadixString(16).padLeft(8, '0');
    final hex = now.toRadixString(16).padLeft(16, '0');
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(12, 15)}'
        '-a${rand.substring(0, 3)}-${rand.substring(0, 8)}${hex.substring(0, 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEdit = widget.existing != null;
    final title = isEdit
        ? l10n.profileEditTitle(widget.existing!.name)
        : l10n.profileNewTitle;

    final form = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.profileName,
              // An example, not a translatable string: it is what someone would actually
              // type in this box.
              hintText: 'Core Keeper LXC',
            ),
            validator: (v) => _required(l10n, v),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _host,
                  decoration: InputDecoration(labelText: l10n.profileHost),
                  validator: (v) => _required(l10n, v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _port,
                  decoration: InputDecoration(labelText: l10n.profilePort),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final port = int.tryParse((v ?? '').trim());
                    if (port == null || port < 1 || port > 65535) {
                      // A numeric range, the same in every language.
                      return '1–65535';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _user,
            decoration: InputDecoration(labelText: l10n.profileUser),
            validator: (v) => _required(l10n, v),
          ),
          const SizedBox(height: 12),
          SegmentedButton<AuthMethod>(
            segments: [
              ButtonSegment(
                value: AuthMethod.password,
                label: Text(l10n.profileAuthPassword),
                icon: const Icon(Icons.password, size: 18),
              ),
              ButtonSegment(
                value: AuthMethod.key,
                label: Text(l10n.profileAuthKey),
                icon: const Icon(Icons.key, size: 18),
              ),
            ],
            selected: {_auth},
            onSelectionChanged: (s) => setState(() => _auth = s.first),
          ),
          if (_auth == AuthMethod.key) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _keyPath,
              decoration: InputDecoration(
                labelText: l10n.profileKeyPath,
                hintText: 'C:\\Users\\you\\.ssh\\id_ed25519',
              ),
              validator: (v) =>
                  _auth == AuthMethod.key && (v ?? '').trim().isEmpty
                  ? l10n.profileKeyPathRequired
                  : null,
            ),
          ],
        ],
      ),
    );

    final actions = <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.commonCancel),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(isEdit ? l10n.profileSaveChanges : l10n.profileAdd),
      ),
    ];

    if (widget.fullScreen) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(title),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton(onPressed: _submit, child: Text(l10n.commonSave)),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: form,
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(title),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: form)),
      actions: actions,
    );
  }

  static String? _required(AppLocalizations l10n, String? v) =>
      (v ?? '').trim().isEmpty ? l10n.profileFieldRequired : null;
}
