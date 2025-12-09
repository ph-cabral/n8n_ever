import { memo, useCallback } from "react";

const ChatInput = memo(
  ({ value, onChange, onSend, isLoading, inputRef }) => {
    const handleKeyDown = useCallback(
      (e) => {
        if (e.key === "Enter" && !e.shiftKey) {
          e.preventDefault();
          onSend();
        }
      },
      [onSend]
    );

    return (
      <div className="chat-input-container">
        <div className="chat-input-wrapper">
          <textarea
            ref={inputRef}
            className="chat-input"
            value={value}
            onChange={onChange}
            onKeyDown={handleKeyDown}
            placeholder="Escribe tu mensaje aquí..."
            rows={1}
            disabled={isLoading}
          />
          <button
            className="send-button"
            onClick={onSend}
            disabled={!value.trim() || isLoading}
          >
            Enviar
          </button>
        </div>
      </div>
    );
  },
  (prevProps, nextProps) => {
    // Solo re-renderizar si cambió el input o el estado de carga
    return (
      prevProps.value === nextProps.value &&
      prevProps.isLoading === nextProps.isLoading
    );
  }
);

ChatInput.displayName = "ChatInput";

export default ChatInput;
