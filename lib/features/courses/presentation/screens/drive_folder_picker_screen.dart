import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/services/google_drive_service.dart';
import '../../../../core/services/google_sign_in_button.dart';
import '../../../../core/theme/app_colors.dart';

class DriveFolderPickerScreen extends StatefulWidget {
  const DriveFolderPickerScreen({
    super.key,
    this.allowFiles = false,
    this.multiSelect = false,
  });

  /// When true, individual files show up alongside folders and tapping one
  /// immediately returns its link — for pickers that need a specific file
  /// (e.g. a lecture PDF), not just a folder.
  final bool allowFiles;

  /// When true (implies [allowFiles]), tapping a file toggles a checkbox
  /// instead of returning immediately — the "تم" button then pops the
  /// whole `List<DriveItem>` selection at once.
  final bool multiSelect;

  @override
  State<DriveFolderPickerScreen> createState() =>
      _DriveFolderPickerScreenState();
}

class _DriveFolderPickerScreenState extends State<DriveFolderPickerScreen> {
  final _service = GoogleDriveService();
  final List<DriveFolder> _path = [];
  Future<List<DriveItem>>? _future;
  final Map<String, DriveItem> _selected = {};

  GoogleSignInAccount? _account;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;
  bool _resolvingAccount = true;
  String? _signInError;

  DriveFolder get _current => _path.last;

  @override
  void initState() {
    super.initState();
    final rootId = dotenv.env['GOOGLE_DRIVE_ROOT_FOLDER_ID'] ?? '';
    _path.add(DriveFolder(id: rootId, name: 'مواد الكورسات'));
    _resolveAccount();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _resolveAccount() async {
    setState(() {
      _resolvingAccount = true;
      _signInError = null;
    });
    try {
      final silent = await _service.attemptSilentSignIn();
      if (silent != null) {
        _onSignedIn(silent);
        return;
      }
      if (await _service.supportsDirectSignIn) {
        final account = await _service.signInInteractively();
        _onSignedIn(account);
        return;
      }
      // Web: wait for the user to sign in via the rendered button.
      _authSub ??= _service.authenticationEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            _onSignedIn(event.user);
          }
        },
        onError: (Object e) {
          if (mounted) setState(() => _signInError = e.toString());
        },
      );
      if (mounted) setState(() => _resolvingAccount = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _resolvingAccount = false;
          _signInError = e.toString();
        });
      }
    }
  }

  void _onSignedIn(GoogleSignInAccount account) {
    if (!mounted) return;
    setState(() {
      _account = account;
      _resolvingAccount = false;
      _signInError = null;
    });
    _load();
  }

  void _load() {
    final account = _account;
    if (account == null) return;
    setState(() {
      _future = _service.listFolderContents(account, _current.id);
    });
  }

  void _openFolder(DriveItem folder) {
    setState(
      () => _path.add(
        DriveFolder(
          id: folder.id,
          name: folder.name,
          webViewLink: folder.webViewLink,
        ),
      ),
    );
    _load();
  }

  void _selectFile(DriveItem file) {
    if (widget.multiSelect) {
      setState(() {
        if (_selected.containsKey(file.id)) {
          _selected.remove(file.id);
        } else {
          _selected[file.id] = file;
        }
      });
      return;
    }
    final link =
        file.webViewLink ?? 'https://drive.google.com/file/d/${file.id}/view';
    Navigator.of(context).pop(link);
  }

  void _confirmSelection() {
    Navigator.of(context).pop(_selected.values.toList());
  }

  void _goToBreadcrumb(int index) {
    if (index == _path.length - 1) return;
    setState(() => _path.removeRange(index + 1, _path.length));
    _load();
  }

  void _selectCurrent() {
    final link =
        _current.webViewLink ??
        'https://drive.google.com/drive/folders/${_current.id}';
    Navigator.of(context).pop(link);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختيار مجلد من Drive'),
        bottom: _account == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      children: [
                        for (var i = 0; i < _path.length; i++) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.chevron_left,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                            ),
                          InkWell(
                            onTap: () => _goToBreadcrumb(i),
                            child: Text(
                              _path[i].name,
                              style: TextStyle(
                                fontSize: 13,
                                color: i == _path.length - 1
                                    ? AppColors.accent
                                    : AppColors.textMuted,
                                fontWeight: i == _path.length - 1
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
      body: _account == null ? _buildSignInBody() : _buildFolderBody(),
      floatingActionButton: _account == null
          ? null
          : widget.multiSelect
          ? FloatingActionButton.extended(
              onPressed: _selected.isEmpty ? null : _confirmSelection,
              icon: const Icon(Icons.check),
              label: Text('تم (${_selected.length})'),
            )
          : FloatingActionButton.extended(
              onPressed: _selectCurrent,
              icon: const Icon(Icons.check),
              label: const Text('اختيار هذا المجلد'),
            ),
    );
  }

  Widget _buildSignInBody() {
    if (_resolvingAccount) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.login, color: AppColors.accent, size: 40),
            const SizedBox(height: 12),
            const Text(
              'سجّل دخول بحساب جوجل عشان تقدر تتصفح Drive',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            if (_signInError != null) ...[
              const SizedBox(height: 12),
              Text(
                _signInError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _resolveAccount,
                child: const Text('إعادة المحاولة'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              SizedBox(height: 44, child: renderGoogleSignInButton()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFolderBody() {
    return FutureBuilder<List<DriveItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'حصل خطأ في الاتصال بـ Drive:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }
        final showFiles = widget.allowFiles || widget.multiSelect;
        final items = (snapshot.data ?? [])
            .where((i) => showFiles || i.isFolder)
            .toList();
        if (items.isEmpty) {
          return Center(
            child: Text(
              showFiles ? 'المجلد ده فاضي' : 'مفيش مجلدات فرعية هنا',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final isSelected = _selected.containsKey(item.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: Icon(
                  item.isFolder
                      ? Icons.folder
                      : Icons.insert_drive_file_outlined,
                  color: AppColors.accent,
                ),
                title: Text(item.name),
                trailing: item.isFolder
                    ? const Icon(Icons.chevron_left)
                    : widget.multiSelect
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (_) => _selectFile(item),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                onTap: () =>
                    item.isFolder ? _openFolder(item) : _selectFile(item),
              ),
            );
          },
        );
      },
    );
  }
}
