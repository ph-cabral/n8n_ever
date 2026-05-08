// src/components/FileUpload/FileItem.jsx
import { memo } from 'react'
import { X, CheckCircle, AlertCircle, Loader2 } from 'lucide-react'
import { getFileIcon, formatBytes } from '../../services/uploadService'

const FileItem = memo(({ fileData, onRemove }) => {
  const { id, file, status, progress, error } = fileData

  const getStatusIcon = () => {
    switch (status) {
      case 'success':
        return <CheckCircle size={20} className="status-icon success" />
      case 'error':
        return <AlertCircle size={20} className="status-icon error" />
      case 'uploading':
        return <Loader2 size={20} className="status-icon uploading" />
      default:
        return null
    }
  }

  return (
    <div className={`file-item status-${status}`}>
      <div className="file-info">
        <div className="file-icon">{getFileIcon(file.name)}</div>
        
        <div className="file-details">
          <div className="file-name">{file.name}</div>
          <div className="file-size">{formatBytes(file.size)}</div>
          
          {status === 'uploading' && (
            <div className="progress-bar">
              <div className="progress-fill" style={{ width: `${progress}%` }} />
            </div>
          )}
          
          {status === 'error' && (
            <div className="file-error">{error}</div>
          )}
        </div>
      </div>

      <div className="file-actions">
        {getStatusIcon()}
        
        {status === 'pending' && (
          <button
            className="remove-btn"
            onClick={() => onRemove(id)}
            aria-label="Eliminar archivo"
          >
            <X size={16} />
          </button>
        )}
      </div>
    </div>
  )
})

FileItem.displayName = 'FileItem'

export default FileItem

