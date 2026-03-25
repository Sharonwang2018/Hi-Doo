import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/screens/book_confirm_screen.dart';
import 'package:echo_reading/screens/manual_book_entry_screen.dart';
import 'package:echo_reading/services/book_api_service.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanBookScreen extends StatefulWidget {
  const ScanBookScreen({super.key});

  @override
  State<ScanBookScreen> createState() => _ScanBookScreenState();
}

class _ScanBookScreenState extends State<ScanBookScreen> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.normal,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
  );
  final BookApiService _bookApiService = BookApiService();

  bool _isProcessing = false;
  /// 从扫码到确认页返回整段流程中为 true，避免去掉转圈后误触发第二次识别。
  bool _scanFlowActive = false;

  static const Duration _fetchIsbnTimeout = Duration(seconds: 30);

  Future<void> _safeScannerStop() async {
    try {
      await _controller.stop().timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> _safeScannerStart() async {
    try {
      await _controller.start().timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openManualEntry({String? initialIsbn}) async {
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }
    await _controller.stop();
    if (!mounted) return;
    final book = await Navigator.push<BookLookupResult?>(
      context,
      MaterialPageRoute(
        builder: (_) => ManualBookEntryScreen(initialIsbn: initialIsbn),
      ),
    );
    if (!mounted) return;
    await _controller.start();
    if (!mounted) return;
    if (book == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BookConfirmScreen(book: book)),
    );
    if (!mounted) return;
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('书籍录入完成')),
      );
    }
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isProcessing || _scanFlowActive) return;

    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;

    final isbn = _bookApiService.normalizeIsbn(raw);
    if (isbn == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未识别到有效 ISBN（10/13位）')));
      return;
    }

    _scanFlowActive = true;
    setState(() {
      _isProcessing = true;
    });

    // stop() 若在 try 外且 Web 上永不 complete，下面的 finally 永远执行不到，会无限转圈。
    try {
      await _safeScannerStop();

      try {
        final book = await _bookApiService.fetchByIsbn(isbn).timeout(
          _fetchIsbnTimeout,
          onTimeout: () => throw TimeoutException(
            '查书超时，请改用手动输入',
            _fetchIsbnTimeout,
          ),
        );
        if (!mounted) return;
        if (book == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('扫码书库中没有此书，请手动输入书名等信息'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '去输入',
                onPressed: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _openManualEntry(initialIsbn: isbn);
                  });
                },
              ),
            ),
          );
          await _safeScannerStart();
          return;
        }

        // push 会阻塞到用户从确认页返回；若等到那时才在 finally 里清 _isProcessing，
        // Safari/Chrome 上扫码页会一直盖着转圈（看起来像「永远转圈」）。
        if (mounted) {
          setState(() => _isProcessing = false);
        }

        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => BookConfirmScreen(book: book)),
        );

        if (!mounted) return;
        if (saved == true) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('扫码录入完成')));
        }
        await _safeScannerStart();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('处理失败：$error')));
        await _safeScannerStart();
      }
    } finally {
      _scanFlowActive = false;
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫码录入书籍'),
        actions: [
          TextButton(
            onPressed: _isProcessing
                ? null
                : () => _openManualEntry(),
            child: const Text('手动输入'),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: (context, error) {
              final isWebHttp = kIsWeb && Uri.base.scheme == 'http';
              final needHttps = isWebHttp &&
                  (error.errorCode == MobileScannerErrorCode.permissionDenied ||
                      error.errorCode == MobileScannerErrorCode.unsupported);
              return ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam_off_rounded,
                          size: 64,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          needHttps
                              ? '扫码需要 HTTPS'
                              : '相机无法使用',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          needHttps
                              ? '手机浏览器要求通过 HTTPS 访问才能使用相机。\n请用 run_all.sh（不用 HTTP=1）启动，或改用本机 localhost 测试。'
                              : error.errorDetails?.message ?? error.errorCode.message,
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: EdgeInsets.all(
                ResponsiveLayout.isTablet(context) ? 20 : 12,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(150),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '请将书本背面的 ISBN 条形码放入取景框内',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveLayout.isTablet(context) ? 18 : 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
