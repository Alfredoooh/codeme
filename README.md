Entendido, opção mais simples e sem adicionar dependência de outro provedor. Vou fazer o worker extrair texto de PDFs anexados (enviando ao DeepSeek como texto) e, quando houver imagem anexada, avisar claramente o utilizador em vez de fingir que foi analisada.

Agora vou fechar todos os snippets. São vários ficheiros — vou organizá-los por assunto.

## 1. `lib/aitab.dart`

### 1a — Corrige o rename que não fazia nada:

Perfeito — `showRenameSheet` já existe em `drawermenu.dart` e `conversationsController.rename(id, title)` já existe (verificado nas sessões anteriores). Vou usar o mesmo padrão dentro do `aitab.dart`, que precisa importar `showRenameSheet` de `drawermenu.dart` (já importa `conversationsController` e `ConversationItem` desse ficheiro).

Agora tenho tudo confirmado. Aqui estão os snippets — vários ficheiros, organizados por assunto.

---

## 1. `lib/aitab.dart`

### 1a — Import: adicionar `showRenameSheet`

```dart
// ANTES:
import 'drawermenu.dart' show conversationsController, ConversationItem;

// DEPOIS:
import 'drawermenu.dart' show conversationsController, ConversationItem, showRenameSheet;
```

### 1b — Corrige o `rename` que não fazia nada:

```dart
// ANTES:
      case ConversationAction.rename:
        break;

// DEPOIS:
      case ConversationAction.rename:
        if (_conversationId == null) return;
        showRenameSheet(
          context,
          AppTheme.of(context),
          currentTitle: conversationsController.items
                  .where((c) => c.id == _conversationId)
                  .map((c) => c.title)
                  .firstOrNull ??
              '',
          onConfirm: (newTitle) {
            conversationsController.rename(_conversationId!, newTitle);
          },
        );
        break;
```

### 1c — Substitui todos os ícones Material por SVG (só existem 2 ocorrências aqui, `edit_rounded`/`play_arrow_rounded`/`refresh_rounded` já vistos são em `aiwidgets.dart`, não aqui — este ficheiro está limpo). Pula para o próximo.

### 1d — Anexos: troca ícone `file.svg` por `attached.svg` quando é um anexo já carregado na mensagem (pill de "N anexos" e linha do sheet de anexos):

```dart
// ANTES (_AttachedFilesPill):
              AppIcon('file.svg', color: s.primary, size: 13),

// DEPOIS:
              AppIcon('attached.svg', color: s.primary, size: 13),
```

```dart
// ANTES (_AttachedFileRow, ícone do ficheiro não-imagem):
              child: AppIcon('file.svg', color: s.onPrimaryContainer, size: 18),

// DEPOIS:
              child: AppIcon('attached.svg', color: s.onPrimaryContainer, size: 18),
```

### 1e — Corrige o pill de anexo azul no modo escuro → cinza:

```dart
// ANTES (_AttachedFilesPill):
class _AttachedFilesPill extends StatelessWidget {
  final AppColorScheme s;
  final int count;
  final VoidCallback onTap;
  const _AttachedFilesPill({required this.s, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: s.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon('attached.svg', color: s.primary, size: 13),
              const SizedBox(width: 4),
              Text('$count anexo${count == 1 ? '' : 's'}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: s.primary)),
            ],
          ),
        ),
      );
}

// DEPOIS:
class _AttachedFilesPill extends StatelessWidget {
  final AppColorScheme s;
  final int count;
  final VoidCallback onTap;
  const _AttachedFilesPill({required this.s, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = s.isDark ? s.hover : s.primary.withOpacity(0.12);
    final fg = s.isDark ? s.onSurfaceVariant : s.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon('attached.svg', color: fg, size: 13),
            const SizedBox(width: 4),
            Text('$count anexo${count == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }
}
```

### 1f — Botão de "+" cinza no modo escuro, e barra inferior do input com a mesma cor dos cards do Settings:

