import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const CodeMeApp());
}

// ── Theme Notifier ────────────────────────────────────────────────────────────

class AppThemeNotifier extends ChangeNotifier {
  Color primaryColor = Colors.black;
  Color backgroundColor = Colors.white;
  bool isDark = false;

  void applyTheme({Color? primary, Color? background, bool? dark}) {
    if (primary != null) primaryColor = primary;
    if (background != null) backgroundColor = background;
    if (dark != null) isDark = dark;
    notifyListeners();
  }
}

final AppThemeNotifier appTheme = AppThemeNotifier();

Color _hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

// ── App Root ──────────────────────────────────────────────────────────────────

class CodeMeApp extends StatefulWidget {
  const CodeMeApp({super.key});
  @override
  State<CodeMeApp> createState() => _CodeMeAppState();
}

class _CodeMeAppState extends State<CodeMeApp> {
  @override
  void initState() {
    super.initState();
    appTheme.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final iconBrightness = appTheme.isDark ? Brightness.light : Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: appTheme.backgroundColor,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: appTheme.isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: appTheme.backgroundColor,
      systemNavigationBarIconBrightness: iconBrightness,
    ));

    return ListenableBuilder(
      listenable: appTheme,
      builder: (context, _) => MaterialApp(
        title: 'CodeMe',
        debugShowCheckedModeBanner: false,
        themeMode: appTheme.isDark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: appTheme.primaryColor,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: appTheme.backgroundColor,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: appTheme.primaryColor,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: appTheme.backgroundColor,
        ),
        home: const WebViewPage(),
      ),
    );
  }
}

