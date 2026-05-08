// src/components/FileUpload/UploadStats.jsx
import { formatBytes } from '../../services/uploadService'

const UploadStats = ({ stats }) => {
  return (
    <div className="upload-stats">
      <div className="stat-item">
        <div className="stat-value">{stats.total}</div>
        <div className="stat-label">Archivos</div>
      </div>
      
      <div className="stat-item">
        <div className="stat-value">{formatBytes(stats.totalSize)}</div>
        <div className="stat-label">Tamaño Total</div>
      </div>
      
      <div className="stat-item">
        <div className="stat-value">{stats.uploaded}</div>
        <div className="stat-label">Subidos</div>
      </div>
    </div>
  )
}

export default UploadStats