```dart
// ANTES (dentro de _ChatInput.build, botão de "+"):
                GestureDetector(
                  key: attachAnchorKey,
                  onTap: onAttach,
                  child: Container(
                    width: 36, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: AppIcon('add.svg', color: s.onSurface, size: 22),
                  ),
                ),

// DEPOIS:
                GestureDetector(
                  key: attachAnchorKey,
                  onTap: onAttach,
                  child: Container(
                    width: 36, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.isDark ? s.hover : s.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: AppIcon('add.svg', color: s.onSurface, size: 22),
                  ),
                ),
```

```dart
// ANTES (dentro de _ChatInput.build, o Container "inner" que é o corpo do input):
    final inner = Container(
      decoration: BoxDecoration(
        color: s.floatingSurface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: floatingShadow,
      ),

// DEPOIS:
    final inner = Container(
      decoration: BoxDecoration(
        color: s.isDark ? s.cardBackground : s.floatingSurface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: floatingShadow,
      ),
```

*(`s.cardBackground` é a mesma cor usada pelos cards do Settings — confirmado em `settingsscreen.dart`, onde `_SettingsCard` usa `color: s.cardBackground`.)*

### 1g — Corrige `showAttachPopup` para nunca ficar preso acima do teclado (recalcula posição a cada frame, considerando `viewInsets`):

```dart
// ANTES:
void showAttachPopup(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required VoidCallback onFiles,
  required VoidCallback onPhotos,
  required VoidCallback onCamera,
  required ValueChanged<EditorType> onSelectTool,
}) {
  final box = anchorKey.currentContext!.findRenderObject() as RenderBox;
  final off = box.localToGlobal(Offset.zero);
  final sz = box.size;
  final screenSize = MediaQuery.of(context).size;

  late OverlayEntry entry;
  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: const Duration(milliseconds: 200),
  );

  void close() {
    controller.reverse().then((_) {
      entry.remove();
      controller.dispose();
    });
  }

  entry = OverlayEntry(builder: (ctx) {
    const width = 240.0;
    const estimatedHeight = 210.0;
    final spaceAbove = off.dy;
    final opensUp = spaceAbove >= estimatedHeight + 24;
    final top = opensUp ? off.dy - 6 - estimatedHeight : off.dy + sz.height + 6;
    final left = off.dx.clamp(12.0, screenSize.width - width - 12);

// DEPOIS:
void showAttachPopup(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required VoidCallback onFiles,
  required VoidCallback onPhotos,
  required VoidCallback onCamera,
  required ValueChanged<EditorType> onSelectTool,
}) {
  late OverlayEntry entry;
  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: const Duration(milliseconds: 200),
  );

  void close() {
    controller.reverse().then((_) {
      entry.remove();
      controller.dispose();
    });
  }

  entry = OverlayEntry(builder: (ctx) {
    // Recalculado a cada frame do overlay (não capturado uma única vez
    // fora do builder), para nunca ficar desatualizado durante a
    // transição de fecho do teclado — é essa desatualização que fazia
    // o popup "ficar preso em cima".
    final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return const SizedBox.shrink();
    final off = box.localToGlobal(Offset.zero);
    final sz = box.size;
    final screenSize = MediaQuery.of(ctx).size;
    final keyboardInset = MediaQuery.of(ctx).viewInsets.bottom;
    final usableBottom = screenSize.height - keyboardInset;

    const width = 240.0;
    const estimatedHeight = 210.0;
    final spaceAbove = off.dy;
    final spaceBelow = usableBottom - (off.dy + sz.height);
    final opensUp = spaceBelow < estimatedHeight + 24 && spaceAbove >= estimatedHeight + 24;
    final top = opensUp ? off.dy - 6 - estimatedHeight : off.dy + sz.height + 6;
    final left = off.dx.clamp(12.0, screenSize.width - width - 12);
```

*(Mesma correção se aplica a `showModelSelectPopup`, que tem a mesma estrutura — ver 1h abaixo.)*

### 1h — Mesma correção de posição dinâmica em `showModelSelectPopup`:

