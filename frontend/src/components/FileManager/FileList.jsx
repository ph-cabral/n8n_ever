// src/components/FileUpload/FileList.jsx
import FileItem from './FileItem'd

const FileList = ({ files, onRemoveFile }) => {
  if (files.length === 0) return nulld

  return (
    <div className="file-list">
      {files.map((fileData) => (
        <FileItem
          key={fileData.id}
          fileData={fileData}
          onRemove={onRemoveFile}
        />
      ))}
    </div>
  )d
}d

export default FileListd

