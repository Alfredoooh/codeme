import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import 'settings_widgets.dart';

class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  const WebViewScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with ThemeReactive<WebViewScreen> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _hasError = false;
  String? _errorMessage;
  bool _canGoBack = false;

  static final _settings = InAppWebViewSettings(
    javaScriptEnabled: true,
    useOnDownloadStart: true,
    supportZoom: true,
    disableHorizontalScroll: false,
    disableVerticalScroll: false,
    transparentBackground: true,
  );
  
  Future<void> _reload() async {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _progress = 0;
    });
    await _controller?.reload();
  }

  Future<bool> _handleBack() async {
    if (_controller != null && _canGoBack) {
      await _controller!.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);

    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBack();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: s.pageBackground,
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Row(
                    children: [
                      CircularBackButton(
                        s: s,
                        onTap: () async {
                          final shouldPop = await _handleBack();
                          if (shouldPop && mounted) Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: s.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: _reload,
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: s.cardBackground,
                            shape: BoxShape.circle,
                            boxShadow: s.cardShadow,
                          ),
                          child: AppIcon('refresh',
                              size: 16, color: s.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_progress > 0 && _progress < 1)
                  LinearProgressIndicator(
                    value: _progress,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(s.primary),
                  ),

                Expanded(
                  child: _hasError
                      ? _WebViewErrorState(
                          s: s,
                          message: _errorMessage ??
                              'Não foi possível carregar a página.',
                          onRetry: _reload,
                        )
                      : InAppWebView(
                          initialUrlRequest:
                              URLRequest(url: WebUri(widget.url)),
                          initialSettings: _settings,
                          onWebViewCreated: (controller) {
                            _controller = controller;
                          },
                          onProgressChanged: (controller, progress) {
                            setState(() => _progress = progress / 100);
                          },
                          onUpdateVisitedHistory:
                              (controller, url, isReload) async {
                            final canGoBack =
                                await controller.canGoBack();
                            if (mounted) {
                              setState(() => _canGoBack = canGoBack);
                            }
                          },
                          onReceivedError: (controller, request, error) {
                            if (!request.isForMainFrame!) return;
                            setState(() {
                              _hasError = true;
                              _errorMessage = error.description;
                              _progress = 0;
                            });
                          },
                          onReceivedHttpError:
                              (controller, request, response) {
                            if (!request.isForMainFrame!) return;
                            if ((response.statusCode ?? 0) >= 400) {
                              setState(() {
                                _hasError = true;
                                _errorMessage =
                                    'Erro HTTP ${response.statusCode}';
                                _progress = 0;
                              });
                            }
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebViewErrorState extends StatelessWidget {
  final AppColorScheme s;
  final String message;
  final VoidCallback onRetry;
  const _WebViewErrorState({
    required this.s,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon('warning', size: 40, color: s.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: s.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: s.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Tentar novamente',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: s.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}