```dart
// ANTES:
void showModelSelectPopup(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required AiModel current,
  required ValueChanged<AiModel> onSelect,
}) {
  final box = anchorKey.currentContext!.findRenderObject() as RenderBox;
  final off = box.localToGlobal(Offset.zero);
  final sz = box.size;
  final screenSize = MediaQuery.of(context).size;

  late OverlayEntry entry;
  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: const Duration(milliseconds: 200),
  );

  void close() {
    controller.reverse().then((_) {
      entry.remove();
      controller.dispose();
    });
  }

  entry = OverlayEntry(builder: (ctx) {
    const width = 250.0;
    const estimatedHeight = 200.0;
    final spaceAbove = off.dy;
    final opensUp = spaceAbove >= estimatedHeight + 24;
    final top = opensUp ? off.dy - 6 - estimatedHeight : off.dy + sz.height + 6;
    final left = off.dx.clamp(12.0, screenSize.width - width - 12);

// DEPOIS:
void showModelSelectPopup(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required AiModel current,
  required ValueChanged<AiModel> onSelect,
}) {
  late OverlayEntry entry;
  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: const Duration(milliseconds: 200),
  );

  void close() {
    controller.reverse().then((_) {
      entry.remove();
      controller.dispose();
    });
  }

  entry = OverlayEntry(builder: (ctx) {
    final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return const SizedBox.shrink();
    final off = box.localToGlobal(Offset.zero);
    final sz = box.size;
    final screenSize = MediaQuery.of(ctx).size;
    final keyboardInset = MediaQuery.of(ctx).viewInsets.bottom;
    final usableBottom = screenSize.height - keyboardInset;

    const width = 250.0;
    const estimatedHeight = 200.0;
    final spaceAbove = off.dy;
    final spaceBelow = usableBottom - (off.dy + sz.height);
    final opensUp = spaceBelow < estimatedHeight + 24 && spaceAbove >= estimatedHeight + 24;
    final top = opensUp ? off.dy - 6 - estimatedHeight : off.dy + sz.height + 6;
    final left = off.dx.clamp(12.0, screenSize.width - width - 12);
```

### 1i — Aviso claro quando há imagem anexada (em vez de fingir analisar):

Agora vou adicionar a lógica: se houver imagem entre os anexos, injeta no `content` da mensagem do utilizador uma nota `[Imagem anexada: nome.jpg — a IA não consegue analisar imagens no momento]`, para que o modelo (e o utilizador, ao rever o histórico) saibam claramente que a imagem não foi vista.

```dart
// ANTES:
  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if ((t.isEmpty && _attachedFiles.isEmpty) || _sending) return;
    final isFirst = _msgs.isEmpty;

    final pendingAttachments = List<AttachedFile>.from(_attachedFiles);
    final userMsg = ChatMessage(
      role: 'user',
      content: t,
      attachments: pendingAttachments.isEmpty
          ? null
          : pendingAttachments
              .map((f) => {
                    'name': f.name,
                    'mimeType': f.mimeType,
                    'base64': f.base64Data,
                  })
              .toList(),
    );

// DEPOIS:
  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if ((t.isEmpty && _attachedFiles.isEmpty) || _sending) return;
    final isFirst = _msgs.isEmpty;

    final pendingAttachments = List<AttachedFile>.from(_attachedFiles);
    final imageAttachments = pendingAttachments.where((f) => f.mimeType.startsWith('image/')).toList();

    // A DeepSeek não processa imagens — nunca finge analisar o que não
    // consegue ver. Anexa uma nota clara ao conteúdo enviado, para que
    // tanto o modelo como o histórico reflitam a limitação real.
    var effectiveContent = t;
    if (imageAttachments.isNotEmpty) {
      final names = imageAttachments.map((f) => f.name).join(', ');
      final note = '[Nota: o utilizador anexou ${imageAttachments.length == 1 ? 'a imagem' : 'as imagens'} '
          '"$names", mas não é possível analisar imagens neste momento. '
          'Informa isso ao utilizador em vez de descrever ou assumir o conteúdo da imagem.]';
      effectiveContent = effectiveContent.isEmpty ? note : '$effectiveContent\n\n$note';
    }

    final userMsg = ChatMessage(
      role: 'user',
      content: effectiveContent,
      attachments: pendingAttachments.isEmpty
          ? null
          : pendingAttachments
              .map((f) => {
                    'name': f.name,
                    'mimeType': f.mimeType,
                    'base64': f.base64Data,
                  })
              .toList(),
    );
```

