import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

void main() {
  runApp(const NexaApp());
}

class NexaApp extends StatelessWidget {
  const NexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.black,
        fontFamily: 'Inter',
      ),
      // Garante CupertinoPageRoute em todas as plataformas ao usar Navigator.push manual,
      // mas desativamos os gestos de swipe-to-back sobrescrevendo a rota abaixo.
      home: const HomeScreen(),
    );
  }
}

/// PageRoute customizada baseada em CupertinoPageRoute, mas com
/// gesto de "arrastar para voltar" desativado — só volta por botão.
class NoSwipeCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  NoSwipeCupertinoPageRoute({
    required super.builder,
    super.settings,
    super.fullscreenDialog,
  });

  @override
  bool get popGestureEnabled => false;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      NoSwipeCupertinoPageRoute(
        builder: (context) => const DetailScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nexa'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _openDetail(context),
          child: const Text('Ir para Detalhes'),
        ),
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes'),
        // O botão de voltar padrão do AppBar já chama Navigator.pop()
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Voltar'),
        ),
      ),
    );
  }
}