import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/gcp_backend_service.dart';
import '../../services/native_bridge_service.dart';
import '../../services/vault_storage.dart';

Future<void> showSettingsAndVaultSheet({
  required BuildContext context,
  required AuthService auth,
  required VaultStorage vault,
  required GcpBackendService backend,
  required String pageContext,
  String initialAccordion = 'account',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SettingsSheetBody(
      auth: auth,
      vault: vault,
      backend: backend,
      pageContext: pageContext,
      initialAccordion: initialAccordion,
    ),
  );
}

class _SettingsSheetBody extends StatefulWidget {
  final AuthService auth;
  final VaultStorage vault;
  final GcpBackendService backend;
  final String pageContext;
  final String initialAccordion;

  const _SettingsSheetBody({
    required this.auth,
    required this.vault,
    required this.backend,
    required this.pageContext,
    required this.initialAccordion,
  });

  @override
  State<_SettingsSheetBody> createState() => _SettingsSheetBodyState();
}

class _SettingsSheetBodyState extends State<_SettingsSheetBody> {
  late String _openSection;
  bool _isRegisterMode = true;
  String? _authMessage;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _bugCtrl = TextEditingController();
  List<BugReportRecord> _openBugs = [];

  @override
  void initState() {
    super.initState();
    _openSection = widget.initialAccordion;
    _refreshBugs();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _bugCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshBugs() async {
    final list = await widget.backend.getOpenBugReportsForCurrentUser(widget.auth.currentUser.email);
    if (mounted) {
      setState(() => _openBugs = list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        key: const Key('settings_vault_sheet'),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: cs.outline)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Settings & Vault', style: tt.titleMedium)),
                  TextButton(
                    key: const Key('close_settings_btn'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close', style: TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline),
                ),
                child: Column(
                  children: [
                    // 1. Account & Cloud Sync
                    _accordionHeader(
                      key: const Key('acc_account_header'),
                      title: 'Account & Cloud Sync',
                      trailing: widget.auth.isGuest ? 'Offline Guest' : widget.auth.currentUser.email,
                      sectionId: 'account',
                    ),
                    if (_openSection == 'account')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: widget.auth.isGuest
                            ? _buildGuestAuthForm(context)
                            : _buildSignedInRow(context),
                      ),

                    Divider(height: 1, color: cs.outline),

                    // 2. Appearance
                    _accordionHeader(
                      key: const Key('acc_theme_header'),
                      title: 'Appearance',
                      trailing: widget.vault.themeMode == ThemeMode.dark ? 'Dark' : 'Light',
                      sectionId: 'theme',
                    ),
                    if (_openSection == 'theme')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await widget.vault.setThemeMode(ThemeMode.light);
                                  if (mounted) setState(() {});
                                },
                                child: const Text('Light Paper', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await widget.vault.setThemeMode(ThemeMode.dark);
                                  if (mounted) setState(() {});
                                },
                                child: const Text('Dark Charcoal', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Divider(height: 1, color: cs.outline),

                    // 3. Reflection & Spaced Reminders
                    _accordionHeader(
                      key: const Key('acc_reminders_header'),
                      title: 'Reflection & Spaced Reminders',
                      trailing: widget.vault.remindersEnabled ? 'Notify: ON' : 'Off',
                      sectionId: 'reminders',
                    ),
                    if (_openSection == 'reminders')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gentle focus (${widget.vault.amTime}) & evening review (${widget.vault.pmTime}), plus Day 1/10/30/60 SuperMemo recall.',
                              style: tt.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              key: const Key('reminders_notify_switch'),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text('Enable daily notifications', style: tt.bodyMedium?.copyWith(fontSize: 13)),
                              value: widget.vault.remindersEnabled,
                              onChanged: (val) async {
                                await widget.vault.updateReminders(enabled: val);
                                if (mounted) setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),

                    Divider(height: 1, color: cs.outline),

                    // 4. Export Decisions
                    _accordionHeader(
                      key: const Key('acc_export_header'),
                      title: 'Export Decisions',
                      trailing: '.md / .json',
                      sectionId: 'export',
                    ),
                    if (_openSection == 'export')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('export_md_btn'),
                                onPressed: () async {
                                  await NativeBridgeService.saveExportDocument(
                                    filename: 'untangle_journal.md',
                                    mimeType: 'text/markdown',
                                    content: widget.vault.buildMarkdownBrief(),
                                  );
                                },
                                child: const Text('Export .md', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('export_json_btn'),
                                onPressed: () async {
                                  await NativeBridgeService.saveExportDocument(
                                    filename: 'untangle_vault.json',
                                    mimeType: 'application/json',
                                    content: const JsonEncoder.withIndent('  ')
                                        .convert(widget.vault.exportSnapshotMap()),
                                  );
                                },
                                child: const Text('Export .json', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Divider(height: 1, color: cs.outline),

                    // 5. Closed-Loop Bug Triage
                    _accordionHeader(
                      key: const Key('acc_bugs_header'),
                      title: 'Report an Issue',
                      trailing: 'Open (${_openBugs.length})',
                      sectionId: 'bugs',
                    ),
                    if (_openSection == 'bugs')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: _buildBugSection(context),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accordionHeader({
    Key? key,
    required String title,
    required String trailing,
    required String sectionId,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      key: key,
      onTap: () {
        setState(() {
          _openSection = _openSection == sectionId ? '' : sectionId;
        });
        if (_openSection == 'bugs') _refreshBugs();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                trailing,
                style: tt.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.65)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestAuthForm(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Decisions stay privately on-device in Guest Mode. Upgrade anytime with zero data loss.',
          style: tt.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('auth_tab_register'),
              label: const Text('Create Account', style: TextStyle(fontSize: 12)),
              selected: _isRegisterMode,
              onSelected: (_) => setState(() => _isRegisterMode = true),
            ),
            ChoiceChip(
              key: const Key('auth_tab_login'),
              label: const Text('Sign In', style: TextStyle(fontSize: 12)),
              selected: !_isRegisterMode,
              onSelected: (_) => setState(() => _isRegisterMode = false),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isRegisterMode) ...[
          TextField(
            key: const Key('auth_name_field'),
            controller: _nameCtrl,
            decoration: const InputDecoration(hintText: 'Your name'),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          key: const Key('auth_email_field'),
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'Email address'),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('auth_password_field'),
          controller: _passCtrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Password (min 6 chars)'),
        ),
        if (_authMessage != null) ...[
          const SizedBox(height: 6),
          Text(_authMessage!, style: tt.bodySmall?.copyWith(color: Colors.redAccent)),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                key: const Key('auth_submit_email_btn'),
                onPressed: () async {
                  final err = await widget.vault.upgradeGuestOrSwitchAccount(
                    authAction: () => _isRegisterMode
                        ? widget.auth.registerWithEmail(
                            name: _nameCtrl.text,
                            email: _emailCtrl.text,
                            password: _passCtrl.text,
                          )
                        : widget.auth.loginWithEmail(
                            email: _emailCtrl.text,
                            password: _passCtrl.text,
                          ),
                  );
                  if (!mounted) return;
                  if (err != null) {
                    setState(() => _authMessage = err);
                  } else {
                    setState(() => _authMessage = null);
                    await _refreshBugs();
                  }
                },
                child: Text(_isRegisterMode ? 'Register & Sync' : 'Sign In', style: const TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const Key('auth_google_btn'),
                onPressed: () async {
                  final err = await widget.vault.upgradeGuestOrSwitchAccount(
                    authAction: widget.auth.signInWithGoogleHandoff,
                  );
                  if (!mounted) return;
                  if (err != null) setState(() => _authMessage = err);
                },
                child: const Text('Google SSO', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignedInRow(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.auth.currentUser.name, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text(widget.auth.currentUser.email, style: tt.bodySmall, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          key: const Key('auth_signout_btn'),
          onPressed: () async {
            await widget.vault.signOutCleanly();
            await _refreshBugs();
            if (mounted) setState(() {});
          },
          child: const Text('Sign Out', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildBugSection(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${widget.pageContext} · v${GcpBackendService.appVersion}', style: tt.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('bug_description_field'),
                controller: _bugCtrl,
                decoration: const InputDecoration(hintText: 'Describe issue or UX suggestion...'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('bug_submit_btn'),
              onPressed: () async {
                final text = _bugCtrl.text.trim();
                if (text.isEmpty) return;
                await widget.backend.submitBugReport(
                  description: text,
                  pageContext: widget.pageContext,
                  userEmail: widget.auth.currentUser.email,
                );
                _bugCtrl.clear();
                await _refreshBugs();
              },
              child: const Text('Send', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Open Reports (${_openBugs.length})', style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (_openBugs.isEmpty)
          Text('No open reports for your account.', style: tt.bodySmall)
        else
          for (final b in _openBugs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(b.description, style: tt.bodyMedium?.copyWith(fontSize: 12.5))),
                  const SizedBox(width: 8),
                  Text(b.pageContext, style: tt.bodySmall),
                ],
              ),
            ),
      ],
    );
  }
}