// ── WebView Page ──────────────────────────────────────────────────────────────

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});
  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isConnected = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  final String _url = 'https://codeme-x1p1.onrender.com/';

  final InAppWebViewSettings _settings = InAppWebViewSettings(
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    cacheEnabled: true,
    cacheMode: CacheMode.LOAD_DEFAULT,
    domStorageEnabled: true,
    databaseEnabled: true,
    applicationNameForUserAgent: 'CodeMeApp/1.0',
    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
    allowFileAccess: true,
    allowContentAccess: true,
    allowFileAccessFromFileURLs: true,
    allowUniversalAccessFromFileURLs: true,
    useWideViewPort: true,
    loadWithOverviewMode: true,
    supportZoom: false,
    builtInZoomControls: false,
    displayZoomControls: false,
    horizontalScrollBarEnabled: false,
    verticalScrollBarEnabled: false,
    overScrollMode: OverScrollMode.NEVER,
    geolocationEnabled: true,
    transparentBackground: false,
    userAgent:
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 CodeMeApp/1.0',
  );

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      if (mounted) {
        setState(() => _isConnected = connected);
        if (connected && _hasError) _reload();
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(
          () => _isConnected = results.any((r) => r != ConnectivityResult.none));
    }
  }

  void _reload() {
    _webViewController?.reload();
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
  }

  void _registerHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'flutterAlert',
      callback: (args) {
        final title = args.isNotEmpty ? args[0].toString() : '';
        final message = args.length > 1 ? args[1].toString() : '';
        _showAlert(title, message);
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'flutterConfirm',
      callback: (args) async {
        final title = args.isNotEmpty ? args[0].toString() : '';
        final message = args.length > 1 ? args[1].toString() : '';
        return await _showConfirm(title, message);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'flutterModal',
      callback: (args) async {
        final title = args.isNotEmpty ? args[0].toString() : '';
        final body = args.length > 1 ? args[1].toString() : '';
        final List<dynamic> actions =
            args.length > 2 ? (args[2] as List<dynamic>) : [];
        return await _showModal(title, body, actions);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'flutterToast',
      callback: (args) {
        final message = args.isNotEmpty ? args[0].toString() : '';
        final duration =
            args.length > 1 && args[1].toString() == 'long' ? 3500 : 1800;
        _showToast(message, duration);
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'flutterSetTheme',
      callback: (args) {
        if (args.isEmpty) return null;
        final Map<String, dynamic> params =
            Map<String, dynamic>.from(args[0] as Map);
        appTheme.applyTheme(
          primary: params['primaryColor'] != null
              ? _hexToColor(params['primaryColor'].toString())
              : null,
          background: params['backgroundColor'] != null
              ? _hexToColor(params['backgroundColor'].toString())
              : null,
          dark: params['isDark'] as bool?,
        );
        return null;
      },
    );
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _NativeDialog(
        title: title,
        body: message,
        actions: [
          _DialogAction(
            label: 'OK',
            style: _ActionStyle.primary,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _NativeDialog(
        title: title,
        body: message,
        actions: [
          _DialogAction(
            label: 'Cancelar',
            style: _ActionStyle.ghost,
            onTap: () => Navigator.pop(context, false),
          ),
          _DialogAction(
            label: 'Confirmar',
            style: _ActionStyle.primary,
            onTap: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _showModal(
      String title, String body, List<dynamic> actions) async {
    final List<_DialogAction> dialogActions = actions.map((a) {
      final Map<String, dynamic> action = Map<String, dynamic>.from(a as Map);
      final label = action['label']?.toString() ?? '';
      final styleStr = action['style']?.toString() ?? 'primary';
      _ActionStyle style;
      if (styleStr == 'danger') {
        style = _ActionStyle.danger;
      } else if (styleStr == 'ghost') {
        style = _ActionStyle.ghost;
      } else {
        style = _ActionStyle.primary;
      }
      return _DialogAction(
        label: label,
        style: style,
        onTap: () => Navigator.pop(context, label),
      );
    }).toList();

    if (dialogActions.isEmpty) {
      dialogActions.add(_DialogAction(
        label: 'Fechar',
        style: _ActionStyle.ghost,
        onTap: () => Navigator.pop(context, null),
      ));
    }

    return showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) =>
          _NativeDialog(title: title, body: body, actions: dialogActions),
    );
  }

  OverlayEntry? _toastEntry;

  void _showToast(String message, int durationMs) {
    _toastEntry?.remove();
    _toastEntry = OverlayEntry(
      builder: (_) => _NativeToast(message: message),
    );
    Overlay.of(context).insert(_toastEntry!);
    Future.delayed(Duration(milliseconds: durationMs), () {
      _toastEntry?.remove();
      _toastEntry = null;
    });
  }

  Future<void> _injectBridge(InAppWebViewController controller) async {
    await controller.evaluateJavascript(source: r"""
      window.FlutterBridge = {
        alert: function(title, message) {
          window.flutter_inappwebview.callHandler('flutterAlert', title, message);
        },
        confirm: function(title, message) {
          return window.flutter_inappwebview.callHandler('flutterConfirm', title, message);
        },
        modal: function(title, body, actions) {
          return window.flutter_inappwebview.callHandler('flutterModal', title, body, actions || []);
        },
        toast: function(message, duration) {
          window.flutter_inappwebview.callHandler('flutterToast', message, duration || 'short');
        },
        setTheme: function(params) {
          window.flutter_inappwebview.callHandler('flutterSetTheme', params);
        }
      };
      window.dispatchEvent(new Event('FlutterBridgeReady'));
    """);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: appTheme.backgroundColor,
        statusBarIconBrightness:
            appTheme.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            appTheme.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: appTheme.backgroundColor,
        systemNavigationBarIconBrightness:
            appTheme.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: appTheme.backgroundColor,
        body: SafeArea(
          top: true,
          bottom: false,
          left: false,
          right: false,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_isConnected) return _buildNoConnectionScreen();
    return Stack(
      children: [
        if (!_hasError)
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_url)),
            initialSettings: _settings,
            onWebViewCreated: (controller) {
              _webViewController = controller;
              _registerHandlers(controller);
            },
            onLoadStart: (controller, url) {
              if (mounted) setState(() => _isLoading = true);
            },
            onLoadStop: (controller, url) async {
              if (mounted) setState(() => _isLoading = false);
              await _injectBridge(controller);
            },
            onReceivedError: (controller, request, error) {
              if (mounted) setState(() {
                _isLoading = false;
                _hasError = true;
              });
            },
            onPermissionRequest: (controller, request) async =>
                PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.GRANT,
            ),
            onGeolocationPermissionsShowPrompt: (controller, origin) async =>
                GeolocationPermissionShowPromptResponse(
              origin: origin,
              allow: true,
              retain: true,
            ),
            shouldOverrideUrlLoading: (controller, navigationAction) async =>
                NavigationActionPolicy.ALLOW,
          ),
        if (_hasError) _buildErrorScreen(),
        if (_isLoading && !_hasError)
          Container(
            color: appTheme.backgroundColor,
            child: Center(
              child: CircularProgressIndicator(
                color: appTheme.primaryColor,
                strokeWidth: 2,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorScreen() {
    return Container(
      color: appTheme.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 64, color: appTheme.primaryColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('Erro ao carregar a página',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: appTheme.isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 8),
            Text('Verifique sua conexão e tente novamente.',
                style: TextStyle(
                    fontSize: 14,
                    color: appTheme.isDark ? Colors.white54 : Colors.black54),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _reload,
              style: ElevatedButton.styleFrom(
                backgroundColor: appTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoConnectionScreen() {
    return Container(
      color: appTheme.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.signal_wifi_off_rounded,
                size: 64, color: appTheme.primaryColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('Sem conexão à internet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: appTheme.isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 8),
            Text('Conecte-se à internet para usar o app.',
                style: TextStyle(
                    fontSize: 14,
                    color: appTheme.isDark ? Colors.white54 : Colors.black54),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Enums & Models ────────────────────────────────────────────────────────────

enum _ActionStyle { primary, danger, ghost }

class _DialogAction {
  final String label;
  final _ActionStyle style;
  final VoidCallback onTap;
  const _DialogAction(
      {required this.label, required this.style, required this.onTap});
}

// ── _NativeDialog ─────────────────────────────────────────────────────────────

class _NativeDialog extends StatelessWidget {
  final String title;
  final String body;
  final List<_DialogAction> actions;

  const _NativeDialog(
      {required this.title, required this.body, required this.actions});

  @override
  Widget build(BuildContext context) {
    final bg = appTheme.isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = appTheme.isDark ? Colors.white : Colors.black;
    final subColor = appTheme.isDark ? Colors.white60 : Colors.black54;
    final divider = appTheme.isDark ? Colors.white12 : Colors.black12;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor),
                      textAlign: TextAlign.center),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(body,
                        style:
                            TextStyle(fontSize: 14, color: subColor, height: 1.5),
                        textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(height: 0.5, color: divider),
            Row(
              children: List.generate(actions.length, (i) {
                final action = actions[i];
                final isLast = i == actions.length - 1;
                Color labelColor;
                switch (action.style) {
                  case _ActionStyle.primary:
                    labelColor = appTheme.primaryColor == Colors.black
                        ? (appTheme.isDark ? Colors.white : Colors.black)
                        : appTheme.primaryColor;
                    break;
                  case _ActionStyle.danger:
                    labelColor = Colors.red;
                    break;
                  case _ActionStyle.ghost:
                    labelColor = subColor;
                    break;
                }
                return Expanded(
                  child: GestureDetector(
                    onTap: action.onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : Border(
                                right:
                                    BorderSide(width: 0.5, color: divider)),
                      ),
                      child: Text(action.label,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  action.style == _ActionStyle.primary
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                              color: labelColor),
                          textAlign: TextAlign.center),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _NativeToast ──────────────────────────────────────────────────────────────

class _NativeToast extends StatefulWidget {
  final String message;
  const _NativeToast({required this.message});

  @override
  State<_NativeToast> createState() => _NativeToastState();
}

class _NativeToastState extends State<_NativeToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 64,
      left: 32,
      right: 32,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: appTheme.isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                widget.message,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.3),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
