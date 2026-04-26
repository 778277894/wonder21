import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SafeNetImage extends StatefulWidget {
  final String url; // رابط الصورة النهائي (كامل)
  final BoxFit fit;
  final double? width, height;
  final BorderRadius? borderRadius;

  const SafeNetImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<SafeNetImage> createState() => _SafeNetImageState();
}

class _SafeNetImageState extends State<SafeNetImage> {
  bool _checking = true;
  bool _ok = true;
  int _rev = 0;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    setState(() => _checking = true);
    try {
      final resp = await http
          .head(Uri.parse(widget.url))
          .timeout(const Duration(seconds: 3));
      _ok = (resp.statusCode >= 200 && resp.statusCode < 400) ||
          resp.statusCode == 403;
    } catch (_) {
      _ok = false;
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.borderRadius ?? BorderRadius.zero;

    if (_checking) {
      return _frame(
          r, const Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }

    if (!_ok) {
      return _frame(
        r,
        _ErrorBox(
          icon: Icons.cloud_off,
          title: "السيرفر غير متاح",
          onRetry: () {
            _probe();
          },
        ),
      );
    }

    final src = "${widget.url}?v=$_rev"; // كسر الكاش عند إعادة المحاولة
    return ClipRRect(
      borderRadius: r,
      child: Image.network(
        src,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        errorBuilder: (_, __, ___) => _ErrorBox(
          icon: Icons.broken_image,
          title: "تعذّر تحميل الصورة",
          onRetry: () => setState(() => _rev++),
        ),
      ),
    );
  }

  Widget _frame(BorderRadius r, Widget child) {
    return ClipRRect(
      borderRadius: r,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onRetry;
  const _ErrorBox(
      {required this.icon, required this.title, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 36, color: Colors.grey),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text("إعادة المحاولة"),
        ),
      ]),
    );
  }
}
