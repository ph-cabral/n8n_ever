import axios from "axios"
import { useState, useEffect } from "react"
import {
  CheckCircle,
  XCircle,
  FileText,
  Loader2,
  AlertCircle,
} from "lucide-react"

const DocumentValidation = () => {
  const [documents, setDocuments] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [processing, setProcessing] = useState({})
  const [actioned, setActioned] = useState({}) // {docId: {action: 'approved'|'rejected', data: {...}}

  // URLs de tus webhooks n8n (ajusta según tu configuración)
  const API_BASE =
    import.meta.env.VITE_N8N_WEBHOOK_URL_MOVE_FILES || "http://10-10-0-159.nip.io:5678/webhook"

  const ENDPOINTS = {
    list: `${API_BASE}/documentos-pendientes`,
    validate: `${API_BASE}-test/validar-documento`,
    reject: `${API_BASE}/reject-document/rechazar-documento`,
  }


  const fetchDocuments = async () => {
  try {
    setLoading(true)

    const response = await axios.get(ENDPOINTS.list)

    // n8n puede devolver { data: [...] } o directamente [...]
    const docs = response.data?.data || response.data || []

    setDocuments(Array.isArray(docs) ? docs : [])
    setError(null)

  } catch (err) {
    console.error("Error cargando documentos:", err)

    if (err.response?.data?.message === "No item to return was found") {
      setError("¡No hay archivos para validar!")
    } else {
      setError(
        err.response?.data?.message || "Error al cargar documentos"
      )
    }

  } finally {
    setLoading(false)
  }
}



  // Cargar documentos al montar el componente
  useEffect(() => {
    fetchDocuments()
  }, [])

  // ✅ Escuchar evento de archivo subido para refrescar automáticamente
  useEffect(() => {
    const handleDocumentUploaded = (event) => {
      console.log("Archivo subido detectado:", event.detail)
      // Refrescar después de un pequeño delay para dar tiempo al procesamiento
      setTimeout(() => {
        fetchDocuments()
      }, 1000)
    }

    window.addEventListener("documentUploaded", handleDocumentUploaded)

    return () => {
      window.removeEventListener("documentUploaded", handleDocumentUploaded)
    }
  }, [])

  // Aprobar documento
  const handleApprove = async (doc) => {
    setProcessing((prev) => ({ ...prev, [doc.id]: "approving" }))
    console.log(doc)
    try {
      await axios.post(ENDPOINTS.validate, {
        documento_id: doc.id,
        nombre_archivo: doc.nombre_archivo,
        tipo: doc.tipo,
        dominio: doc.dominio,
        hash_archivo: doc.hash_archivo,
      })

      // Guardar estado para poder deshacer
      setActioned((prev) => ({
        ...prev,
        [doc.id]: { action: "approved", data: doc },
      }))

      // NO remover de la lista inmediatamente
      setError(null)
    } catch (err) {
      console.error("Error aprobando documento:", err)
      setError(
        `Error al aprobar "${doc.nombre_archivo}": ${err.response?.data?.message || err.message}`,
      )
    } finally {
      setProcessing((prev) => {
        const { [doc.id]: _, ...rest } = prev
        return rest
      })
    }
  }

  // Rechazar documento
  const handleReject = async (doc) => {


    setProcessing((prev) => ({ ...prev, [doc.id]: "rejecting" }))

    try {
      await axios.delete(`${ENDPOINTS.reject}/${doc.id}`)

      // Guardar estado para poder deshacer
      setActioned((prev) => ({
        ...prev,
        [doc.id]: { action: "rejected", data: doc },
      }))

      // NO remover de la lista inmediatamente
      setError(null)
    } catch (err) {
      console.error("Error rechazando documento:", err)
      setError(
        `Error al rechazar "${doc.nombre_archivo}": ${err.response?.data?.message || err.message}`,
      )
    } finally {
      setProcessing((prev) => {
        const { [doc.id]: _, ...rest } = prev
        return rest
      })
    }
  }

  // Deshacer acción
  const handleUndo = async (docId) => {
    const actionData = actioned[docId]
    if (!actionData) return

    setProcessing((prev) => ({ ...prev, [docId]: "undoing" }))

    try {
      // Llamar endpoint de deshacer (revertir a PENDIENTE_VALIDACION)
      await axios.post(
        `${ENDPOINTS.validate.replace("validar-documento", "deshacer-accion")}`,
        {
          documento_id: docId,
          accion_previa: actionData.action,
        },
      )

      // Remover del estado de acciones
      setActioned((prev) => {
        const { [docId]: _, ...rest } = prev
        return rest
      })


      setError(null)
    } catch (err) {
      console.error("Error deshaciendo acción:", err)
      setError(
        `Error al deshacer: ${err.response?.data?.message || err.message}`,
      )
    } finally {
      setProcessing((prev) => {
        const { [docId]: _, ...rest } = prev
        return rest
      })
    }
  }

  // Descartar acción (remover definitivamente de la lista)
  const handleDiscard = (docId) => {
    setActioned((prev) => {
      const { [docId]: _, ...rest } = prev
      return rest
    })
    setDocuments((prev) => prev.filter((d) => d.id !== docId))
  }

  // Formatear tamaño
  const formatSize = (bytes) => {
    if (!bytes) return "N/A"
    const kb = bytes / 1024
    return kb > 1024 ? `${(kb / 1024).toFixed(1)} MB` : `${kb.toFixed(1)} KB`
  }

  // Truncar texto
  const truncate = (text, maxLength = 150) => {
    if (!text) return "Sin contenido"
    return text.length > maxLength
      ? text.substring(0, maxLength) + "..."
      : text
  }

  if (loading && documents.length === 0) {
    return (
      <div className="validation-container">
        <div className="validation-loading">
          <Loader2 className="spinner" size={40} />
          <p>Cargando documentos pendientes...</p>
        </div>
      </div>
    )
  }

  return (
    // <div className="validation-container">
    <div className="validation-container">
      {/* Header */}
      <div className="validation-header">
        <div className="header-left">
          <FileText size={24} />
          <h2>Validación de Documentos</h2>
          <span className="badge">{documents.length} pendientes</span>
        </div>
        <button
          className="refresh-btn"
          onClick={fetchDocuments}
          disabled={loading}
        >
          <Loader2 className={loading ? "spinner" : ""} size={18} />
          Actualizar
        </button>
      </div>

      {/* Error */}
      {error && (
        <div className="validation-error">
          <AlertCircle size={20} />
          <span>{error}</span>
          <button onClick={() => setError(null)}>×</button>
        </div>
      )}

      {/* Tabla */}
      {documents.length === 0 ? (
        <div className="validation-empty">
          <FileText size={48} opacity={0.3} />
          <p>No hay documentos pendientes de validación</p>
        </div>
      ) : (
        <div className="validation-table-wrapper">
          <table className="validation-table">
            <thead>
              <tr>
                <th>id</th>
                <th>Archivo</th>
                <th>Tipo</th>
                <th>Dominio</th>
                <th>Tamaño</th>
                <th>Vista previa</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              {documents.map((doc) => (
                <tr
                  key={doc.id}
                  className={processing[doc.id] ? "processing" : ""}
                >
                  <td>
                    <span className="type-badge">{doc.id || "N/A"}</span>
                  </td>
                  <td>
                    <div className="file-cell">
                      <FileText size={16} />
                      <span title={doc.nombre_archivo}>
                        {doc.nombre_archivo?.length > 30
                          ? doc.nombre_archivo.substring(0, 27) + "..."
                          : doc.nombre_archivo}
                      </span>
                    </div>
                  </td>
                  <td>
                    <span className="type-badge">{doc.tipo || "N/A"}</span>
                  </td>
                  <td>
                    <span className="domain-badge">{doc.dominio || "N/A"}</span>
                  </td>
                  <td>{formatSize(doc.tamanio_bytes)}</td>
                  <td>
                    <div className="preview-cell" title={doc.texto_limpio}>
                      {truncate(doc.texto_limpio)}
                    </div>
                  </td>
                  <td>
                    <div className="action-buttons">
                      {actioned[doc.id] ? (
                        // Mostrar botones de Deshacer y Confirmar
                        <>
                          <button
                            className="btn-undo"
                            onClick={() => handleUndo(doc.id)}
                            disabled={!!processing[doc.id]}
                            title="Deshacer acción"
                          >
                            {processing[doc.id] === "undoing" ? (
                              <Loader2 className="spinner" size={16} />
                            ) : (
                              "↶"
                            )}
                            Deshacer
                          </button>
                          <button
                            className="btn-confirm"
                            onClick={() => handleDiscard(doc.id)}
                            disabled={!!processing[doc.id]}
                            title="Confirmar y ocultar"
                          >
                            ✓ Confirmar
                          </button>
                          <span
                            className={`action-badge ${actioned[doc.id].action}`}
                          >
                            {actioned[doc.id].action === "approved"
                              ? "✓ Aprobado"
                              : "✗ Rechazado"}
                          </span>
                        </>
                      ) : (
                        // Mostrar botones normales
                        <>
                          <button
                            className="btn-approve"
                            onClick={() => handleApprove(doc)}
                            disabled={!!processing[doc.id]}
                            title="Aprobar documento"
                          >
                            {processing[doc.id] === "approving" ? (
                              <Loader2 className="spinner" size={16} />
                            ) : (
                              <CheckCircle size={16} />
                            )}
                            Aprobar
                          </button>
                          <button
                            className="btn-reject"
                            onClick={() => handleReject(doc)}
                            disabled={!!processing[doc.id]}
                            title="Rechazar documento"
                          >
                            {processing[doc.id] === "rejecting" ? (
                              <Loader2 className="spinner" size={16} />
                            ) : (
                              <XCircle size={16} />
                            )}
                            Rechazar
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

export default DocumentValidation