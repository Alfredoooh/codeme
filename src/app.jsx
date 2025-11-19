import React, { useState } from 'react';
import { Send, Settings, Trash2, ChevronLeft } from 'lucide-react';

export default function DeepSeekPlayground() {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [showSettings, setShowSettings] = useState(false);
  const [apiKey, setApiKey] = useState('sk-7c0076d4248e44bdaeaed3bebf73aaa7');
  const [model, setModel] = useState('deepseek-chat');
  const [temperature, setTemperature] = useState(0.7);
  const [maxTokens, setMaxTokens] = useState(2000);

  const sendMessage = async () => {
    if (!input.trim() || loading) return;

    const userMessage = { role: 'user', content: input };
    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setLoading(true);

    try {
      const response = await fetch('https://api.deepseek.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`
        },
        body: JSON.stringify({
          model: model,
          messages: [...messages, userMessage],
          temperature: temperature,
          max_tokens: maxTokens,
          stream: false
        })
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error?.message || 'API request failed');
      }

      const data = await response.json();
      const assistantMessage = {
        role: 'assistant',
        content: data.choices[0].message.content
      };
      
      setMessages(prev => [...prev, assistantMessage]);
    } catch (error) {
      console.error('Error:', error);
      setMessages(prev => [...prev, {
        role: 'error',
        content: `Error: ${error.message}`
      }]);
    } finally {
      setLoading(false);
    }
  };

  const clearChat = () => {
    setMessages([]);
  };

  if (showSettings) {
    return (
      <div className="flex flex-col h-screen bg-gray-50">
        {/* Settings Header */}
        <div className="bg-white border-b border-gray-200">
          <div className="flex items-center px-4 h-14">
            <button
              onClick={() => setShowSettings(false)}
              className="flex items-center text-blue-500 font-normal -ml-2"
            >
              <ChevronLeft size={24} />
              <span className="ml-1">Chat</span>
            </button>
            <h1 className="flex-1 text-center font-semibold text-gray-900 -ml-16">Settings</h1>
          </div>
        </div>

        {/* Settings Content */}
        <div className="flex-1 overflow-y-auto bg-gray-50">
          <div className="mt-8">
            {/* API Key Section */}
            <div className="bg-white border-y border-gray-200">
              <div className="px-4 py-3">
                <label className="block text-sm text-gray-500 mb-2">API Key</label>
                <input
                  type="password"
                  value={apiKey}
                  onChange={(e) => setApiKey(e.target.value)}
                  className="w-full px-0 py-1 text-base text-gray-900 bg-transparent border-none focus:outline-none"
                  placeholder="Enter API Key"
                />
              </div>
            </div>

            {/* Model Section */}
            <div className="mt-8 bg-white border-y border-gray-200">
              <div className="px-4 py-3 border-b border-gray-200">
                <label className="block text-sm text-gray-500 mb-2">Model</label>
                <select
                  value={model}
                  onChange={(e) => setModel(e.target.value)}
                  className="w-full px-0 py-1 text-base text-gray-900 bg-transparent border-none focus:outline-none"
                >
                  <option value="deepseek-chat">deepseek-chat</option>
                  <option value="deepseek-reasoner">deepseek-reasoner</option>
                </select>
              </div>

              <div className="px-4 py-3 border-b border-gray-200">
                <label className="block text-sm text-gray-500 mb-2">
                  Temperature: {temperature.toFixed(1)}
                </label>
                <input
                  type="range"
                  min="0"
                  max="2"
                  step="0.1"
                  value={temperature}
                  onChange={(e) => setTemperature(parseFloat(e.target.value))}
                  className="w-full h-1 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-blue-500"
                />
              </div>

              <div className="px-4 py-3">
                <label className="block text-sm text-gray-500 mb-2">Max Tokens</label>
                <input
                  type="number"
                  value={maxTokens}
                  onChange={(e) => setMaxTokens(parseInt(e.target.value))}
                  className="w-full px-0 py-1 text-base text-gray-900 bg-transparent border-none focus:outline-none"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-screen bg-white">
      {/* Header */}
      <div className="bg-white border-b border-gray-200">
        <div className="flex items-center justify-between px-4 h-14">
          <button
            onClick={clearChat}
            className="text-blue-500 font-normal"
          >
            Clear
          </button>
          <h1 className="font-semibold text-gray-900">DeepSeek</h1>
          <button
            onClick={() => setShowSettings(true)}
            className="text-blue-500"
          >
            <Settings size={22} />
          </button>
        </div>
      </div>

      {/* Chat Area */}
      <div className="flex-1 overflow-y-auto p-4">
        {messages.length === 0 ? (
          <div className="flex items-center justify-center h-full">
            <div className="text-center">
              <div className="w-16 h-16 bg-blue-500 rounded-full mx-auto mb-4 flex items-center justify-center">
                <Send className="text-white" size={28} />
              </div>
              <h2 className="text-xl font-semibold text-gray-900 mb-2">Welcome</h2>
              <p className="text-gray-500">Start a conversation</p>
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            {messages.map((msg, idx) => (
              <div
                key={idx}
                className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                <div
                  className={`max-w-xs px-4 py-2 rounded-3xl ${
                    msg.role === 'user'
                      ? 'bg-blue-500 text-white'
                      : msg.role === 'error'
                      ? 'bg-red-100 text-red-800'
                      : 'bg-gray-100 text-gray-900'
                  }`}
                >
                  <div className="whitespace-pre-wrap text-base leading-relaxed">{msg.content}</div>
                </div>
              </div>
            ))}
            {loading && (
              <div className="flex justify-start">
                <div className="bg-gray-100 px-4 py-2 rounded-3xl">
                  <div className="flex space-x-1">
                    <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
                    <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{animationDelay: '0.1s'}}></div>
                    <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{animationDelay: '0.2s'}}></div>
                  </div>
                </div>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Input Area */}
      <div className="border-t border-gray-200 bg-white p-4">
        <div className="flex items-center gap-2 bg-gray-100 rounded-full px-4 py-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && !e.shiftKey && sendMessage()}
            placeholder="Message"
            className="flex-1 bg-transparent border-none focus:outline-none text-base text-gray-900 placeholder-gray-400"
            disabled={loading}
          />
          <button
            onClick={sendMessage}
            disabled={loading || !input.trim()}
            className="text-blue-500 disabled:text-gray-300 transition-colors"
          >
            <Send size={22} />
          </button>
        </div>
      </div>
    </div>
  );
}