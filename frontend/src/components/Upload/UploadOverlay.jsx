import "../../styles/UploadOverlay.css"
import UploadBox from "./UploadBox"

export default function UploadOverlay({ visible, onDropFiles }) {
  if (!visible) return null

  return (
    <div
      className="upload-overlay"
      onDragOver={(e) => {
        e.preventDefault()
        e.stopPropagation()
      }}
      onDrop={(e) => {
        e.preventDefault()
        e.stopPropagation()

        onDropFiles(e)

        // 👉 cerrar overlay inmediatamente
        window.dispatchEvent(new Event("drop"))
      }}
    >
      <UploadBox />
    </div>
  )
}
