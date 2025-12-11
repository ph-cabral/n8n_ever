import React, { memo } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import "../styles/message-formatting.css";

// 🔥 MEMOIZAR para evitar re-renders innecesarios
const FormattedMessage = memo(
  ({ content }) => {
    const preprocessContent = (text) => {
      if (!text) return "";

      let processed = text.replace(/\\n/g, "\n");
      processed = processed.replace(/^(#{1,6})(\S)/gm, "$1 $2");
      processed = processed.replace(/^-(\S)/gm, "- $1");

      return processed;
    };

    const processedContent = preprocessContent(content);

    // 🔥 Memoizar los componentes personalizados
    const components = React.useMemo(
      () => ({
        h1: ({ children }) => <h2 className="formatted-title">{children}</h2>,
        h2: ({ children }) => (
          <h3 className="formatted-subtitle">{children}</h3>
        ),
        h3: ({ children }) => (
          <h4 className="formatted-subsubtitle">{children}</h4>
        ),
        p: ({ children }) => <p className="formatted-paragraph">{children}</p>,
        ul: ({ children }) => <ul className="formatted-list">{children}</ul>,
        ol: ({ children }) => (
          <ol className="formatted-list-numbered">{children}</ol>
        ),
        li: ({ children }) => (
          <li className="formatted-list-item">{children}</li>
        ),
        code: ({ inline, className, children }) => {
          if (inline) {
            return <code className="inline-code">{children}</code>;
          }

          const language = className?.replace("language-", "") || "plaintext";
          return (
            <pre className="code-block">
              <div className="code-header">
                <span className="code-language">{language}</span>
              </div>
              <code className={className}>{children}</code>
            </pre>
          );
        },
        strong: ({ children }) => (
          <strong className="formatted-bold">{children}</strong>
        ),
        em: ({ children }) => <em className="formatted-italic">{children}</em>,
        a: ({ href, children }) => (
          <a
            href={href}
            className="formatted-link"
            target="_blank"
            rel="noopener noreferrer"
          >
            {children}
          </a>
        ),
        blockquote: ({ children }) => (
          <blockquote className="formatted-quote">{children}</blockquote>
        ),
        table: ({ children }) => (
          <div className="table-wrapper">
            <table className="formatted-table">{children}</table>
          </div>
        ),
        hr: () => <hr className="formatted-divider" />,
      }),
      []
    ); // 🔥 Array vacío = se crea solo una vez

    return (
      <div className="formatted-message">
        <ReactMarkdown remarkPlugins={[remarkGfm]} components={components}>
          {processedContent}
        </ReactMarkdown>
      </div>
    );
  },
  (prevProps, nextProps) => {
    // 🔥 Solo re-renderizar si el contenido cambió
    return prevProps.content === nextProps.content;
  }
);

FormattedMessage.displayName = "FormattedMessage";

export default FormattedMessage;