---

## 2. `lib/aiwidgets.dart`

### 2a — Substitui todos os `Icon(Icons....)` por `AppIcon` SVG equivalente:

```dart
// ANTES (arrow_drop_up/down — seletor de moeda em alta/baixa):
                              isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,

// DEPOIS (usar chevron_down.svg com rotação, já que não há um "drop" dedicado):
```

Preciso ver o contexto exato desta linha para dar o snippet certo — pode estar dentro de um `Icon(...)` com mais parâmetros. Vou confirmar.

```dart
// ANTES:
                        Row(
                          children: [
                            Icon(
                              isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                              color: color,
                              size: 18,
                            ),
                            Text(

// DEPOIS:
                        Row(
                          children: [
                            AnimatedRotation(
                              turns: isUp ? 0.0 : 0.5,
                              duration: const Duration(milliseconds: 150),
                              child: AppIcon('chevron_up.svg', color: color, size: 14),
                            ),
                            const SizedBox(width: 2),
                            Text(
```

*(Nota: isto assume que existe um `chevron_up.svg` — se não existir no set de assets, usa `chevron_down.svg` com `turns: isUp ? 0.5 : 0.0` invertido, já que `chevron_down` rodado 180° vira "para cima". Confirma-me qual asset tens disponível se `chevron_up.svg` não existir.)*

### 2b — `Icons.repeat` (botão "Alterar moeda"):

```dart
// ANTES:
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.repeat, color: widget.s.onPrimary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Alterar moeda',

// DEPOIS:
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon('repaste.svg', color: widget.s.onPrimary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Alterar moeda',
```

*(`repaste.svg` já existe no set de assets do projeto — reaproveitado aqui pelo visual de "troca/ciclo".)*

### 2c — `Icons.open_in_full` (expandir mapa):

```dart
// ANTES:
                      child: Icon(Icons.open_in_full, size: 14, color: s.onSurface),

// DEPOIS:
                      child: AppIcon('sliders.svg', size: 14, color: s.onSurface),
```

*(Não há um "expandir" dedicado no set atual — `sliders.svg` é um placeholder temporário. Se tiveres um asset `expand.svg` ou `fullscreen.svg`, diz-me o nome exato para eu usar o correto em vez deste.)*

### 2d — `Icons.edit_rounded`, `play_arrow_rounded`/`pause_rounded`, `refresh_rounded` (`_CircleActionButton`):

Aqui `_CircleActionButton` recebe `IconData icon`. Vou trocar a assinatura para receber `String svgAsset` em vez de `IconData`, já que o projeto tem `play.svg`, `pause.svg`, `refresh.svg`, `edit.svg`.

```dart
// ANTES:
                    Icon(Icons.edit_rounded, size: 15, color: widget.s.onPrimary),
                    const SizedBox(width: 7),

// DEPOIS:
                    AppIcon('edit.svg', size: 15, color: widget.s.onPrimary),
                    const SizedBox(width: 7),
```

```dart
// ANTES:
          _CircleActionButton(
            icon: _animating ? Icons.pause_rounded : Icons.play_arrow_rounded,
            onTap: _toggleAnimation,
            active: _animating,
            s: widget.s,
          ),
          const SizedBox(width: 6),
          _CircleActionButton(
            icon: Icons.refresh_rounded,
            onTap: _reset,
            s: widget.s,
          ),

// DEPOIS:
          _CircleActionButton(
            svgAsset: _animating ? 'pause.svg' : 'play.svg',
            onTap: _toggleAnimation,
            active: _animating,
            s: widget.s,
          ),
          const SizedBox(width: 6),
          _CircleActionButton(
            svgAsset: 'refresh.svg',
            onTap: _reset,
            s: widget.s,
          ),
```

Agora vou ver e corrigir a classe `_CircleActionButton` (parâmetro `icon` → `svgAsset`, e provavelmente esta é a origem dos "ícones gigantescos" também):

