import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:takesep_design_system/takesep_design_system.dart';
import 'package:http/http.dart' as http;

/// Current app version — update this when releasing a new build.
/// Must match the version in pubspec.yaml (without the +buildNumber).
const String kAppVersion = '1.0.1';
const int kAppBuildNumber = 1;

class UpdateService {
  static final _supabase = Supabase.instance.client;

  /// Check for updates and show a dialog if a newer version is available.
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final platform = _currentPlatform;
      if (platform == null) return;

      final response = await _supabase
          .from('app_versions')
          .select()
          .eq('platform', platform)
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return;

      final latestBuild = (response['build_number'] as num?)?.toInt() ?? 0;
      final latestVersion = response['version'] as String? ?? '';
      final downloadUrl = response['download_url'] as String?;
      final releaseNotes = response['release_notes'] as String?;
      final forceUpdate = response['force_update'] as bool? ?? false;

      if (latestBuild <= kAppBuildNumber) return;

      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: !forceUpdate,
        builder: (ctx) => _UpdateDialog(
          version: latestVersion,
          releaseNotes: releaseNotes,
          downloadUrl: downloadUrl ?? '',
          forceUpdate: forceUpdate,
        ),
      );
    } catch (e) {
      debugPrint('[UpdateService] Error checking for updates: $e');
    }
  }

  static String? get _currentPlatform {
    try {
      if (Platform.isWindows) return 'windows';
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
    } catch (_) {}
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════
// UPDATE DIALOG — with download progress & auto-install
// ═══════════════════════════════════════════════════════════════

class _UpdateDialog extends StatefulWidget {
  final String version;
  final String? releaseNotes;
  final String downloadUrl;
  final bool forceUpdate;

  const _UpdateDialog({
    required this.version,
    this.releaseNotes,
    required this.downloadUrl,
    required this.forceUpdate,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _UpdateStage _stage = _UpdateStage.prompt;
  double _progress = 0;
  String _statusText = '';
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !widget.forceUpdate && _stage != _UpdateStage.downloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _stage == _UpdateStage.done
                      ? Icons.check_circle_rounded
                      : _stage == _UpdateStage.error
                          ? Icons.error_rounded
                          : Icons.system_update_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                _stage == _UpdateStage.done
                    ? 'Обновление загружено'
                    : _stage == _UpdateStage.error
                        ? 'Ошибка обновления'
                        : 'Доступно обновление',
                style: AppTypography.headlineSmall.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              // Version badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v${widget.version}',
                  style: const TextStyle(
                    color: Color(0xFF6C5CE7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Release notes (only on prompt stage)
              if (_stage == _UpdateStage.prompt &&
                  widget.releaseNotes != null &&
                  widget.releaseNotes!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Что нового:',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(widget.releaseNotes!,
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.8),
                              fontSize: 13,
                              height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Download progress
              if (_stage == _UpdateStage.downloading) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor:
                        cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF6C5CE7)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Text(_statusText,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 12)),
                const SizedBox(height: 8),
              ],

              // Error message
              if (_stage == _UpdateStage.error && _errorText != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_errorText!,
                      style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          height: 1.3)),
                ),
                const SizedBox(height: 16),
              ],

              // Buttons
              if (_stage == _UpdateStage.prompt) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _startUpdate,
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text('Обновить сейчас'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (!widget.forceUpdate) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Позже',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.4),
                            fontSize: 14)),
                  ),
                ],
                if (widget.forceUpdate) ...[
                  const SizedBox(height: 8),
                  Text('Это обязательное обновление',
                      style: TextStyle(
                          color: AppColors.error.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ],

              if (_stage == _UpdateStage.done) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _launchInstaller,
                    icon: const Icon(Icons.install_desktop_rounded, size: 20),
                    label: const Text('Установить и перезапустить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],

              if (_stage == _UpdateStage.error) ...[
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openInBrowser(),
                      child: const Text('Скачать вручную', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _startUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Повторить', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startUpdate() async {
    if (widget.downloadUrl.isEmpty) {
      setState(() {
        _stage = _UpdateStage.error;
        _errorText = 'Ссылка для скачивания недоступна.';
      });
      return;
    }

    setState(() {
      _stage = _UpdateStage.downloading;
      _progress = 0;
      _statusText = 'Подготовка...';
      _errorText = null;
    });

    try {
      final dir = await getTemporaryDirectory();
      final ext = Platform.isWindows ? '.exe' : '.apk';
      final filePath = '${dir.path}/TakEsep-update$ext';
      final file = File(filePath);

      // Delete previous download if exists
      if (await file.exists()) await file.delete();

      // Start download with progress tracking
      final request = http.Request('GET', Uri.parse(widget.downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (totalBytes > 0) {
          setState(() {
            _progress = receivedBytes / totalBytes;
            final mb = (receivedBytes / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (totalBytes / 1024 / 1024).toStringAsFixed(1);
            _statusText = 'Загрузка: $mb / $totalMb МБ';
          });
        } else {
          setState(() {
            final mb = (receivedBytes / 1024 / 1024).toStringAsFixed(1);
            _statusText = 'Загрузка: $mb МБ...';
          });
        }
      }

      await sink.close();

      setState(() {
        _stage = _UpdateStage.done;
        _statusText = 'Загрузка завершена';
      });

      // On Android, auto-launch install prompt
      if (Platform.isAndroid) {
        _launchInstaller();
      }
    } catch (e) {
      setState(() {
        _stage = _UpdateStage.error;
        _errorText = 'Не удалось скачать: $e';
      });
    }
  }

  void _launchInstaller() async {
    try {
      final dir = await getTemporaryDirectory();

      if (Platform.isWindows) {
        final installerPath = '${dir.path}/TakEsep-update.exe';
        // Launch installer with /SILENT flag → closes app → installs → relaunches
        await Process.start(installerPath, ['/SILENT', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
            mode: ProcessStartMode.detached);
        // Exit current app so installer can replace files
        exit(0);
      } else if (Platform.isAndroid) {
        // On Android, open the download URL in browser for manual install
        // Direct APK install from temp dir requires FileProvider + content:// URI
        // which needs native channel. Browser download is more reliable.
        _openInBrowser();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = _UpdateStage.error;
          _errorText = 'Не удалось запустить установку: $e';
        });
      }
    }
  }

  void _openInBrowser() async {
    final uri = Uri.parse(widget.downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

enum _UpdateStage { prompt, downloading, done, error }
