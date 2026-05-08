import axios from "axios"
import { Send, User, Bot } from "lucide-react"
import { useState, useRef, useEffect } from "react"
import { CandidateCards } from "./components/candidatos"
import { parseN8nResponse } from "./utils/responsePorser"
// import { useTheme } from "./hooks/useTheme"
import ThemeToggle from "./components/ThemeToggle"
import useDragOverlay from "./hooks/useDragOverlay"
import FormattedMessage from "./components/FormattedMessage"
import UploadOverlay from "./components/Upload/UploadOverlay"
import DocumentValidation from "./components/DocumentValidation"
import QdrantCollectionManager from "./components/QdrantCollectionManager"


function App() {
  const [messages, setMessages] = useState([])
  const [input, setInput] = useState("")
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState(null)
  const messagesEndRef = useRef(null)
  const inputRef = useRef(null)

  const [view, setView] = useState("viki") // "viki" | "revision"

  const [uploadPopup, setUploadPopup] = useState(null)

  const [attachments, setAttachments] = useState([])

  const [candidatos, setCandidatos] = useState([])
  const [loadingCandidatos, setLoadingCandidatos] = useState(false)

  const url = import.meta.env.VITE_N8N_WEBHOOK_URL
  const files = import.meta.env.VITE_N8N_WEBHOOK_URL_FILES

  const isDragging = useDragOverlay()
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" })
  }

  useEffect(() => {
    scrollToBottom()
  }, [messages])

  const handleFileSelect = (e) => {
    const selectedFiles = Array.from(e.target.files)
    if (selectedFiles.length === 0) return

    setAttachments((prev) => [...prev, ...selectedFiles])

    // reset input para permitir seleccionar el mismo archivo de nuevo
    e.target.value = null
  }

  const handleSend = async () => {
    if ((!input.trim() && attachments.length === 0) || isLoading) return

    const userMessage = {
      role: "user",
      content: input.trim(),
      timestamp: new Date().toISOString(),
      attachments: attachments.map((file) => file.name),
    }

    // Añadir mensaje del usuario al chat
    setMessages((prev) => [...prev, userMessage])
    setInput("")
    setIsLoading(true)
    setError(null)

    try {
      // Enviar mensaje + adjuntos al webhook de n8n
      const formData = new FormData()
      formData.append("message", userMessage.content)
      formData.append("conversationHistory", JSON.stringify(messages))

      attachments.forEach((file) => {
        formData.append("file", file)
      })

      const response = await axios.post(url, formData, {
        headers: {
          "Content-Type": "multipart/form-data",
        },
      })

      const content = parseN8nResponse(response.data)

      const assistantMessage = {
        role: "assistant",
        content,
        timestamp: new Date().toISOString(),
      }

      setMessages((prev) => [...prev, assistantMessage])
    } catch (err) {
      console.error("Error al enviar mensaje:", err)

      const msg = err.response
        ? `Error del servidor: ${err.response.status}`
        : `Error de conexión: ${err.message}`

      setError(msg)
      setMessages((prev) => prev.slice(0, -1)) // quitar mensaje usuario si falló
    } finally {
      setIsLoading(false)
      setAttachments([]) // limpiar adjuntos tras enviar
      inputRef.current?.focus()
    }
  }

  const handleKeyDown = (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault()
      handleSend()
    }
  }

  const formatTime = (timestamp) => {
    const date = new Date(timestamp)
    return date.toLocaleTimeString("es-AR", {
      hour: "2-digit",
      minute: "2-digit",
    })
  }

  const handleDropFiles = async (e) => {
    if (!e.dataTransfer || !e.dataTransfer.files) return

    const droppedFiles = Array.from(e.dataTransfer.files)
    if (droppedFiles.length === 0) return

    try {
      // Procesar cada archivo
      const uploadPromises = droppedFiles.map((file) => {
        return new Promise((resolve, reject) => {
          const reader = new FileReader()

          reader.onload = async () => {
            try {
              // Extraer base64 (sin el prefijo "data:...")
              const base64Data = reader.result.split(",")[1]

              // Enviar a n8n
              const response = await axios.post(
                files,
                {
                  filename: file.name,
                  mimeType: file.type,
                  data: base64Data,
                  category: "general",
                  fileSize: file.size,
                },
                {
                  headers: {
                    "Content-Type": "application/json",
                  },
                },
              )

              resolve(response.data)
            } catch (error) {
              reject(error)
            }
          }

          reader.onerror = () => reject(reader.error)
          reader.readAsDataURL(file)
        })
      })

      // Esperar a que todos se suban
      await Promise.all(uploadPromises)

      setUploadPopup(droppedFiles.length)
      setTimeout(() => setUploadPopup(null), 3000)
    } catch (error) {
      console.error("Error subiendo archivos:", error)
      alert(`Error: ${error.message}`)
    }
  }

  useEffect(() => {
    const preventDefault = (e) => {
      e.preventDefault()
      e.stopPropagation()
    }

    window.addEventListener("dragover", preventDefault)

    return () => {
      window.removeEventListener("dragover", preventDefault)
    }
  }, [])

 
  useEffect(() => {
    if (view !== "candidatos") return

    setLoadingCandidatos(true)

    fetch("http://10-10-0-159.nip.io:5678/webhook-test/candidatos")
      .then((r) => r.json())
      .then((res) => setCandidatos(res.data ?? []))
      .finally(() => setLoadingCandidatos(false))
  }, [view])

  return (
    <div className="app-container">
      {/* BOTÓN ÚNICO */}
      <div className="view-switcher">
        {view === "viki" && (
          <div>
            <button className="switch-btn" onClick={() => setView("revision")}>
              📄 Revisión
            </button>
            <button className="switch-btn" onClick={() => setView("coleccion")}>
              📄 colecciones
            </button>
            <button
              className="switch-btn"
              onClick={() => setView("candidatos")}
            >
              👤 Candidatos
            </button>
          </div>
        )}

        {view === "revision" && (
          <div>
            <button className="switch-btn" onClick={() => setView("viki")}>
              💬 VIKI
            </button>
            <button className="switch-btn" onClick={() => setView("coleccion")}>
              📄 colecciones
            </button>
            <button
              className="switch-btn"
              onClick={() => setView("candidatos")}
            >
              👤 Candidatos
            </button>
          </div>
        )}

        {view === "coleccion" && (
          <div>
            <button className="switch-btn" onClick={() => setView("viki")}>
              💬 VIKI
            </button>
            <button className="switch-btn" onClick={() => setView("revision")}>
              📄 Revisión
            </button>
            <button
              className="switch-btn"
              onClick={() => setView("candidatos")}
            >
              👤 Candidatos
            </button>
          </div>
        )}

        {view === "candidatos" && (
          <div>
            <button className="switch-btn" onClick={() => setView("viki")}>
              💬 VIKI
            </button>
            <button className="switch-btn" onClick={() => setView("revision")}>
              📄 Revisión
            </button>
          </div>
        )}
      </div>
      {/* OVERLAY DRAG */}
      <UploadOverlay visible={isDragging} onDropFiles={handleDropFiles} />
      {/* POPUP UPLOAD */}
      {uploadPopup !== null && (
        <div className="upload-popup">
          {uploadPopup === 1
            ? "Se subió 1 archivo"
            : `Se subieron ${uploadPopup} archivos`}
        </div>
      )}
      {/* ===== VISTAS ===== */}
      {view === "viki" && (
        <div className="chat-container">
          <div className="chat-container">
            {/* Header */}
            <div className="chat-header">
              <ThemeToggle />
              <div className="header-left">
                <div className="header-icon">
                  <Bot size={20} />
                </div>
                <h1>VIKI</h1>
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
                      {msg.role === "user" ? (
                        <User size={20} />
                      ) : (
                        <Bot size={20} />
                      )}
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

            {/* Error message */}
            {error && <div className="error-message">{error}</div>}

            {/* Chat input */}
            <div className="chat-input-container">
              <div className="chat-input-wrapper">
                {attachments.length > 0 && (
                  <div className="attachments-banner">
                    📎 {attachments.length} archivo
                    {attachments.length > 1 ? "s" : ""} adjunto
                    {attachments.length > 1 ? "s" : ""}
                  </div>
                )}

                <label className="attach-button">
                  <input
                    type="file"
                    className="file-input"
                    multiple
                    onChange={handleFileSelect}
                  />
                  📎
                </label>

                {/* ⛔ YA NO SE MUESTRA UploadBox AQUÍ */}

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
      )}
      {view === "revision" && <DocumentValidation />}
      {view === "coleccion" && <QdrantCollectionManager />}
      {view === "candidatos" && (
        <div className="candidatos-view">
          {loadingCandidatos ? (
            <p>Cargando candidatos…</p>
          ) : (
            <CandidateCards data={candidatos} />
          )}
        </div>
      )}
    </div>
  )
}

export default App