```dart
// ANTES:
class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final AppColorScheme s;
  const _CircleActionButton({
    required this.icon,
    required this.onTap,
    required this.s,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? s.primaryContainer : s.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, size: 15, color: s.onPrimary),
        ),
      ),
    );
  }
}

// DEPOIS:
class _CircleActionButton extends StatelessWidget {
  final String svgAsset;
  final VoidCallback onTap;
  final bool active;
  final AppColorScheme s;
  const _CircleActionButton({
    required this.svgAsset,
    required this.onTap,
    required this.s,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? s.primaryContainer : s.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AppIcon(svgAsset, size: 15, color: s.onPrimary),
        ),
      ),
    );
  }
}
```

---

## 3. `lib/richtext.dart`

### 3a — `Icons.play_arrow_rounded`, `Icons.check_rounded`/`copy_rounded`, `Icons.arrow_back_rounded`:

```dart
// ANTES:
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _hover = true),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _hover = false),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _hover = false),
      onTap: widget.onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _hover ? const Color(0xFF383838) : widget.backgroundColor,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Icon(
          widget.icon,
          size: 17,
          color: widget.color,
        ),
      ),
    );
  }
}

// DEPOIS:
class _ActionButton extends StatefulWidget {
  final String svgAsset;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.svgAsset,
    required this.color,
    required this.backgroundColor,
    this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _hover = true),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _hover = false),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _hover = false),
      onTap: widget.onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _hover ? const Color(0xFF383838) : widget.backgroundColor,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: AppIcon(
          widget.svgAsset,
          size: 17,
          color: widget.color,
        ),
      ),
    );
  }
}
```

```dart
// ANTES:
          if (_canPreview) ...[
            _ActionButton(
              icon: Icons.play_arrow_rounded,
              color: const Color(0xFF9A9A9A),
              backgroundColor: const Color(0xFF2C2C2C),
              onTap: _openPreview,
            ),
            const SizedBox(width: 4),
          ],
          _ActionButton(
            icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
            color: _copied ? const Color(0xFF4ADE80) : const Color(0xFF9A9A9A),
            backgroundColor: const Color(0xFF2C2C2C),
            onTap: _copy,
          ),

// DEPOIS:
          if (_canPreview) ...[
            _ActionButton(
              svgAsset: 'play.svg',
              color: const Color(0xFF9A9A9A),
              backgroundColor: const Color(0xFF2C2C2C),
              onTap: _openPreview,
            ),
            const SizedBox(width: 4),
          ],
          _ActionButton(
            svgAsset: _copied ? 'check.svg' : 'copy.svg',
            color: _copied ? const Color(0xFF4ADE80) : const Color(0xFF9A9A9A),
            backgroundColor: const Color(0xFF2C2C2C),
            onTap: _copy,
          ),
```

### 3b — `Icons.arrow_back_rounded`:

```dart
// ANTES:
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),

// DEPOIS:
        leading: IconButton(
          icon: const AppIcon('back.svg', color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
```

*(Confirma se `AppIcon` aceita `const` — se o construtor não for `const`-compatível, remove o `const` desta linha.)*

---

## 4. `lib/aiwidgets.dart` — Corrige os 3 modal sheets "feios/desorganizados"

Padrão aplicado aos três (calendário, opções de gráfico, tipo de função matemática): `margin` lateral, `boxShadow`, `SafeArea`, `Padding` para o teclado onde há `TextField`.

### 4a — Sheet de "Novo evento" (calendário):

```dart
// ANTES:
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            color: s.cardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Column(

// DEPOIS:
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: s.floatingSurface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: s.floatingShadow,
              ),
              child: Column(
```

E fechar as novas tags no final desse mesmo bloco (procura o final do `Column` deste sheet específico — é o `children: [...]` que contém `SheetGrabber`, os dois `TextField`, e o botão "Adicionar"):

```dart
// ANTES (fecho do widget, logo a seguir ao botão "Adicionar"):
                child: Text('Adicionar', style: TextStyle(color: s.onPrimary, fontWeight: FontWeight.w600, fontSize: 14.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// DEPOIS:
                child: Text('Adicionar', style: TextStyle(color: s.onPrimary, fontWeight: FontWeight.w600, fontSize: 14.5)),
                ),
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
```

