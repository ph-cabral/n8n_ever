// import { useState, useRef } from "react"
// import "../../styles/UploadBox.css"

// const WEBHOOK_URL = import.meta.env.VITE_N8N_UPLOAD_WEBHOOK_URL

// export default function UploadBox() {
//   const [files, setFiles] = useState([])
//   const [uploadedCount, setUploadedCount] = useState(0)

//   const fileInputRef = useRef(null)

//   // Drag & Drop handlers
//   const handleDragOver = (e) => {
//     e.preventDefault()
//     e.currentTarget.classList.add("dragover")
//   }

//   const handleDragLeave = (e) => {
//     e.preventDefault()
//     e.currentTarget.classList.remove("dragover")
//   }

//   const handleDrop = (e) => {
//     e.preventDefault()
//     e.currentTarget.classList.remove("dragover")
//     const droppedFiles = Array.from(e.dataTransfer.files)
//     addFiles(droppedFiles)
//   }

//   const handleFileSelect = (e) => {
//     const selectedFiles = Array.from(e.target.files)
//     addFiles(selectedFiles)
//     fileInputRef.current.value = ""
//   }

//   // Validación y agregado
//   const addFiles = (incoming) => {
//     const updated = [...files]

//     incoming.forEach((file) => {
//       if (updated.some((f) => f.file.name === file.name)) return

//       updated.push({
//         file,
//         id: Date.now() + Math.random(),
//         status: "pending",
//         progress: 0,
//       })
//     })

//     setFiles(updated)
//   }

//   // Subir archivos
//   const uploadAll = async () => {
//     for (const fileData of files.filter((f) => f.status === "pending")) {
//       await uploadFile(fileData)
//     }
//   }

//   const uploadFile = async (fileData) => {
//     fileData.status = "uploading"
//     fileData.progress = 10
//     setFiles([...files])

//     const formData = new FormData()
//     formData.append("data", fileData.file)
//     formData.append("filename", fileData.file.name)
//     formData.append("category", "general")
//     formData.append(
//       "metadata",
//       JSON.stringify({
//         uploadedAt: new Date().toISOString(),
//         size: fileData.file.size,
//         type: fileData.file.type,
//       })
//     )

//     try {
//       const res = await fetch(WEBHOOK_URL, {
//         method: "POST",
//         body: formData,
//       })

//       if (!res.ok) throw new Error("Error en subida")

//       fileData.status = "success"
//       fileData.progress = 100
//       setUploadedCount((count) => count + 1)
//     } catch (e) {
//       console.error(e)
//       fileData.status = "error"
//     }

//     setFiles([...files])
//   }

//   const removeFile = (id) => {
//     setFiles(files.filter((f) => f.id !== id))
//   }

//   return (
//     <div className="upload-container">
//       <h1>📁 Carga de Documentos</h1>
//       <p className="subtitle">Sistema de Gestión de RRHH</p>

//       <div
//         className="upload-area"
//         onClick={() => fileInputRef.current.click()}
//         onDragOver={handleDragOver}
//         onDragLeave={handleDragLeave}
//         onDrop={handleDrop}
//       >
//         <div className="upload-icon">☁️</div>
//         <div className="upload-text">
//           Arrastra archivos aquí o haz clic para seleccionar
//         </div>

//         <input
//           type="file"
//           multiple
//           ref={fileInputRef}
//           style={{ display: "none" }}
//           onChange={handleFileSelect}
//           accept=".pdf,.doc,.docx,.txt,.csv"
//         />
//       </div>

//       <div className="file-list">
//         {files.map((file) => (
//           <div className="file-item" key={file.id}>
//             <div className="file-info">
//               <div className="file-name">{file.file.name}</div>
//               <div className="file-size">
//                 {(file.file.size / 1024 / 1024).toFixed(2)} MB
//               </div>

//               {file.status === "uploading" && (
//                 <div className="progress-bar">
//                   <div
//                     className="progress-fill"
//                     style={{ width: `${file.progress}%` }}
//                   ></div>
//                 </div>
//               )}
//             </div>

//             <div className={`file-status status-${file.status}`}>
//               {file.status === "pending" && "Pendiente"}
//               {file.status === "uploading" && "Subiendo..."}
//               {file.status === "success" && "Completado"}
//               {file.status === "error" && "Error"}
//             </div>

//             {file.status === "pending" && (
//               <button
//                 className="remove-btn"
//                 onClick={() => removeFile(file.id)}
//               >
//                 ✕
//               </button>
//             )}
//           </div>
//         ))}
//       </div>

