import { useState, useRef, useCallback, memo } from 'react';
import FormattedMessage from '../FormattedMessage';
import ChatInput from './ChatInpit';

// 🔥 Memoizar cada mensaje individual
const MessageItem = memo(({ msg, formatTime }) => {
    return (
        <div className={`message ${msg.role}`}>
            <div className="message-content">
                <FormattedMessage content={msg.content} />
                <div className="message-time">
                    {formatTime(msg.timestamp)}
                </div>
            </div>
        </div>
    );
}, (prevProps, nextProps) => {
    // Solo re-renderizar si cambió el mensaje
    return (
        prevProps.msg.id === nextProps.msg.id &&
        prevProps.msg.content === nextProps.msg.content
    );
});

MessageItem.displayName = 'MessageItem';

const ChatContainer = () => {
    const [messages, setMessages] = useState([]);
    const [input, setInput] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const inputRef = useRef(null);

    // 🔥 Memoizar función de formateo
    const formatTime = useCallback((timestamp) => {
        return new Date(timestamp).toLocaleTimeString('es-ES', {
            hour: '2-digit',
            minute: '2-digit',
        });
    }, []);

    // 🔥 Memoizar handler de input (evita recrear función)
    const handleInputChange = useCallback((e) => {
        setInput(e.target.value);
    }, []);

    const handleSend = async () => {
        if (!input.trim() || isLoading) return;

        const userMessage = {
            id: Date.now(),
            role: 'user',
            content: input.trim(),
            timestamp: Date.now(),
        };

        setMessages(prev => [...prev, userMessage]);
        setInput('');
        setIsLoading(true);

        try {
            const response = await sendMessage(input.trim(), sessionId);

            const botMessage = {
                id: Date.now() + 1,
                role: 'assistant',
                content: response.output || response.message || 'Sin respuesta',
                timestamp: Date.now(),
            };

            setMessages(prev => [...prev, botMessage]);
        } catch (error) {
            console.error('Error:', error);
            // Manejo de errores...
        } finally {
            setIsLoading(false);
        }
    };

    const handleKeyDown = useCallback((e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            handleSend();
        }
    }, [input, isLoading]); // 🔥 Dependencias necesarias

    return (
        <div className="chat-container">
            <div className="messages-container">
                <ChatInput
                    value={input}
                    onChange={handleInputChange}
                    onSend={handleSend}
                    isLoading={isLoading}
                    inputRef={inputRef}
                />
                {messages.map((msg) => (
                    <MessageItem
                        key={msg.id}
                        msg={msg}
                        formatTime={formatTime}
                    />
                ))}
                {isLoading && (
                    <div className="message assistant">
                        <div className="typing-indicator">
                            <span></span>
                            <span></span>
                            <span></span>
                        </div>
                    </div>
                )}
            </div>

            <div className="chat-input-container">
                <div className="chat-input-wrapper">
                    <textarea
                        ref={inputRef}
                        className="chat-input"
                        value={input}
                        onChange={handleInputChange}
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
                        Enviar
                    </button>
                </div>
            </div>
        </div>
    );
};

export default ChatContainer;
