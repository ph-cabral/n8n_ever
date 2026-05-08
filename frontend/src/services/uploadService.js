// src/services/uploadService.js
const WEBHOOK_URL = import.meta.env.VITE_N8N_UPLOAD_WEBHOOK_URL 

const MAX_FILE_SIZE = 10 * 1024 * 1024 // 10MB
const ALLOWED_EXTENSIONS = ['pdf', 'docx', 'doc', 'txt', 'csv']

export const validateFile = (file) => {
  const ext = file.name.split('.').pop().toLowerCase()
  
  if (!ALLOWED_EXTENSIONS.includes(ext)) {
    return { valid: false, error: 'Tipo de archivo no permitido' }
  }
  
  if (file.size > MAX_FILE_SIZE) {
    return { valid: false, error: 'Archivo muy grande (máx. 10MB)' }
  }
  
  return { valid: true }
}

export const uploadFile = async (file, onProgress) => {
  const formData = new FormData()
  formData.append('data', file)
  formData.append('filename', file.name)
  formData.append('category', 'general')
  formData.append('metadata', JSON.stringify({
    uploadedAt: new Date().toISOString(),
    size: file.size,
    type: file.type,
  }))

  try {
    const response = await fetch(WEBHOOK_URL, {
      method: 'POST',
      body: formData,
    })

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`)
    }

    return await response.json()
  } catch (error) {
    console.error('❌ Upload error:', error)
    throw error
  }
}

export const getFileIcon = (filename) => {
  const ext = filename.split('.').pop().toLowerCase()
  const icons = {
    pdf: '📄',
    docx: '📝',
    doc: '📝',
    txt: '📃',
    csv: '📊',
  }
  return icons[ext] || '📁'
}

export const formatBytes = (bytes) => {
  if (bytes === 0) return '0 Bytes'
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i]
}

