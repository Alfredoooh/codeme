Nota de honestidade importante: o novo _ProcessPill usa AppIcon('chevron_down.svg', ...). Não confirmei que este asset existe na tua pasta svg — o código usa chevron_right.svg noutros pontos (ex. _CanvasCard), mas nunca vi chevron_down.svg referenciado em nenhuma parte do ficheiro original. Se não existir, o AppIcon provavelmente vai falhar a carregar o SVG em runtime (dependendo de como AppIcon trata assets em falta). Se não tiveres esse ícone, diz-me o nome real do que tens (ou se preferes que eu troque para uma rotação de chevron_right.svg) que eu corrijo.
Também assumi que existe uma função findOpenWidgetBlock(text) em aiwidgets.dart que devolve algo com .startIndex e .rawContent — não tinha esse ficheiro no prompt, só vi parseAiWidgetBlocks e hasOpenWidgetBlock a serem chamados em richtext.dart/aitab.dart original. Se aiwidgets.dart não tiver essa função exatamente com esse shape, preciso de ver o ficheiro para ajustar _detectOpeningBlock corretamente


```html
<!DOCTYPE html>
<html lang="pt-PT">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Chat com Processos Dinâmicos</title>
<style>
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }

  body {
    background: #0e0e10;
    min-height: 100vh;
    display: flex;
    justify-content: center;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    padding: 24px;
  }

  .chat-wrap {
    width: 100%;
    max-width: 460px;
  }

  .block {
    margin-bottom: 4px;
  }

  /* -------- Texto de resposta (streaming) -------- */
  .answer-text {
    font-size: 15px;
    line-height: 1.65;
    color: #e4e4e8;
    white-space: pre-wrap;
    padding: 6px 0;
  }

  .cursor {
    display: inline-block;
    width: 2px;
    height: 14px;
    background: #e4e4e8;
    margin-left: 2px;
    vertical-align: middle;
    animation: blink 0.9s step-start infinite;
  }

  @keyframes blink {
    50% { opacity: 0; }
  }

  .cursor.hidden {
    display: none;
  }

  /* -------- Linha de processo (ícone + texto), ambos com shimmer enquanto ativo -------- */
  .process-row {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 0;
    user-select: none;
    cursor: pointer;
  }

  .process-icon {
    width: 18px;
    height: 18px;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .process-icon svg {
    width: 17px;
    height: 17px;
    display: block;
  }

  /* estado inativo (não streaming, não hover) */
  .process-icon svg path,
  .process-icon svg circle,
  .process-icon svg line,
  .process-icon svg polyline {
    stroke: #9a9aa4;
    fill: none;
  }

  .process-icon svg.filled path {
    fill: #9a9aa4;
    stroke: none;
  }

  .process-text {
    font-size: 14px;
    color: #9a9aa4;
  }

  /* Shimmer aplicado ao ícone E ao texto em simultâneo, mesma animação sincronizada */
  .process-row.active .process-text {
    background: linear-gradient(100deg, #55555f 30%, #f5f5fa 50%, #55555f 70%);
    background-size: 250% 100%;
    background-clip: text;
    -webkit-background-clip: text;
    color: transparent;
    -webkit-text-fill-color: transparent;
    animation: shimmerMove 1.8s ease-in-out infinite;
  }

  .process-row.active .process-icon svg path,
  .process-row.active .process-icon svg circle,
  .process-row.active .process-icon svg line,
  .process-row.active .process-icon svg polyline {
    stroke: url(#shimmerGradient);
  }

  .process-row.active .process-icon svg.filled path {
    fill: url(#shimmerGradient);
  }

  @keyframes shimmerMove {
    0% { background-position: 200% 0; }
    100% { background-position: -50% 0; }
  }

  .process-timer {
    font-size: 12px;
    color: #55555e;
    margin-left: 2px;
  }

  .process-chevron {
    width: 13px;
    height: 13px;
    margin-left: auto;
    flex-shrink: 0;
    transition: transform 0.25s ease;
  }

  .process-chevron path {
    stroke: #6b6b76;
  }

  .process-row.expanded .process-chevron {
    transform: rotate(180deg);
  }

  /* -------- Detalhe interno do processo (pode ser ocultado a qualquer momento) -------- */
  .process-detail {
    max-height: 3000px;
    overflow: hidden;
    transition: max-height 0.4s ease, opacity 0.3s ease, margin 0.3s ease;
    opacity: 1;
    padding-left: 26px;
    margin-top: 2px;
  }

  .process-detail.hidden {
    max-height: 0;
    opacity: 0;
    margin-top: 0;
  }

  .process-detail-text {
    font-size: 13px;
    color: #55555e;
    line-height: 1.55;
    white-space: pre-wrap;
  }

  .process-cursor {
    display: inline-block;
    width: 2px;
    height: 12px;
    background: #55555e;
    margin-left: 2px;
    vertical-align: middle;
    animation: blink 0.9s step-start infinite;
  }

  .process-cursor.hidden {
    display: none;
  }
</style>
</head>
<body>

<!-- Gradiente SVG global usado no stroke/fill animado dos ícones durante o shimmer -->
<svg width="0" height="0" style="position:absolute">
  <defs>
    <linearGradient id="shimmerGradient" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#55555f"/>
      <stop offset="50%" stop-color="#f5f5fa"/>
      <stop offset="100%" stop-color="#55555f"/>
      <animateTransform attributeName="gradientTransform" type="translate"
        from="-1 0" to="1 0" dur="1.8s" repeatCount="indefinite"/>
    </linearGradient>
  </defs>
</svg>

<div class="chat-wrap" id="chatWrap"></div>

<script>
(function () {
  var chatWrap = document.getElementById('chatWrap');

  // Ícone principal do produto (documento)
  var docIconSVG = '<svg class="filled" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M19,4h-1.101c-.465-2.279-2.485-4-4.899-4h-2c-2.414,0-4.435,1.721-4.899,4h-1.101C2.243,4,0,6.243,0,9v10c0,2.757,2.243,5,5,5h14c2.757,0,5-2.243,5-5V9c0-2.757-2.243-5-5-5ZM11,2h2c1.304,0,2.415,.836,2.828,2h-7.656c.413-1.164,1.524-2,2.828-2ZM5,6h14c1.654,0,3,1.346,3,3v1h-3v-1c0-.552-.447-1-1-1s-1,.448-1,1v1H7v-1c0-.552-.447-1-1-1s-1,.448-1,1v1H2v-1c0-1.654,1.346-3,3-3Zm14,16H5c-1.654,0-3-1.346-3-3v-7h3v1c0,.552,.447,1,1,1s1-.448,1-1v-1h10v1c0,.552,.447,1,1,1s1-.448,1-1v-1h3v7c0,1.654-1.346,3-3,3Z"/></svg>';

  // Ícone de edição (lápis) — SVG inline no estilo Lucide (stroke-based)
  var editIconSVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/><path d="m15 5 4 4"/></svg>';

  var chevronSVG = '<svg class="process-chevron" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>';

  var sequence = [
    {
      type: "answer",
      text: "Vou criar o material completo de fonética que pediste, com as 10 aulas organizadas por ordem progressiva de dificuldade. Vou incluir todas as combinações consoante+vogal como pr+a=pra, br+a=bra, bl+a=bla, cr+a=cra, fr+a=fra, gr+a=gra, tr+a=tra, dr+a=dra, e as famílias qua, que, qui, quo em todas as suas variações. Cada aula vai ter listas de sílabas, palavras completas, frases de exemplo, exercícios de leitura, ditados mistos e uma pequena avaliação prática no final para consolidar o que foi aprendido nessa sessão."
    },
    {
      type: "process",
      icon: docIconSVG,
      label: "A criar ficheiro",
      duration: 82000,
      detail: "A definir a estrutura geral do documento com cabeçalho, índice das 10 aulas e secção de instruções para o utilizador.\n\nA gerar a tabela completa de sílabas simples: pa, pe, pi, po, pu, ba, be, bi, bo, bu, ta, te, ti, to, tu, da, de, di, do, du, e assim sucessivamente para todas as consoantes do alfabeto português.\n\nA gerar a tabela de encontros consonantais válidos: pra, pre, pri, pro, pru, bra, bre, bri, bro, bru, tra, tre, tri, tro, tru, dra, dre, dri, dro, dru, cra, cre, cri, cro, cru, gra, gre, gri, gro, gru, fra, fre, fri, fro, fru, bla, ble, bli, blo, blu, cla, cle, cli, clo, clu, fla, fle, fli, flo, flu, gla, gle, gli, glo, glu, pla, ple, pli, plo, plu.\n\nA gerar a família qu: qua, que, qui, quo, e a validar que que e qui não levam til nem trema conforme o novo acordo ortográfico, garantindo que os exemplos estão corretos foneticamente.\n\nA distribuir o conteúdo pelas 10 aulas por ordem de dificuldade: aula 1 e 2 para sílabas simples, aula 3 e 4 para introdução aos encontros consonantais mais comuns como pr, br, tr, aula 5 e 6 para os restantes encontros consonantais, aula 7 e 8 para a família qu e outras irregularidades, aula 9 para revisão geral com todos os padrões misturados, e aula 10 para avaliação final.\n\nA adicionar exercícios práticos a cada aula: leitura em voz alta, ditado de palavras, formação de frases simples e um pequeno jogo de associação de sílabas.\n\nA rever a formatação para impressão em A4, com espaçamento adequado e tipo de letra legível para prática diária.\n\nA fazer uma última verificação cruzada entre todas as tabelas geradas e o conteúdo distribuído por aula, confirmando que nenhuma sílaba ou padrão ficou de fora e que a progressão de dificuldade está coerente do início ao fim do material."
    },
    {
      type: "answer",
      text: "Ficheiro criado com sucesso. Contém as 10 aulas completas, com todas as tabelas de sílabas simples e de encontros consonantais, a família qua, que, qui, quo devidamente incluída, exercícios práticos, ditados mistos e uma avaliação final. Está formatado em português europeu e pronto para imprimir e usar aula a aula."
    },
    {
      type: "process",
      icon: editIconSVG,
      label: "A editar ficheiro",
      duration: 80000,
      detail: "A rever o pedido de ajuste: adicionar mais exemplos práticos de palavras do dia a dia para cada padrão silábico, tornando o material mais aplicável à vida real.\n\nA percorrer aula por aula e a inserir pelo menos cinco palavras comuns adicionais por padrão, evitando repetições com as já existentes.\n\nA verificar consistência ortográfica em todas as novas palavras acrescentadas, confirmando que seguem o novo acordo ortográfico da língua portuguesa.\n\nA ajustar os ditados mistos de cada aula para incorporar as novas palavras nos exercícios, mantendo o nível de dificuldade coerente com a progressão das aulas anteriores.\n\nA rever a avaliação prática final para garantir que cobre proporcionalmente todos os padrões silábicos ensinados ao longo das 10 aulas, sem sobrecarregar nenhuma categoria específica.\n\nA validar novamente a paginação e o espaçamento do documento após as inserções de conteúdo, assegurando que continua adequado para impressão em A4.\n\nA confirmar que todas as referências cruzadas entre aulas continuam corretas depois das edições, e a fazer uma passagem final de leitura sobre o documento completo antes de o considerar concluído."
    },
    {
      type: "answer",
      text: "Pronto, o ficheiro foi atualizado com mais exemplos práticos de palavras do dia a dia em cada aula, os ditados mistos foram ajustados para incluir esse novo vocabulário e a avaliação final ficou equilibrada entre todos os padrões silábicos. O documento mantém a formatação adequada para impressão."
    }
  ];

  var index = 0;

  function nextStep() {
    if (index >= sequence.length) return;
    var step = sequence[index];
    index++;

    if (step.type === "answer") {
      renderAnswer(step.text, nextStep);
    } else {
      renderProcess(step, nextStep);
    }
  }

  function renderAnswer(text, done) {
    var el = document.createElement('div');
    el.className = 'block answer-text';
    el.innerHTML = '<span class="cursor"></span>';
    chatWrap.appendChild(el);

    var cursor = el.querySelector('.cursor');
    streamWords(text, function (current, finished) {
      el.innerHTML = current + ' ';
      el.appendChild(cursor);
      window.scrollTo(0, document.body.scrollHeight);
      if (finished) {
        setTimeout(function () {
          cursor.classList.add('hidden');
          done();
        }, 400);
      }
    }, 30);
  }

  function renderProcess(step, done) {
    var row = document.createElement('div');
    row.className = 'block process-row active expanded';
    row.innerHTML =
      '<div class="process-icon">' + step.icon + '</div>' +
      '<div class="process-text"></div>' +
      '<span class="process-timer">0s</span>' +
      chevronSVG;
    chatWrap.appendChild(row);

    var textEl = row.querySelector('.process-text');
    var timerEl = row.querySelector('.process-timer');
    textEl.textContent = step.label;

    var detail = document.createElement('div');
    detail.className = 'block process-detail';
    detail.innerHTML = '<div class="process-detail-text"><span class="process-cursor"></span></div>';
    chatWrap.appendChild(detail);

    var detailTextEl = detail.querySelector('.process-detail-text');
    var pCursor = detail.querySelector('.process-cursor');

    var startTime = Date.now();
    var running = true;
    var finished = false;

    // Cronómetro em tempo real, atualiza a cada segundo enquanto o processo corre
    var timerInterval = setInterval(function () {
      if (!running) return;
      var elapsed = Math.round((Date.now() - startTime) / 1000);
      timerEl.textContent = elapsed + "s";
    }, 250);

    // Clique na linha alterna aberto/fechado a qualquer momento, mesmo durante o streaming.
    // Isto NÃO pausa o streaming nem o cronómetro — só mostra/oculta o detalhe.
    row.addEventListener('click', function () {
      var isHidden = detail.classList.toggle('hidden');
      row.classList.toggle('expanded', !isHidden);
    });

    streamWordsForDuration(step.detail, step.duration, function (current, done2) {
      detailTextEl.innerHTML = current + ' ';
      detailTextEl.appendChild(pCursor);
      window.scrollTo(0, document.body.scrollHeight);
      if (done2) {
        finishStreaming();
      }
    });

    function finishStreaming() {
      if (finished) return;
      finished = true;
      pCursor.classList.add('hidden');
      running = false;
      clearInterval(timerInterval);

      var elapsedFinal = Math.max(1, Math.round((Date.now() - startTime) / 1000));
      timerEl.textContent = elapsedFinal + "s";

      setTimeout(function () {
        row.classList.remove('active');
        row.classList.remove('expanded');
        textEl.textContent = step.label.replace("A criar", "Criou").replace("A editar", "Editou") + " · " + elapsedFinal + "s";
        timerEl.style.display = 'none';
        detail.classList.add('hidden');
        done();
      }, 400);
    }
  }

  function streamWords(text, onUpdate, speed) {
    var words = text.split(' ');
    var i = 0;
    var current = '';

    function step() {
      if (i < words.length) {
        current += (i === 0 ? '' : ' ') + words[i];
        i++;
        onUpdate(current, false);
        setTimeout(step, speed);
      } else {
        onUpdate(current, true);
      }
    }
    step();
  }

  // Distribui as palavras ao longo de uma duração total alvo (ex: 80000ms),
  // para que o streaming do processo demore o tempo pedido mesmo com textos longos.
  function streamWordsForDuration(text, totalDuration, onUpdate) {
    var words = text.split(' ');
    var perWord = Math.max(20, totalDuration / words.length);
    var i = 0;
    var current = '';

    function step() {
      if (i < words.length) {
        current += (i === 0 ? '' : ' ') + words[i];
        i++;
        onUpdate(current, false);
        setTimeout(step, perWord);
      } else {
        onUpdate(current, true);
      }
    }
    step();
  }

  nextStep();
})();
</script>

</body>
</html>
```
Ok agora faça o mesmo com este aitab

O icone de tools.svg está na pasta svg do projeto não é necessário você vê e vários outros ícones estão mesmo lá

Quero que esse processo só seja aplicado quando estiver dando um widget ou seja o json do widget vai estar dentro de um processo e depois vai ser exibido em baixo do processo. Também tem que ser aplicado quando estiver escrevendo um documento sheets ou slides


Dê os códigos diretamente aqui na conversa

Vou aplicar exatamente o padrão do protótipo HTML (shimmer no ícone+texto, clique abre/fecha mesmo em streaming, cronómetro em tempo real, colapsa no fim) aos três pontos onde `aitab.dart` já tem a lógica de "bloco em aberto": `_StreamOpenBlock` (canvas doc/sheet/slide/whiteboard) e o novo caso de widget em streaming, que atualmente não existe como pill — só aparece já fechado.

Antes de reescrever o ficheiro inteiro preciso de confirmar um ponto que não está no HTML de referência nem no código atual: