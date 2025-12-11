import axios from "axios";
import { useState, useRef, useEffect } from "react";
import { Send, MessageSquare, User, Bot } from "lucide-react";
import { parseN8nResponse } from "./utils/responsePorser";
import FormattedMessage from "./components/FormattedMessage";
import ThemeToggle from "./components/ThemeToggle";
import { useTheme } from "./hooks/useTheme";
import ChatContainer from "./components/Chat/ChatContainer";

function App() {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);
  const messagesEndRef = useRef(null);
  const inputRef = useRef(null);

  const url = import.meta.env.VITE_N8N_WEBHOOK_URL;

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleSend = async () => {
    if (!input.trim() || isLoading) return;

    const userMessage = {
      role: "user",
      content: input.trim(),
      timestamp: new Date().toISOString(),
    };

    setMessages((prev) => [...prev, userMessage]);
    setInput("");
    setIsLoading(true);
    setError(null);

    try {
      const response = await axios.post(url, {
        message: userMessage.content,
        conversationHistory: messages,
      });

      const content = parseN8nResponse(response.data);

      const assistantMessage = {
        role: "assistant",
        content,
        timestamp: new Date().toISOString(),
      };

      setMessages((prev) => [...prev, assistantMessage]);
    } catch (err) {
      console.error("Error al enviar mensaje:", err);

      const msg = err.response
        ? `Error del servidor: ${err.response.status}`
        : `Error de conexión: ${err.message}`;

      setError(msg);
      setMessages((prev) => prev.slice(0, -1));
    } finally {
      setIsLoading(false);
      inputRef.current?.focus();
    }
  };

  const handleKeyDown = (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const formatTime = (timestamp) => {
    const date = new Date(timestamp);
    return date.toLocaleTimeString("es-AR", {
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  return (
    <div className="app-container">
      <div className="chat-container">
        {/* Header */}
        <div className="chat-header">
      <ThemeToggle />
          <div className="header-left">
            <div className="header-icon">
              <Bot size={20} />
            </div>
            <h1>MARI</h1>
          </div>
          <div className="status-badge">
            <div className="status-dot"></div>
            <span>Online</span>
          </div>
        </div>

        {/* Messages */}
        <div className="chat-messages">
          {messages.length === 0 ? (
            <div className="welcome-message">
              <h2>👋 ¡Hola! Soy tu asistente n8n</h2>
              <p>Preguntame lo que necesites y te ayudaré.</p>
            </div>
          ) : (
            messages.map((msg, idx) => (
              <div key={idx} className={`message ${msg.role}`}>
                <div className="message-avatar">
                  {msg.role === "user" ? <User size={20} /> : <Bot size={20} />}
                </div>
                <div className="message-content">
                  {msg.role === "assistant" ? (
                    <FormattedMessage content={msg.content} />
                  ) : (
                    <p>{msg.content}</p>
                  )}
                  <div className="message-time">
                    {formatTime(msg.timestamp)}
                  </div>
                </div>
              </div>
            ))
          )}

          {isLoading && (
            <div className="message assistant">
              <div className="message-avatar">
                <Bot size={20} />
              </div>
              <div className="message-content">
                <div className="typing-indicator">
                  <div className="typing-dot"></div>
                  <div className="typing-dot"></div>
                  <div className="typing-dot"></div>
                </div>
              </div>
            </div>
          )}

          <div ref={messagesEndRef} />
        </div>

        {error && <div className="error-message">{error}</div>}

        <div className="chat-input-container">
          <div className="chat-input-wrapper">
            <textarea
              ref={inputRef}
              className="chat-input"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Escribe tu mensaje aquí..."
              rows={1}
              disabled={isLoading}
            />
            <button
              className="send-button"
              onClick={handleSend}
              disabled={!input.trim() || isLoading}
            >
              <Send size={20} />
              Enviar
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