//       {files.length > 0 && (
//         <button className="upload-action-btn" onClick={uploadAll}>
//           Subir Archivos
//         </button>
//       )}
//     </div>
//   )
// }

import { useState, useRef } from "react"
import "../../styles/UploadBox.css"

const WEBHOOK_URL = import.meta.env.VITE_N8N_UPLOAD_WEBHOOK_URL

export default function UploadBox() {
  const [files, setFiles] = useState([])
  const [uploadedCount, setUploadedCount] = useState(0)

  const fileInputRef = useRef(null)

  // Drag & Drop handlers
  const handleDragOver = (e) => {
    e.preventDefault()
    e.currentTarget.classList.add("dragover")
  }

  const handleDragLeave = (e) => {
    e.preventDefault()
    e.currentTarget.classList.remove("dragover")
  }

  const handleDrop = (e) => {
    e.preventDefault()
    e.currentTarget.classList.remove("dragover")
    const droppedFiles = Array.from(e.dataTransfer.files)
    addFiles(droppedFiles)
  }

  const handleFileSelect = (e) => {
    const selectedFiles = Array.from(e.target.files)
    addFiles(selectedFiles)
    fileInputRef.current.value = ""
  }

  // Validación y agregado
  const addFiles = (incoming) => {
    const updated = [...files]

    incoming.forEach((file) => {
      if (updated.some((f) => f.file.name === file.name)) return

      updated.push({
        file,
        id: Date.now() + Math.random(),
        status: "pending",
        progress: 0,
      })
    })

    setFiles(updated)
  }

  // Subir archivos
  const uploadAll = async () => {
    for (const fileData of files.filter((f) => f.status === "pending")) {
      await uploadFile(fileData)
    }
  }

  const uploadFile = async (fileData) => {
    fileData.status = "uploading"
    fileData.progress = 10
    setFiles([...files])

    const formData = new FormData()
    formData.append("data", fileData.file)
    formData.append("filename", fileData.file.name)
    formData.append("category", "general")
    formData.append(
      "metadata",
      JSON.stringify({
        uploadedAt: new Date().toISOString(),
        size: fileData.file.size,
        type: fileData.file.type,
      }),
    )

    try {
      const res = await fetch(WEBHOOK_URL, {
        method: "POST",
        body: formData,
      })

      if (!res.ok) throw new Error("Error en subida")

      fileData.status = "success"
      fileData.progress = 100
      setUploadedCount((count) => count + 1)

      // ✅ Emitir evento personalizado para notificar que se subió un archivo
      window.dispatchEvent(
        new CustomEvent("documentUploaded", {
          detail: {
            filename: fileData.file.name,
            timestamp: new Date().toISOString(),
            size: fileData.file.size,
          },
        }),
      )
    } catch (e) {
      console.error(e)
      fileData.status = "error"
    }

    setFiles([...files])
  }

  const removeFile = (id) => {
    setFiles(files.filter((f) => f.id !== id))
  }

  return (
    <div className="upload-container">
      <h1>📄 Carga de Documentos</h1>
      <p className="subtitle">Sistema de Gestión de RRHH</p>

      <div
        className="upload-area"
        onClick={() => fileInputRef.current.click()}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
      >
        <div className="upload-icon">☁️</div>
        <div className="upload-text">
          Arrastra archivos aquí o haz clic para seleccionar
        </div>

        <input
          type="file"
          multiple
          ref={fileInputRef}
          style={{ display: "none" }}
          onChange={handleFileSelect}
          accept=".pdf,.doc,.docx,.txt,.csv"
        />
      </div>

      <div className="file-list">
        {files.map((file) => (
          <div className="file-item" key={file.id}>
            <div className="file-info">
              <div className="file-name">{file.file.name}</div>
              <div className="file-size">
                {(file.file.size / 1024 / 1024).toFixed(2)} MB
              </div>

              {file.status === "uploading" && (
                <div className="progress-bar">
                  <div
                    className="progress-fill"
                    style={{ width: `${file.progress}%` }}
                  ></div>
                </div>
              )}
            </div>

            <div className={`file-status status-${file.status}`}>
              {file.status === "pending" && "Pendiente"}
              {file.status === "uploading" && "Subiendo..."}
              {file.status === "success" && "Completado"}
              {file.status === "error" && "Error"}
            </div>

            {file.status === "pending" && (
              <button
                className="remove-btn"
                onClick={() => removeFile(file.id)}
              >
                ❌
              </button>
            )}
          </div>
        ))}
      </div>

      {files.length > 0 && (
        <button className="upload-action-btn" onClick={uploadAll}>
          Subir Archivos
        </button>
      )}
    </div>
  )
}