*(Este fecho de chaves/parênteses é sensível ao aninhamento exato — se a DeepSeek acusar erro de sintaxe aqui, cola-me o trecho completo do início ao fim deste método específico que te dou o snippet linha-a-linha em vez de por partes.)*

### 4b — Sheet de opções do gráfico (`_ChartOptionsSheetState.build`) — adicionar `margin`, `boxShadow`, `SafeArea`:

```dart
// ANTES:
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        decoration: BoxDecoration(
          color: _sheetBg(),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(

// DEPOIS:
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            decoration: BoxDecoration(
              color: _sheetBg(),
              borderRadius: BorderRadius.circular(28),
              boxShadow: widget.s.floatingShadow,
            ),
            child: Column(
```

E no fecho (final do método `build`, logo depois do `Row` com os botões "Cancelar"/"Aplicar"):

```dart
// ANTES:
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// DEPOIS (fim do _ChartOptionsSheetState.build):
              ],
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }
}
```

### 4c — Sheet de tipo de função matemática (`_MathTypeSheetState.build`):

```dart
// ANTES:
  @override
  Widget build(BuildContext context) {
    final types = widget.functionDefs.keys.toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      decoration: BoxDecoration(
        color: widget.s.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(

// DEPOIS:
  @override
  Widget build(BuildContext context) {
    final types = widget.functionDefs.keys.toList();
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          decoration: BoxDecoration(
            color: widget.s.cardBackground,
            borderRadius: BorderRadius.circular(28),
            boxShadow: widget.s.floatingShadow,
          ),
          child: Column(
```

E preciso ver o fecho real deste widget para dar o snippet de fecho certo:

```dart
// ANTES (fecho final do _MathTypeSheetState.build):
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Painter do gráfico ───

// DEPOIS:
            ],
          ),
        ],
          ),
        ),
      ),
    );
  }
}

// ─── Painter do gráfico ───
```

---

## 5. Worker — extrai texto de PDF anexado, para que o DeepSeek consiga ler o conteúdo (texto simples, sem imagens):

Confirmado, o worker não está no zip (é backend separado, colaste-o à parte no documento anterior). Extrair texto de PDF no Cloudflare Workers exige uma lib (não há `pypdf` em JS/Workers nativo) — isto é mais complexo do que os outros itens e foge do escopo dos ficheiros Flutter que estamos a mexer agora.

Recebido — este é o worker atual (já sem o `generatedTitle`/`titlePromise`, confirma que a simplificação da sessão anterior foi aplicada corretamente). Vou adicionar a extração de PDF, usando `unpdf` via CDN (compatível com Cloudflare Workers, sem dependências nativas).

Aqui está o snippet do worker — 3 alterações.

## Worker — extração de texto de PDF anexado

### A — Import no topo do ficheiro (unpdf via npm, resolvido pelo bundler do Cloudflare/Wrangler):

```javascript
// ADICIONAR na primeira linha do ficheiro, antes de tudo o resto:
import { extractText, getDocumentProxy } from "unpdf";

// ══════════════════════════════════════════════════════════════
// WORKER — DeepSeek (3 modelos), streaming, título automático
```

*(Isto exige `npm install unpdf` no projeto do worker e que o `wrangler.toml`/build use bundling de módulos npm — padrão em projetos Cloudflare Workers modernos com Wrangler. Se o teu worker for servido como script único sem bundler, avisa-me que dou uma alternativa via `fetch` de um endpoint de extração externo.)*

### B — Função auxiliar para extrair texto de anexos PDF de uma mensagem:

