import React, { useState, useRef, useEffect } from 'react';
import { Plus, ChevronLeft, Menu, FileText, Send, Zap, X, Sparkles } from 'lucide-react';

// Configurações
const GROQ_API_KEY = 'YOUR_GROQ_KEY';
const GEMINI_API_KEY = 'AIzaSyARcRrg6qEkYwQMmpCTowmBCvgwErImnBQ';

const App = () => {
  const [activeTab, setActiveTab] = useState('chat');
  const [messages, setMessages] = useState([
    { type: 'assistant', content: 'Olá! Descreva o documento que deseja criar e eu vou gerá-lo para você.' }
  ]);
  const [input, setInput] = useState('');
  const [isGenerating, setIsGenerating] = useState(false);
  const [advancedMode, setAdvancedMode] = useState(false);
  const [showMenu, setShowMenu] = useState(false);
  const [showDrawer, setShowDrawer] = useState(false);
  const [showOptions, setShowOptions] = useState(false);
  const [selectedModel, setSelectedModel] = useState('groq');
  const [pdfPreview, setPdfPreview] = useState(null);
  const [documents, setDocuments] = useState([]);
  const [inputFocused, setInputFocused] = useState(false);
  const chatRef = useRef(null);

  useEffect(() => {
    if (chatRef.current) {
      chatRef.current.scrollTop = chatRef.current.scrollHeight;
    }
  }, [messages]);

  const models = [
    { id: 'groq', name: 'Groq Llama 3.3 70B Versatile', icon: '⚡' },
    { id: 'gemini', name: 'Gemini 2.0 Flash Experimental', icon: '✨' }
  ];

  const addMessage = (content, type) => {
    setMessages(prev => [...prev, { type, content }]);
  };

  const generateWithGroq = async (prompt) => {
    const enhancedPrompt = advancedMode
      ? `Você é um especialista em criação de documentos profissionais de altíssima qualidade. Crie um documento HTML EXTREMAMENTE COMPLETO E DETALHADO sobre: "${prompt}"

REQUISITOS CRÍTICOS E OBRIGATÓRIOS:
- Título principal impactante com <h1> (centralizado, negrito, tamanho grande)
- Estrutura hierárquica clara e bem organizada com <h2> e <h3>
- MÍNIMO ABSOLUTO de 2000 palavras de conteúdo denso, rico e profundo
- Parágrafos extremamente bem desenvolvidos (6-8 linhas cada) com <p>
- Use listas detalhadas <ul> ou <ol> quando apropriado
- Adicione <strong> e <em> para ênfase estratégica
- Tom profissional, acadêmico e autoritativo
- Informações precisas, atualizadas e verificáveis
- Exemplos práticos, casos de uso e aplicações reais
- Dados, estatísticas e referências quando relevante
- Conclusão robusta e impactante
- Múltiplas seções e subseções bem organizadas

ESTILO CSS EMBUTIDO OBRIGATÓRIO:
- padding: 25mm em todos os lados (top, right, bottom, left)
- font-family: Arial, Helvetica, sans-serif
- font-size: 12pt para texto normal
- font-size: 28pt para h1 (título principal)
- font-size: 20pt para h2 (seções)
- font-size: 16pt para h3 (subseções)
- line-height: 1.8 (espaçamento generoso)
- color: #1a1a1a (texto escuro)
- text-align: justify (texto justificado)
- max-width: 210mm (largura A4)
- background: white
- Margens internas respeitadas

Retorne APENAS o HTML completo com CSS inline em CADA elemento. SEM tags html, head ou body externas. Comece direto com o conteúdo estilizado. GARANTA que as margens sejam respeitadas.`
      : `Crie um documento HTML bem formatado, profissional e detalhado sobre: "${prompt}". 

Use estrutura HTML completa com h1, h2, h3, p, ul/ol. Adicione CSS inline para padding de 25mm em todos os lados, fonte Arial 12pt, espaçamento entre linhas 1.6, texto justificado. Mínimo 1000 palavras. Retorne apenas HTML puro com estilos inline em cada elemento. GARANTA margens de 25mm.`;

    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${GROQ_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        messages: [{ role: 'user', content: enhancedPrompt }],
        temperature: advancedMode ? 0.9 : 0.7,
        max_tokens: advancedMode ? 8000 : 4000
      })
    });

    const data = await response.json();
    return data.choices[0].message.content.replace(/```html|```/g, '').trim();
  };

  const generateWithGemini = async (prompt) => {
    const enhancedPrompt = advancedMode
      ? `Você é um especialista em documentação profissional de elite. Crie um documento HTML EXTREMAMENTE COMPLETO E APROFUNDADO sobre: "${prompt}"

ESPECIFICAÇÕES TÉCNICAS OBRIGATÓRIAS:
- Use <h1> para título principal (centralizado, negrito, 28pt)
- Hierarquia clara e profunda com <h2> (20pt) e <h3> (16pt)
- Conteúdo EXTENSO E DENSO: mínimo absoluto de 2000 palavras
- Parágrafos muito bem desenvolvidos de 6-8 linhas com <p>
- Listas organizadas e detalhadas <ul>/<ol> quando apropriado
- Ênfases estratégicas com <strong> e <em>
- Tom acadêmico, profissional e autoritativo
- Exemplos concretos, estudos de caso, aplicações práticas
- Dados, estatísticas e informações verificáveis
- Múltiplas seções e análises profundas

CSS INLINE OBRIGATÓRIO EM CADA ELEMENTO:
- padding: 25mm 25mm 25mm 25mm (CRÍTICO - margens em todos os lados)
- font-family: Arial, Helvetica, sans-serif
- font-size: 12pt (corpo do texto)
- font-size: 28pt (h1 - título)
- font-size: 20pt (h2 - seções)
- font-size: 16pt (h3 - subseções)
- line-height: 1.8
- color: #1a1a1a
- text-align: justify
- max-width: 210mm
- background: white
- box-sizing: border-box

Retorne HTML puro com CSS inline em TODOS os elementos. SEM tags html, head, body externas. GARANTA que as margens de 25mm sejam respeitadas em todo o documento.`
      : `Crie documento HTML formatado e profissional sobre: "${prompt}". Use h1, h2, h3, p, listas. CSS inline OBRIGATÓRIO: padding 25mm em todos os lados, fonte Arial 12pt, espaçamento 1.6, texto justificado. Min 1000 palavras. Retorne HTML puro. GARANTA margens corretas.`;

    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=${GEMINI_API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: enhancedPrompt }] }]
      })
    });

    const data = await response.json();
    return data.candidates[0].content.parts[0].text.replace(/```html|```/g, '').trim();
  };

  const htmlToPDF = async (html) => {
    const wrappedHtml = `
      <div style="
        width: 210mm;
        min-height: 297mm;
        padding: 25mm;
        margin: 0;
        background: white;
        font-family: Arial, sans-serif;
        font-size: 12pt;
        line-height: 1.6;
        color: #1a1a1a;
        text-align: justify;
        box-sizing: border-box;
      ">
        ${html}
      </div>
    `;

    const container = document.createElement('div');
    container.style.cssText = 'position:absolute;left:-9999px;';
    container.innerHTML = wrappedHtml;
    document.body.appendChild(container);

    const canvas = await html2canvas(container.querySelector('div'), {
      scale: 2,
      useCORS: true,
      logging: false,
      backgroundColor: '#ffffff',
      width: 794,
      windowWidth: 794
    });

    document.body.removeChild(container);

    const { jsPDF } = window.jspdf;
    const pdf = new jsPDF('p', 'mm', 'a4');
    const imgData = canvas.toDataURL('image/png');
    const imgW = 210;
    const imgH = (canvas.height * imgW) / canvas.width;
    const pageH = 297;

    let heightLeft = imgH;
    let position = 0;

    pdf.addImage(imgData, 'PNG', 0, position, imgW, imgH);
    heightLeft -= pageH;

    while (heightLeft > 0) {
      position = heightLeft - imgH;
      pdf.addPage();
      pdf.addImage(imgData, 'PNG', 0, position, imgW, imgH);
      heightLeft -= pageH;
    }

    return pdf.output('blob');
  };

  const handleSend = async () => {
    if (!input.trim() || isGenerating) return;

    const userMessage = input.trim();
    addMessage(userMessage, 'user');
    setInput('');
    setIsGenerating(true);

    try {
      addMessage('Gerando documento...', 'thinking');

      const html = selectedModel === 'groq' 
        ? await generateWithGroq(userMessage)
        : await generateWithGemini(userMessage);

      const pdfBlob = await htmlToPDF(html);
      const pdfUrl = URL.createObjectURL(pdfBlob);
      
      setPdfPreview(pdfUrl);
      
      const newDoc = {
        id: Date.now(),
        title: userMessage.substring(0, 50) + '...',
        url: pdfUrl,
        date: new Date().toLocaleDateString('pt-BR')
      };
      setDocuments(prev => [newDoc, ...prev]);

      setMessages(prev => prev.filter(m => m.type !== 'thinking'));
      addMessage('✅ Documento gerado com sucesso! Veja na aba Preview.', 'assistant');
      
      setTimeout(() => setActiveTab('preview'), 1000);
    } catch (error) {
      setMessages(prev => prev.filter(m => m.type !== 'thinking'));
      addMessage(`❌ Erro ao gerar documento: ${error.message}`, 'assistant');
    } finally {
      setIsGenerating(false);
    }
  };

  return (
    <div className="app">
      <style>{`
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
          -webkit-tap-highlight-color: transparent;
        }

        html, body {
          height: 100%;
          overflow: hidden;
          background: #f5f5f5;
        }

        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          -webkit-font-smoothing: antialiased;
        }

        .app {
          height: 100vh;
          display: flex;
          flex-direction: column;
          background-image: url('/assets/background.png');
          background-size: cover;
          background-position: center;
        }

        .appbar {
          padding: 12px 16px;
          background: rgba(255, 255, 255, 0.8);
          backdrop-filter: blur(20px) saturate(180%);
          -webkit-backdrop-filter: blur(20px) saturate(180%);
          border-bottom: 0.5px solid rgba(0, 0, 0, 0.1);
          display: flex;
          align-items: center;
          justify-content: space-between;
        }

        .appbar-left, .appbar-right {
          width: 40px;
        }

        .icon-btn {
          width: 36px;
          height: 36px;
          border: none;
          background: transparent;
          display: flex;
          align-items: center;
          justify-content: center;
          border-radius: 50%;
          cursor: pointer;
          color: #007AFF;
        }

        .app-title {
          font-size: 17px;
          font-weight: 600;
          color: #000;
          text-align: center;
          flex: 1;
          letter-spacing: -0.4px;
        }

        .dots {
          display: flex;
          gap: 3px;
          flex-direction: column;
          align-items: center;
        }

        .dots span {
          width: 4px;
          height: 4px;
          border-radius: 50%;
          background: #007AFF;
        }

        .tabs {
          display: flex;
          background: rgba(255, 255, 255, 0.9);
          backdrop-filter: blur(20px);
          position: relative;
          border-bottom: 0.5px solid rgba(0, 0, 0, 0.1);
        }

        .tab {
          flex: 1;
          padding: 12px;
          border: none;
          background: transparent;
          font-size: 13px;
          font-weight: 400;
          color: #8e8e93;
          cursor: pointer;
          position: relative;
          z-index: 1;
          transition: color 0.3s;
        }

        .tab.active {
          color: #000;
          font-weight: 600;
        }

        .tab-indicator {
          position: absolute;
          bottom: 0;
          left: 0;
          width: 50%;
          height: 2px;
          background: #007AFF;
          transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
        }

        .tab-indicator.right {
          transform: translateX(100%);
        }

        .content {
          flex: 1;
          overflow: hidden;
        }

        .chat-container {
          height: 100%;
          overflow-y: auto;
          padding: 16px;
          display: flex;
          flex-direction: column;
          gap: 16px;
        }

        .message-wrapper {
          display: flex;
          width: 100%;
        }

        .message-wrapper.user {
          justify-content: flex-end;
        }

        .message.user {
          background: #007AFF;
          color: white;
          padding: 12px 16px;
          border-radius: 18px;
          border-bottom-right-radius: 4px;
          max-width: 75%;
          font-size: 16px;
          line-height: 1.4;
        }

        .ai-message {
          font-size: 17px;
          line-height: 1.5;
          color: rgba(255, 255, 255, 0.95);
          text-shadow: 0 1px 3px rgba(0,0,0,0.2);
          max-width: 90%;
          font-weight: 400;
        }

        .thinking {
          display: flex;
          gap: 6px;
          padding: 16px 0;
        }

        .thinking-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: rgba(255,255,255,0.8);
          animation: bounce 1.4s infinite;
        }

        .thinking-dot:nth-child(2) {
          animation-delay: 0.2s;
        }

        .thinking-dot:nth-child(3) {
          animation-delay: 0.4s;
        }

        @keyframes bounce {
          0%, 60%, 100% { transform: translateY(0); }
          30% { transform: translateY(-10px); }
        }

        .preview-container {
          height: 100%;
          background: rgba(0,0,0,0.3);
          display: flex;
          align-items: center;
          justify-content: center;
          padding: 20px;
        }

        .pdf-frame {
          width: 100%;
          height: 100%;
          border: none;
          background: white;
          box-shadow: 0 10px 40px rgba(0,0,0,0.3);
        }

        .empty-preview {
          text-align: center;
          color: rgba(255,255,255,0.7);
        }

        .empty-preview p {
          margin-top: 16px;
          font-size: 16px;
        }

        .input-area {
          padding: 12px 16px;
          background: rgba(255, 255, 255, 0.9);
          backdrop-filter: blur(20px);
          border-top: 0.5px solid rgba(0, 0, 0, 0.1);
          display: flex;
          gap: 8px;
          align-items: flex-end;
          transition: padding 0.3s;
        }

        .input-area.focused {
          padding-top: 24px;
          padding-bottom: 24px;
        }

        .plus-btn {
          width: 36px;
          height: 36px;
          border: none;
          background: transparent;
          color: #007AFF;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          flex-shrink: 0;
        }

        .input-wrapper {
          flex: 1;
          display: flex;
          gap: 8px;
          align-items: flex-end;
          background: #f2f2f7;
          border-radius: 20px;
          padding: 8px 12px;
        }

        textarea {
          flex: 1;
          border: none;
          background: transparent;
          font-size: 17px;
          font-family: inherit;
          resize: none;
          outline: none;
          line-height: 1.4;
          max-height: 120px;
        }

        .send-btn {
          width: 32px;
          height: 32px;
          border: none;
          background: #007AFF;
          color: white;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          flex-shrink: 0;
        }

        .send-btn:disabled {
          background: #c7c7cc;
        }

        .options-menu {
          position: fixed;
          bottom: 90px;
          left: 16px;
          background: rgba(255, 255, 255, 0.95);
          backdrop-filter: blur(20px);
          border-radius: 14px;
          padding: 8px;
          box-shadow: 0 10px 40px rgba(0,0,0,0.2);
          min-width: 250px;
          z-index: 50;
        }

        .option-item {
          width: 100%;
          padding: 14px 16px;
          border: none;
          background: transparent;
          display: flex;
          align-items: center;
          gap: 12px;
          cursor: pointer;
          border-radius: 8px;
          font-size: 16px;
          color: #000;
          text-align: left;
        }

        .option-item:active {
          background: rgba(0,0,0,0.05);
        }

        .option-item.active {
          color: #007AFF;
        }

        .check {
          margin-left: auto;
          color: #007AFF;
          font-weight: bold;
          font-size: 18px;
        }

        .modal {
          position: fixed;
          inset: 0;
          background: rgba(0,0,0,0.4);
          display: flex;
          align-items: flex-end;
          z-index: 100;
        }

        .modal-content {
          background: white;
          border-radius: 20px 20px 0 0;
          width: 100%;
          padding: 24px;
          animation: slideUp 0.3s;
        }

        @keyframes slideUp {
          from { transform: translateY(100%); }
          to { transform: translateY(0); }
        }

        .modal-header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 20px;
        }

        .modal-header h2 {
          font-size: 20px;
          font-weight: 600;
        }

        .modal-header button {
          width: 32px;
          height: 32px;
          border: none;
          background: #f2f2f7;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
        }

        .modal-body label {
          display: block;
          font-size: 14px;
          color: #8e8e93;
          margin-bottom: 8px;
          font-weight: 500;
        }

        .modal-body select {
          width: 100%;
          padding: 14px;
          border: 1px solid #e5e5ea;
          border-radius: 10px;
          font-size: 17px;
          background: white;
          outline: none;
        }

        .drawer-overlay {
          position: fixed;
          inset: 0;
          background: rgba(0,0,0,0.4);
          z-index: 100;
        }

        .drawer {
          position: fixed;
          left: 0;
          top: 0;
          bottom: 0;
          width: 85%;
          max-width: 360px;
          background: white;
          animation: slideRight 0.3s;
          display: flex;
          flex-direction: column;
        }

        @keyframes slideRight {
          from { transform: translateX(-100%); }
          to { transform: translateX(0); }
        }

        .drawer-header {
          padding: 20px;
          border-bottom: 1px solid #e5e5ea;
          display: flex;
          justify-content: space-between;
          align-items: center;
        }

        .drawer-header h2 {
          font-size: 22px;
          font-weight: 700;
        }

        .drawer-header button {
          width: 32px;
          height: 32px;
          border: none;
          background: #f2f2f7;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
        }

        .drawer-body {
          flex: 1;
          overflow-y: auto;
          padding: 16px;
        }

        .empty {
          text-align: center;
          color: #8e8e93;
          padding: 40px 20px;
          font-size: 15px;
        }

        .doc-item {
          display: flex;
          gap: 12px;
          padding: 14px;
          border-radius: 12px;
          cursor: pointer;
          margin-bottom: 8px;
          background: #f9f9f9;
          border: 1px solid #e5e5ea;
        }

        .doc-item:active {
          background: #f2f2f7;
        }

        .doc-info {
          flex: 1;
        }

        .doc-title {
          font-size: 15px;
          font-weight: 500;
          margin-bottom: 4px;
          color: #000;
        }

        .doc-date {
          font-size: 13px;
          color: #8e8e93;
        }
      `}</style>

      {/* AppBar */}
      <div className="appbar">
        <div className="appbar-left">
          <button className="icon-btn" onClick={() => setShowDrawer(true)}>
            <Menu size={22} />
          </button>
        </div>
        <h1 className="app-title">DocuGen AI</h1>
        <div className="appbar-right">
          <button className="icon-btn" onClick={() => setShowMenu(true)}>
            <div className="dots">
              <span></span>
              <span></span>
              <span></span>
            </div>
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="tabs">
        <button 
          className={`tab ${activeTab === 'chat' ? 'active' : ''}`}
          onClick={() => setActiveTab('chat')}
        >
          Chat
        </button>
        <button 
          className={`tab ${activeTab === 'preview' ? 'active' : ''}`}
          onClick={() => setActiveTab('preview')}
        >
          Preview
        </button>
        <div className={`tab-indicator ${activeTab === 'preview' ? 'right' : ''}`} />
      </div>

      {/* Content */}
      <div className="content">
        {activeTab === 'chat' ? (
          <div className="chat-container" ref={chatRef}>
            {messages.map((msg, i) => (
              <div key={i} className={`message-wrapper ${msg.type}`}>
                {msg.type === 'user' ? (
                  <div className="message user">{msg.content}</div>
                ) : msg.type === 'thinking' ? (
                  <div className="thinking">
                    <div className="thinking-dot"></div>
                    <div className="thinking-dot"></div>
                    <div className="thinking-dot"></div>
                  </div>
                ) : (
                  <div className="ai-message">{msg.content}</div>
                )}
              </div>
            ))}
          </div>
        ) : (
          <div className="preview-container">
            {pdfPreview ? (
              <iframe src={pdfPreview} className="pdf-frame" />
            ) : (
              <div className="empty-preview">
                <FileText size={64} strokeWidth={1} />
                <p>Nenhum documento gerado ainda</p>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Input Area */}
      <div className={`input-area ${inputFocused ? 'focused' : ''}`}>
        <button className="plus-btn" onClick={() => setShowOptions(!showOptions)}>
          <Plus size={24} />
        </button>
        <div className="input-wrapper">
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onFocus={() => setInputFocused(true)}
            onBlur={() => setInputFocused(false)}
            placeholder="Descreva seu documento..."
            rows={inputFocused ? 4 : 1}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                handleSend();
              }
            }}
          />
          <button className="send-btn" onClick={handleSend} disabled={!input.trim() || isGenerating}>
            <Send size={18} />
          </button>
        </div>
      </div>

      {/* Options Menu */}
      {showOptions && (
        <div className="options-menu">
          <button 
            className={`option-item ${advancedMode ? 'active' : ''}`}
            onClick={() => {
              setAdvancedMode(!advancedMode);
              setShowOptions(false);
            }}
          >
            <Zap size={20} />
            <span>Raciocínio Avançado</span>
            {advancedMode && <div className="check">✓</div>}
          </button>
          <button className="option-item" onClick={() => setShowOptions(false)}>
            <Sparkles size={20} />
            <span>Modo Criativo</span>
          </button>
        </div>
      )}

      {/* Settings Menu */}
      {showMenu && (
        <div className="modal" onClick={() => setShowMenu(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>Configurações</h2>
              <button onClick={() => setShowMenu(false)}><X size={20} /></button>
            </div>
            <div className="modal-body">
              <label>Modelo de IA</label>
              <select value={selectedModel} onChange={(e) => setSelectedModel(e.target.value)}>
                {models.map(m => (
                  <option key={m.id} value={m.id}>{m.icon} {m.name}</option>
                ))}
              </select>
            </div>
          </div>
        </div>
      )}

      {/* Drawer */}
      {showDrawer && (
        <div className="drawer-overlay" onClick={() => setShowDrawer(false)}>
          <div className="drawer" onClick={(e) => e.stopPropagation()}>
            <div className="drawer-header">
              <h2>Documentos</h2>
              <button onClick={() => setShowDrawer(false)}><X size={20} /></button>
            </div>
            <div className="drawer-body">
              {documents.length === 0 ? (
                <p className="empty">Nenhum documento criado</p>
              ) : (
                documents.map(doc => (
                  <div key={doc.id} className="doc-item" onClick={() => {
                    setPdfPreview(doc.url);
                    setActiveTab('preview');
                    setShowDrawer(false);
                  }}>
                    <FileText size={40} color="#dc2626" />
                    <div className="doc-info">
                      <p className="doc-title">{doc.title}</p>
                      <p className="doc-date">{doc.date}</p>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default App;