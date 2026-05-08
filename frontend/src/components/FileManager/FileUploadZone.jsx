import { useState, useRef } from "react"
import {
  Upload,
  X,
  FileText,
  CheckCircle,
  AlertCircle,
  Loader,
} from "lucide-react"
import axios from "axios"

const ALLOWED_EXTENSIONS = ["pdf", "docx", "doc", "txt", "csv", "xlsx", "xls"]
const MAX_FILE_SIZE = 10 * 1024 * 1024 // 10MB

export default function UploadZone({ onUploadComplete }) {
  const [files, setFiles] = useState([])
  const [isDragging, setIsDragging] = useState(false)
  const fileInputRef = useRef(null)

  // ============================================
  // Manejadores de Drag & Drop
  // ============================================
  const handleDragOver = (e) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragging(true)
  }

  const handleDragLeave = (e) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragging(false)
  }

  const handleDrop = (e) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragging(false)

    const droppedFiles = Array.from(e.dataTransfer.files)
    addFiles(droppedFiles)
  }

  // ============================================
  // Manejador de Selección Manual
  // ============================================
  const handleFileSelect = (e) => {
    const selectedFiles = Array.from(e.target.files)
    addFiles(selectedFiles)
    fileInputRef.current.value = ""
  }

  // ============================================
  // Validación y Agregado de Archivos
  // ============================================
  const addFiles = (newFiles) => {
    const validatedFiles = newFiles.map((file) => {
      const ext = file.name.split(".").pop().toLowerCase()

      // Validar extensión
      if (!ALLOWED_EXTENSIONS.includes(ext)) {
        return {
          file,
          id: Date.now() + Math.random(),
          status: "error",
          error: "Tipo de archivo no permitido",
          progress: 0,
        }
      }

      // Validar tamaño
      if (file.size > MAX_FILE_SIZE) {
        return {
          file,
          id: Date.now() + Math.random(),
          status: "error",
          error: "Archivo muy grande (máx. 10MB)",
          progress: 0,
        }
      }

      // Verificar duplicados
      if (
        files.find(
          (f) => f.file.name === file.name && f.file.size === file.size
        )
      ) {
        return {
          file,
          id: Date.now() + Math.random(),
          status: "error",
          error: "Archivo ya agregado",
          progress: 0,
        }
      }

      return {
        file,
        id: Date.now() + Math.random(),
        status: "pending",
        progress: 0,
        error: null,
      }
    })

    setFiles((prev) => [...prev, ...validatedFiles])
  }

  // ============================================
  // Eliminar Archivo
  // ============================================
  const removeFile = (fileId) => {
    setFiles((prev) => prev.filter((f) => f.id !== fileId))
  }

  // ============================================
  // Subir Archivos a n8n
  // ============================================
  const uploadFiles = async () => {
    const pendingFiles = files.filter((f) => f.status === "pending")

    if (pendingFiles.length === 0) {
      alert("No hay archivos pendientes para subir")
      return
    }

    for (const fileObj of pendingFiles) {
      try {
        // Actualizar estado a "uploading"
        setFiles((prev) =>
          prev.map((f) =>
            f.id === fileObj.id ? { ...f, status: "uploading", progress: 0 } : f
          )
        )

        const formData = new FormData()
        formData.append("file", fileObj.file)
        formData.append("filename", fileObj.file.name)

        const response = await axios.post(
          import.meta.env.VITE_N8N_UPLOAD_WEBHOOK_URL,
          formData,
          {
            headers: {
              "Content-Type": "multipart/form-data",
            },
            onUploadProgress: (progressEvent) => {
              const progress = Math.round(
                (progressEvent.loaded * 100) / progressEvent.total
              )
              setFiles((prev) =>
                prev.map((f) => (f.id === fileObj.id ? { ...f, progress } : f))
              )
            },
          }
        )

        // Marcar como exitoso
        setFiles((prev) =>
          prev.map((f) =>
            f.id === fileObj.id ? { ...f, status: "success", progress: 100 } : f
          )
        )

        console.log("✅ Archivo subido:", response.data)
      } catch (error) {
        console.error("❌ Error subiendo archivo:", error)
        setFiles((prev) =>
          prev.map((f) =>
            f.id === fileObj.id
              ? {
                  ...f,
                  status: "error",
                  error:
                    error.response?.data?.message || "Error al subir archivo",
                }
              : f
          )
        )
      }
    }

    // Callback opcional
    if (onUploadComplete) {
      onUploadComplete(files.filter((f) => f.status === "success"))
    }
  }

  // ============================================
  // Render
  // ============================================
  return (
    <div className="upload-container">
      {/* Zona de Drag & Drop */}
      <div
        className={`upload-area ${isDragging ? "dragover" : ""}`}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onClick={() => fileInputRef.current?.click()}
      >
        <Upload className="upload-icon" size={48} />
        <div className="upload-text">
          Arrastra archivos aquí o haz clic para seleccionar
        </div>
        <div className="upload-hint">
          Soporta: PDF, DOCX, TXT, CSV, XLSX (máx. 10MB por archivo)
        </div>
        <input
          ref={fileInputRef}
          type="file"
          multiple
          accept=".pdf,.docx,.doc,.txt,.csv,.xlsx,.xls"
          onChange={handleFileSelect}
          style={{ display: "none" }}
        />
      </div>

      {/* Lista de Archivos */}
      {files.length > 0 && (
        <div className="files-list">
          {files.map((fileObj) => (
            <div
              key={fileObj.id}
              className={`file-item status-${fileObj.status}`}
            >
              <div className="file-icon">
                <FileText size={20} />
              </div>

              <div className="file-info">
                <div className="file-name">{fileObj.file.name}</div>
                <div className="file-size">
                  {(fileObj.file.size / 1024).toFixed(2)} KB
                </div>

                {fileObj.status === "uploading" && (
                  <div className="file-progress">
                    <div
                      className="progress-bar"
                      style={{ width: `${fileObj.progress}%` }}
                    />
                  </div>
                )}

                {fileObj.error && (
                  <div className="file-error">{fileObj.error}</div>
                )}
              </div>

              <div className="file-status">
                {fileObj.status === "pending" && (
                  <span className="status-badge pending">Pendiente</span>
                )}
                {fileObj.status === "uploading" && (
                  <Loader className="spinner" size={20} />
                )}
                {fileObj.status === "success" && (
                  <CheckCircle className="status-icon success" size={20} />
                )}
                {fileObj.status === "error" && (
                  <AlertCircle className="status-icon error" size={20} />
                )}
              </div>

              <button
                className="file-remove"
                onClick={(e) => {
                  e.stopPropagation()
                  removeFile(fileObj.id)
                }}
                disabled={fileObj.status === "uploading"}
              >
                <X size={16} />
              </button>
            </div>
          ))}
        </div>
      )}

      {/* Botones de Acción */}
      {files.length > 0 && (
        <div className="upload-actions">
          <button
            className="btn-secondary"
            onClick={() => setFiles([])}
            disabled={files.some((f) => f.status === "uploading")}
          >
            Limpiar Todo
          </button>
          <button
            className="btn-primary"
            onClick={uploadFiles}
            disabled={
              files.filter((f) => f.status === "pending").length === 0 ||
              files.some((f) => f.status === "uploading")
            }
          >
            Subir Archivos ({files.filter((f) => f.status === "pending").length}
            )
          </button>
        </div>
      )}
    </div>
  )
}
