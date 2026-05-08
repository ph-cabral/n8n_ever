// src/hooks/useFileUpload.js
import { useState, useCallback } from 'react'
import { validateFile, uploadFile } from '../services/uploadService'

export const useFileUpload = () => {
  const [files, setFiles] = useState([])
  const [uploadedCount, setUploadedCount] = useState(0)
  const [isUploading, setIsUploading] = useState(false)

  const addFiles = useCallback((newFiles) => {
    const validatedFiles = []
    
    newFiles.forEach((file) => {
      const validation = validateFile(file)
      
      if (!validation.valid) {
        console.warn(`❌ ${file.name}: ${validation.error}`)
        return
      }

      // Evitar duplicados
      const isDuplicate = files.some(
        (f) => f.file.name === file.name && f.file.size === file.size
      )

      if (isDuplicate) {
        console.warn(`⚠️ ${file.name}: Ya existe`)
        return
      }

      validatedFiles.push({
        id: Date.now() + Math.random(),
        file,
        status: 'pending',
        progress: 0,
        error: null,
      })
    })

    setFiles((prev) => [...prev, ...validatedFiles])
    return validatedFiles.length
  }, [files])

  const removeFile = useCallback((id) => {
    setFiles((prev) => prev.filter((f) => f.id !== id))
  }, [])

  const clearAll = useCallback(() => {
    setFiles([])
    setUploadedCount(0)
  }, [])

  const uploadAllFiles = useCallback(async () => {
    const pendingFiles = files.filter((f) => f.status === 'pending')
    if (pendingFiles.length === 0) return

    setIsUploading(true)

    for (const fileData of pendingFiles) {
      setFiles((prev) =>
        prev.map((f) =>
          f.id === fileData.id
            ? { ...f, status: 'uploading', progress: 0 }
            : f
        )
      )

      try {
        // Simular progreso
        const progressInterval = setInterval(() => {
          setFiles((prev) =>
            prev.map((f) =>
              f.id === fileData.id && f.progress < 90
                ? { ...f, progress: f.progress + 10 }
                : f
            )
          )
        }, 200)

        await uploadFile(fileData.file)

        clearInterval(progressInterval)

        setFiles((prev) =>
          prev.map((f) =>
            f.id === fileData.id
              ? { ...f, status: 'success', progress: 100 }
              : f
          )
        )

        setUploadedCount((prev) => prev + 1)
      } catch (error) {
        setFiles((prev) =>
          prev.map((f) =>
            f.id === fileData.id
              ? { ...f, status: 'error', error: error.message }
              : f
          )
        )
      }
    }

    setIsUploading(false)
  }, [files])

  const stats = {
    total: files.length,
    totalSize: files.reduce((acc, f) => acc + f.file.size, 0),
    uploaded: uploadedCount,
    pending: files.filter((f) => f.status === 'pending').length,
  }

  return {
    files,
    stats,
    isUploading,
    addFiles,
    removeFile,
    clearAll,
    uploadAllFiles,
  }
}