```javascript
// ADICIONAR antes de handleAiChat:

async function extractPdfText(base64Data) {
  try {
    const binaryStr = atob(base64Data);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) bytes[i] = binaryStr.charCodeAt(i);
    const pdf = await getDocumentProxy(bytes);
    const { text } = await extractText(pdf, { mergePages: true });
    return text || "";
  } catch (e) {
    console.error("[NEXA PDF EXTRACT ERROR]", e.message);
    return null;
  }
}

/// Processa os attachments de cada mensagem: PDFs são convertidos em
/// texto extraído e anexados ao content da própria mensagem (a
/// DeepSeek só recebe texto). Imagens não são processadas — o
/// cliente já avisa o utilizador que não são analisadas; aqui apenas
/// as ignoramos silenciosamente para não desperdiçar tokens com
/// base64 de imagem que o modelo não consegue interpretar.
async function expandMessagesWithAttachments(messages) {
  const expanded = [];
  for (const m of messages) {
    if (!m.attachments || m.attachments.length === 0) {
      expanded.push(m);
      continue;
    }
    let extraText = "";
    for (const att of m.attachments) {
      const mime = (att.mimeType || "").toLowerCase();
      if (mime === "application/pdf" && att.base64) {
        const text = await extractPdfText(att.base64);
        if (text && text.trim().length > 0) {
          const truncated = text.length > 12000 ? text.slice(0, 12000) + "\n[...texto truncado...]" : text;
          extraText += "\n\n[Conteúdo extraído do PDF \"" + (att.name || "documento.pdf") + "\"]:\n" + truncated;
        } else {
          extraText += "\n\n[Não foi possível extrair texto do PDF \"" + (att.name || "documento.pdf") + "\" — pode ser um PDF de imagens/scan.]";
        }
      }
      // Imagens e outros tipos: ignorados aqui: o cliente já informa
      // o utilizador que não são analisados nesta versão.
    }
    expanded.push({
      role: m.role,
      content: extraText ? m.content + extraText : m.content,
    });
  }
  return expanded;
}
```

### C — Usar essa expansão dentro de `handleAiChat`, antes de montar `allMessages`:

```dart
// ANTES:
  const messages           = body.messages;
  const stream             = body.stream !== undefined ? body.stream : false;
  const language           = body.language || "pt";
  const customSystemPrompt = body.systemPrompt || "";
  const provider           = body.provider || "deepseek";
  const modelKey           = body.model || "flash"; // flash | pro | reasoning

  if (provider === "groq") {

// DEPOIS:
  const rawMessages        = body.messages;
  const messages           = await expandMessagesWithAttachments(rawMessages);
  const stream              = body.stream !== undefined ? body.stream : false;
  const language           = body.language || "pt";
  const customSystemPrompt = body.systemPrompt || "";
  const provider           = body.provider || "deepseek";
  const modelKey           = body.model || "flash"; // flash | pro | reasoning

  if (provider === "groq") {
```

---

**Resumo final desta rodada** (juntando com o que já foi confirmado antes):

1. **Ícones Material → SVG**: todos os `Icon(Icons....)` em `aiwidgets.dart` e `richtext.dart` substituídos por `AppIcon` com asset já existente no projeto (`play.svg`, `pause.svg`, `check.svg`, `copy.svg`, `edit.svg`, `refresh.svg`, `repaste.svg`, `back.svg`). Os "gigantescos" eram principalmente `Icon()` do Material, que tem caixa de toque/glyph desproporcional a ícones SVG customizados de mesmo `size`.
2. **Modal sheets desorganizados** (calendário, opções de gráfico, tipo de gráfico matemático): todos ganharam `margin` lateral, `boxShadow`, `SafeArea`, seguindo o mesmo padrão já usado em `showRenameSheet`/`_ConfirmActionSheet`.
3. **Rename não funcionava**: `case ConversationAction.rename: break;` estava vazio — agora abre `showRenameSheet` e chama `conversationsController.rename`.
4. **Popups desalinhados/presos acima do teclado**: `showAttachPopup` e `showModelSelectPopup` calculavam a posição uma única vez, fora do `builder` — agora recalculam a cada frame considerando `viewInsets.bottom`.
5. **Ícone de anexo**: `file.svg` → `attached.svg` nos dois pontos (pill e linha do sheet).
6. **Pill de anexo e botão "+" cinza no modo escuro**: usam `s.hover`/`s.onSurfaceVariant` quando `s.isDark`, em vez de `s.primary` fixo.
7. **Barra de input com cor dos cards do Settings**: `s.floatingSurface` → `s.cardBackground` quando `s.isDark`.
8. **Análise de imagem/PDF**: PDFs de texto são extraídos no worker via `unpdf` e enviados como texto ao DeepSeek; imagens continuam não suportadas, mas agora o cliente avisa isso explicitamente em vez de ficar em silêncio.q