import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/services/book_api_service.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';

/// 扫码书库无记录时，手动填写书名、作者等后进入确认页
class ManualBookEntryScreen extends StatefulWidget {
  const ManualBookEntryScreen({super.key, this.initialIsbn});

  /// 已扫到 ISBN 但未命中书库时带入
  final String? initialIsbn;

  @override
  State<ManualBookEntryScreen> createState() => _ManualBookEntryScreenState();
}

class _ManualBookEntryScreenState extends State<ManualBookEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _isbnCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _api = BookApiService();

  @override
  void initState() {
    super.initState();
    if (widget.initialIsbn != null && widget.initialIsbn!.isNotEmpty) {
      _isbnCtrl.text = widget.initialIsbn!;
    }
    // 去掉扫码页残留的「去输入」SnackBar，避免挡表单、误点再次入栈
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });
  }

  @override
  void dispose() {
    _isbnCtrl.dispose();
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  String _resolveIsbn(String raw) {
    final t = raw.trim();
    final n = _api.normalizeIsbn(t);
    if (n != null) return n;
    if (t.isEmpty) {
      return 'manual-${DateTime.now().millisecondsSinceEpoch}';
    }
    return t;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final isbn = _resolveIsbn(_isbnCtrl.text);
    final book = BookLookupResult(
      isbn: isbn,
      title: _titleCtrl.text.trim(),
      author: _authorCtrl.text.trim(),
      summary: Book.defaultSummary,
    );
    Navigator.pop(context, book);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('手动输入书籍'),
      ),
      body: SafeArea(
        child: ResponsiveLayout.constrainToMaxWidth(
          context,
          SingleChildScrollView(
            padding: ResponsiveLayout.padding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '书库未收录时可在此填写，保存后与其它书一样使用。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _isbnCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ISBN',
                      hintText: '已扫码会自动填入；没有可留空',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: '书名',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '请填写书名';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _authorCtrl,
                    decoration: const InputDecoration(
                      labelText: '作者',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '请填写作者';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('下一步：确认信息'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
