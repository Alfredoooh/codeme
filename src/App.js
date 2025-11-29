import React, { useState, useRef, useEffect } from 'react';
import { Send, Plus, Menu, ChevronLeft, Download, Trash2, FileText, Zap, Settings, X, Check, Loader } from 'lucide-react';

const DocuGenAI = () => {
  const [activeTab, setActiveTab] = useState('chat');
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [isGenerating, setIsGenerating] = useState(false);
  const [currentDoc, setCurrentDoc] = useState(null);
  const [docs, setDocs] = useState([]);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [advancedMode, setAdvancedMode] = useState(false);
  const [selectedModel, setSelectedModel] = useState('groq');
  const [apiKeys, setApiKeys] = useState({
    groq: localStorage.getItem('groq_key') || '',
    gemini: localStorage.getItem('gemini_key') || ''
  });
  const [inputFocused, setInputFocused] = useState(false);
  const [generationSteps, setGenerationSteps] = useState([]);
  const [currentStep, setCurrentStep] = useState(-1);
  
  const chatEndRef = useRef(null);
  const inputRef = useRef(null);
  const previewRef = useRef(null);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  useEffect(() => {
    const savedDocs = localStorage.getItem('documents');
    if (savedDocs) {
      setDocs(JSON.parse(savedDocs));
    }
  }, []);

  const saveApiKey = (provider, key) => {
    localStorage.setItem(`${provider}_key`, key);
    setApiKeys(prev => ({ ...prev, [provider]: key }));
  };

  const getDocumentTemplate = (type, content) => {
    const templates = {
      professional: `
        <!doctype html>
        <html lang="pt-PT">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width,initial-scale=1" />
          <title>${content.title || 'Documento Profissional'}</title>
          <style>
            :root{
              --bg:#ffffff;
              --card:#fbfbfd;
              --text:#0f1724;
              --muted:#546275;
              --accent:#0b84ff;
              --accent-2:#6c63ff;
              --radius:12px;
              --max-width:800px;
              --glass: rgba(11,132,255,0.06);
            }
            *{box-sizing:border-box;margin:0;padding:0}
            body{
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
              background: linear-gradient(180deg,var(--bg), #f7fbff);
              color:var(--text);
              line-height:1.6;
              padding:40px 20px;
              display:flex;
              justify-content:center;
            }
            .container{
              width:100%;
              max-width:var(--max-width);
              background:linear-gradient(180deg, rgba(255,255,255,0.9), rgba(255,255,255,0.7));
              border-radius:20px;
              box-shadow: 0 10px 40px rgba(12,24,48,0.1);
              padding:40px;
              backdrop-filter: blur(10px);
            }
            .header{
              display:flex;
              align-items:center;
              gap:16px;
              margin-bottom:32px;
              padding-bottom:20px;
              border-bottom:2px solid var(--glass);
            }
            .logo{
              width:60px;
              height:60px;
              border-radius:14px;
              background:linear-gradient(135deg,var(--accent),var(--accent-2));
              display:flex;
              align-items:center;
              justify-content:center;
              color:white;
              font-weight:700;
              font-size:24px;
              box-shadow: 0 8px 20px rgba(11,132,255,0.3);
            }
            h1{font-size:28px;margin:0;font-weight:700;color:var(--text)}
            .subtitle{color:var(--muted);font-size:15px;margin-top:6px}
            h2{
              font-size:22px;
              margin:32px 0 16px;
              color:var(--accent);
              font-weight:600;
              display:flex;
              align-items:center;
              gap:10px;
            }
            h3{font-size:18px;margin:24px 0 12px;font-weight:600}
            p{margin:0 0 16px;line-height:1.7}
            ul,ol{margin:0 0 16px 24px;line-height:1.8}
            .highlight{
              background: linear-gradient(90deg, rgba(11,132,255,0.1), rgba(108,99,255,0.05));
              padding:16px;
              border-radius:12px;
              border-left:4px solid var(--accent);
              margin:20px 0;
            }
            .section{
              background:var(--card);
              padding:24px;
              border-radius:var(--radius);
              margin:20px 0;
              box-shadow: 0 4px 12px rgba(12,24,48,0.04);
            }
            @media print{
              body{padding:0}
              .container{box-shadow:none;border-radius:0}
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <div class="logo">${content.icon || '📄'}</div>
              <div>
                <h1>${content.title || 'Documento Profissional'}</h1>
                <div class="subtitle">${content.subtitle || 'Gerado automaticamente'}</div>
              </div>
            </div>
            ${content.body || '<p>Conteúdo do documento aqui.</p>'}
          </div>
        </body>
        </html>
      `,
      
      modern: `
        <!doctype html>
        <html lang="pt-PT">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width,initial-scale=1" />
          <title>${content.title || 'Documento Moderno'}</title>
          <style>
            *{box-sizing:border-box;margin:0;padding:0}
            body{
              font-family: 'SF Pro Display', -apple-system, sans-serif;
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              color:#1a202c;
              padding:40px 20px;
              min-height:100vh;
            }
            .container{
              max-width:900px;
              margin:0 auto;
              background:white;
              border-radius:24px;
              padding:48px;
              box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            }
            .header{
              text-align:center;
              margin-bottom:48px;
              padding-bottom:32px;
              border-bottom:3px solid #667eea;
            }
            .icon{
              font-size:64px;
              margin-bottom:16px;
            }
            h1{
              font-size:36px;
              font-weight:800;
              background: linear-gradient(135deg, #667eea, #764ba2);
              -webkit-background-clip: text;
              -webkit-text-fill-color: transparent;
              margin-bottom:12px;
            }
            h2{
              font-size:26px;
              margin:36px 0 20px;
              color:#667eea;
              font-weight:700;
            }
            p{line-height:1.8;margin-bottom:16px;font-size:17px}
            ul,ol{margin:0 0 20px 28px;line-height:2}
            .card{
              background: linear-gradient(135deg, #f6f8fb 0%, #ffffff 100%);
              padding:24px;
              border-radius:16px;
              margin:24px 0;
              border-left:5px solid #667eea;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <div class="icon">${content.icon || '✨'}</div>
              <h1>${content.title || 'Documento Moderno'}</h1>
            </div>
            ${content.body || '<p>Conteúdo aqui.</p>'}
          </div>
        </body>
        </html>
      `,
      
      minimal: `
        <!doctype html>
        <html lang="pt-PT">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width,initial-scale=1" />
          <title>${content.title || 'Documento'}</title>
          <style>
            *{box-sizing:border-box;margin:0;padding:0}
            body{
              font-family: 'Helvetica Neue', Arial, sans-serif;
              background:#ffffff;
              color:#2d3748;
              padding:60px 40px;
              max-width:700px;
              margin:0 auto;
              line-height:1.8;
            }
            h1{
              font-size:32px;
              font-weight:700;
              margin-bottom:8px;
              color:#1a202c;
            }
            .date{
              color:#718096;
              font-size:14px;
              margin-bottom:40px;
              padding-bottom:20px;
              border-bottom:2px solid #e2e8f0;
            }
            h2{
              font-size:24px;
              margin:40px 0 16px;
              font-weight:600;
              color:#2d3748;
            }
            p{margin-bottom:20px;font-size:16px}
            ul,ol{margin:0 0 20px 24px}
            li{margin-bottom:8px}
          </style>
        </head>
        <body>
          <h1>${content.title || 'Documento'}</h1>
          <div class="date">${new Date().toLocaleDateString('pt-PT')}</div>
          ${content.body || '<p>Conteúdo aqui.</p>'}
        </body>
        </html>
      `
    };

    return templates[type] || templates.professional;
  };

  const generateWithGroq = async (prompt) => {
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKeys.groq}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.7,
        max_tokens: advancedMode ? 8000 : 4000
      })
    });

    if (!response.ok) throw new Error('Erro na API Groq');
    const data = await response.json();
    return data.choices[0].message.content;
  };

  const generateWithGemini = async (prompt) => {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKeys.gemini}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }]
        })
      }
    );

    if (!response.ok) throw new Error('Erro na API Gemini');
    const data = await response.json();
    return data.candidates[0].content.parts[0].text;
  };

  const generateDocument = async () => {
    if (!input.trim() || isGenerating) return;

    const provider = selectedModel === 'groq' ? 'groq' : 'gemini';
    if (!apiKeys[provider]) {
      setMessages(prev => [...prev, {
        type: 'system',
        content: `⚠️ Configure a chave API do ${provider.toUpperCase()} nas configurações primeiro.`
      }]);
      setSettingsOpen(true);
      return;
    }

    const userMessage = input;
    setMessages(prev => [...prev, { type: 'user', content: userMessage }]);
    setInput('');
    setIsGenerating(true);

    const steps = advancedMode ? [
      '🔍 Analisando requisitos',
      '🌐 Pesquisando informações',
      '📐 Estruturando conteúdo',
      '✨ Gerando documento',
      '📄 Convertendo para PDF'
    ] : [
      '💭 Processando pedido',
      '✍️ Gerando conteúdo',
      '📄 Criando PDF'
    ];

    setGenerationSteps(steps);
    setCurrentStep(0);

    try {
      const enhancedPrompt = advancedMode ? `
Você é um especialista em criação de documentos profissionais. Crie um documento HTML completo e MUITO detalhado sobre: "${userMessage}"

REQUISITOS OBRIGATÓRIOS:
1. Mínimo de 1200 palavras de conteúdo substantivo
2. Estrutura profissional com introdução, desenvolvimento detalhado e conclusão
3. Use APENAS h2 e h3 para títulos de seções (NUNCA h1)
4. Parágrafos bem desenvolvidos e informativos (mínimo 4-5 linhas cada)
5. Listas quando apropriado, mas sempre com contexto em parágrafos
6. Informações precisas, atualizadas e relevantes
7. Tom profissional e objetivo
8. Citações ou dados quando possível

FORMATO DE RESPOSTA:
Retorne um objeto JSON neste formato EXATO:
{
  "title": "Título do documento",
  "subtitle": "Subtítulo ou descrição breve",
  "icon": "emoji apropriado",
  "template": "professional",
  "body": "HTML completo com h2, h3, p, ul, ol, div class='section', div class='highlight'"
}

O campo "body" deve conter TODO o conteúdo do documento em HTML puro (sem h1, sem tags html/head/body).
` : `
Crie um documento HTML bem formatado sobre: "${userMessage}"

Retorne JSON:
{
  "title": "Título",
  "subtitle": "Descrição",
  "icon": "emoji",
  "template": "modern",
  "body": "HTML com h2, h3, p, ul"
}
`;

      for (let i = 0; i < steps.length - 1; i++) {
        setCurrentStep(i);
        await new Promise(r => setTimeout(r, advancedMode ? 800 : 500));
      }

      setCurrentStep(steps.length - 1);

      const generateFn = selectedModel === 'groq' ? generateWithGroq : generateWithGemini;
      let response = await generateFn(enhancedPrompt);

      response = response.replace(/```json|```/g, '').trim();
      const docData = JSON.parse(response);

      const html = getDocumentTemplate(docData.template || 'professional', docData);

      const newDoc = {
        id: Date.now(),
        title: docData.title,
        html,
        date: new Date().toISOString(),
        icon: docData.icon || '📄'
      };

      setCurrentDoc(newDoc);
      setDocs(prev => {
        const updated = [newDoc, ...prev];
        localStorage.setItem('documents', JSON.stringify(updated));
        return updated;
      });

      setMessages(prev => [...prev, {
        type: 'system',
        content: '✅ Documento gerado com sucesso! Confira na aba Preview.'
      }]);
      
      setActiveTab('preview');

    } catch (error) {
      setMessages(prev => [...prev, {
        type: 'system',
        content: `❌ Erro: ${error.message}`
      }]);
    } finally {
      setIsGenerating(false);
      setGenerationSteps([]);
      setCurrentStep(-1);
    }
  };

  const downloadPDF = () => {
    if (!currentDoc) return;
    
    const blob = new Blob([currentDoc.html], { type: 'text/html' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${currentDoc.title.replace(/[^a-z0-9]/gi, '_')}.html`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const deleteDoc = (id) => {
    setDocs(prev => {
      const updated = prev.filter(d => d.id !== id);
      localStorage.setItem('documents', JSON.stringify(updated));
      return updated;
    });
    if (currentDoc?.id === id) {
      setCurrentDoc(null);
    }
  };

  return (
    <div className="h-screen flex flex-col bg-gray-50" 
         style={{
           backgroundImage: activeTab === 'chat' ? 'url(assets/background.png), linear-gradient(135deg, #667eea 0%, #764ba2 100%)' : 'none',
           backgroundSize: 'cover',
           backgroundPosition: 'center',
           backgroundBlendMode: 'overlay'
         }}>
      
      {/* iOS Style App Bar with Blur */}
      <div className="relative">
        <div className="absolute inset-0 bg-white/70 backdrop-blur-xl border-b border-gray-200/50"></div>
        <div className="relative px-4 py-3 flex items-center justify-between">
          <button onClick={() => setDrawerOpen(true)} className="p-2 hover:bg-gray-100 rounded-full transition-colors">
            <Menu size={24} className="text-gray-700" />
          </button>
          <h1 className="text-lg font-semibold text-gray-900">DocuGen AI</h1>
          <button onClick={() => setSettingsOpen(true)} className="p-2 hover:bg-gray-100 rounded-full transition-colors">
            <Settings size={22} className="text-gray-600" />
          </button>
        </div>
      </div>

      {/* iOS Style Tabs */}
      <div className="relative bg-white/50 backdrop-blur-lg border-b border-gray-200/30">
        <div className="flex">
          <button
            onClick={() => setActiveTab('chat')}
            className={`flex-1 py-3 text-[15px] font-medium transition-all relative ${
              activeTab === 'chat' ? 'text-blue-500' : 'text-gray-500'
            }`}>
            Chat
            {activeTab === 'chat' && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-500 rounded-full"></div>
            )}
          </button>
          <button
            onClick={() => setActiveTab('preview')}
            className={`flex-1 py-3 text-[15px] font-medium transition-all relative ${
              activeTab === 'preview' ? 'text-blue-500' : 'text-gray-500'
            }`}>
            Preview
            {activeTab === 'preview' && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-500 rounded-full"></div>
            )}
          </button>
        </div>
      </div>

      {/* Content Area */}
      <div className="flex-1 overflow-hidden">
        {activeTab === 'chat' ? (
          <div className="h-full flex flex-col">
            <div className="flex-1 overflow-y-auto px-4 py-4 space-y-4">
              <div className="text-gray-700 text-[15px] leading-relaxed">
                Olá! Descreva o documento que deseja criar e eu vou gerá-lo para você.
              </div>
              
              {messages.map((msg, i) => (
                <div key={i}>
                  {msg.type === 'user' ? (
                    <div className="flex justify-end">
                      <div className="max-w-[85%] bg-blue-500 text-white rounded-[20px] rounded-br-[4px] px-4 py-2.5 text-[15px]">
                        {msg.content}
                      </div>
                    </div>
                  ) : (
                    <div className="text-gray-700 text-[15px] leading-relaxed">
                      {msg.content}
                    </div>
                  )}
                </div>
              ))}

              {isGenerating && generationSteps.length > 0 && (
                <div className="space-y-2">
                  {generationSteps.map((step, i) => (
                    <div key={i} className="flex items-center gap-3 text-[15px]">
                      {i < currentStep ? (
                        <Check size={18} className="text-green-500 flex-shrink-0" />
                      ) : i === currentStep ? (
                        <Loader size={18} className="text-blue-500 animate-spin flex-shrink-0" />
                      ) : (
                        <div className="w-[18px] h-[18px] rounded-full border-2 border-gray-300 flex-shrink-0"></div>
                      )}
                      <span className={i <= currentStep ? 'text-gray-900 font-medium' : 'text-gray-400'}>
                        {step}
                      </span>
                    </div>
                  ))}
                </div>
              )}
              
              <div ref={chatEndRef} />
            </div>

            {/* Input Area */}
            <div className={`bg-white/70 backdrop-blur-xl border-t border-gray-200/50 px-4 transition-all ${
              inputFocused ? 'py-6' : 'py-3'
            }`}>
              <div className="flex items-end gap-2">
                <button
                  onClick={() => setMenuOpen(true)}
                  className="p-2.5 hover:bg-gray-100 rounded-full transition-colors flex-shrink-0">
                  <Plus size={24} className="text-gray-600" />
                </button>
                
                <div className={`flex-1 bg-gray-100 rounded-[20px] px-4 py-2 flex items-end gap-2 transition-all ${
                  inputFocused ? 'shadow-lg ring-2 ring-blue-500' : ''
                }`}>
                  <textarea
                    ref={inputRef}
                    value={input}
                    onChange={(e) => setInput(e.target.value)}
                    onFocus={() => setInputFocused(true)}
                    onBlur={() => setInputFocused(false)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' && !e.shiftKey) {
                        e.preventDefault();
                        generateDocument();
                      }
                    }}
                    placeholder="Descreva seu documento..."
                    className={`flex-1 bg-transparent resize-none outline-none text-[16px] ${
                      inputFocused ? 'min-h-[100px]' : 'min-h-[24px] max-h-[100px]'
                    }`}
                    rows={1}
                    disabled={isGenerating}
                  />
                  <button
                    onClick={generateDocument}
                    disabled={!input.trim() || isGenerating}
                    className="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center disabled:opacity-50 flex-shrink-0">
                    <Send size={16} className="text-white" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div className="h-full bg-gray-900 overflow-auto p-4">
            {currentDoc ? (
              <div className="max-w-4xl mx-auto">
                <div className="flex items-center justify-between mb-4 bg-gray-800 rounded-lg p-3">
                  <div className="flex items-center gap-3">
                    <FileText size={24} className="text-blue-400" />
                    <div>
                      <div className="text-white font-medium">{currentDoc.title}</div>
                      <div className="text-gray-400 text-sm">{new Date(currentDoc.date).toLocaleDateString('pt-PT')}</div>
                    </div>
                  </div>
                  <button
                    onClick={downloadPDF}
                    className="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors">
                    <Download size={18} />
                  </button>
                </div>
                <div
                  ref={previewRef}
                  className="bg-white rounded-lg shadow-2xl overflow-hidden"
                  dangerouslySetInnerHTML={{ __html: currentDoc.html }}
                />
              </div>
            ) : (
              <div className="h-full flex flex-col items-center justify-center text-gray-500">
                <FileText size={64} className="mb-4 opacity-50" />
                <p>Nenhum documento gerado ainda</p>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Drawer Menu */}
      {drawerOpen && (
        <div className="fixed inset-0 z-50">
          <div className="absolute inset-0 bg-black/30" onClick={() => setDrawerOpen(false)} />
          <div className="absolute left-0 top-0 bottom-0 w-80 bg-white shadow-2xl overflow-y-auto">
            <div className="p-4 border-b flex items-center justify-between bg-gray-50">
              <h2 className="text-lg font-semibold">Documentos</h2>
              <button onClick={() => setDrawerOpen(false)} className="p-2 hover:bg-gray-200 rounded-full">
                <X size={20} />
              </button>
            </div>
            <div className="p-4 space-y-3">
              {docs.length === 0 ? (
                <div className="text-center text-gray-400 py-8">
                  <FileText size={48} className="mx-auto mb-3 opacity-30" />
                  <p>Nenhum documento criado</p>
                </div>
              ) : (
                docs.map(doc => (
                  <div
                    key={doc.id}
                    className="flex items-center gap-3 p-3 rounded-lg hover:bg-gray-50 cursor-pointer group"
                    onClick={() => {
                      setCurrentDoc(doc);
                      setActiveTab('preview');
                      setDrawerOpen(false);
                    }}>
                    <div className="text-3xl">{doc.icon}</div>
                    <div className="flex-1 min-w-0">
                      <div className="font-medium truncate">{doc.title}</div>
                      <div className="text-sm text-gray-500">
                        {new Date(doc.date).toLocaleDateString('pt-PT')}
                      </div>
                    </div>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        deleteDoc(doc.id);
                      }}
                      className="p-2 opacity-0 group-hover:opacity-100 hover:bg-red-100 rounded-full transition-all">
                      <Trash2 size={16} className="text-red-500" />
                    </button>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      )}

      {/* Options Menu */}
      {menuOpen && (
        <div className="fixed inset-0 z-50 flex items-end">
          <div className="absolute inset-0 bg-black/30" onClick={() => setMenuOpen(false)} />
          <div className="relative w-full bg-white rounded-t-3xl p-6 space-y-3 animate-slide-up">
            <h3 className="text-lg font-semibold mb-4">Opções</h3>
            
            <button
              onClick={() => {
                setAdvancedMode(!advancedMode);
                setMenuOpen(false);
              }}
              className={`w-full flex items-center gap-3 p-4 rounded-xl transition-colors ${
                advancedMode ? 'bg-blue-500 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}>
              <Zap size={20} />
              <span className="font-medium">Raciocínio Avançado</span>
              {advancedMode && <Check size={20} className="ml-auto" />}
            </button>

            <div className="space-y-2">
              <div className="text-sm font-medium text-gray-600 px-2">Modelo de IA</div>
              <button
                onClick={() => {
                  setSelectedModel('groq');
                  setMenuOpen(false);
                }}
                className={`w-full flex items-center gap-3 p-4 rounded-xl transition-colors ${
                  selectedModel === 'groq' ? 'bg-blue-500 text-white' : 'bg-gray-100 text-gray-700'
                }`}>
                <span className="font-medium">Groq (Llama 3.3)</span>
                {selectedModel === 'groq' && <Check size={20} className="ml-auto" />}
              </button>
              
              <button
                onClick={() => {
                  setSelectedModel('gemini');
                  setMenuOpen(false);
                }}
                className={`w-full flex items-center gap-3 p-4 rounded-xl transition-colors ${
                  selectedModel === 'gemini' ? 'bg-blue-500 text-white' : 'bg-gray-100 text-gray-700'
                }`}>
                <span className="font-medium">Google Gemini 2.0</span>
                {selectedModel === 'gemini' && <Check size={20} className="ml-auto" />}
              </button>
            </div>

            <button
              onClick={() => setMenuOpen(false)}
              className="w-full p-4 bg-gray-100 text-gray-700 rounded-xl font-medium hover:bg-gray-200 transition-colors">
              Cancelar
            </button>
          </div>
        </div>
      )}

      {/* Settings Modal */}
      {settingsOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div className="absolute inset-0 bg-black/50" onClick={() => setSettingsOpen(false)} />
          <div className="relative bg-white rounded-3xl p-6 w-full max-w-md space-y-4">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-semibold">Configurações</h2>
              <button onClick={() => setSettingsOpen(false)} className="p-2 hover:bg-gray-100 rounded-full">
                <X size={20} />
              </button>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Groq API Key
                </label>
                <input
                  type="password"
                  value={apiKeys.groq}
                  onChange={(e) => setApiKeys(prev => ({ ...prev, groq: e.target.value }))}
                  placeholder="gsk_..."
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Gemini API Key
                </label>
                <input
                  type="password"
                  value={apiKeys.gemini}
                  onChange={(e) => setApiKeys(prev => ({ ...prev, gemini: e.target.value }))}
                  placeholder="AIza..."
                  className="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none"
                />
              </div>

              <button
                onClick={() => {
                  saveApiKey('groq', apiKeys.groq);
                  saveApiKey('gemini', apiKeys.gemini);
                  setSettingsOpen(false);
                }}
                className="w-full bg-blue-500 text-white py-3 rounded-xl font-semibold hover:bg-blue-600 transition-colors">
                Salvar
              </button>
            </div>
          </div>
        </div>
      )}

      <style jsx>{`
        @keyframes slide-up {
          from {
            transform: translateY(100%);
          }
          to {
            transform: translateY(0);
          }
        }
        .animate-slide-up {
          animation: slide-up 0.3s ease-out;
        }
      `}</style>
    </div>
  );
};

export default DocuGenAI;
