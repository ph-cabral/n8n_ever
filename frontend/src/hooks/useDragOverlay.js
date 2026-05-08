import { useState, useEffect, useRef } from "react"

export default function useDragOverlay() {
  const [isDragging, setIsDragging] = useState(false)
  const dragCounter = useRef(0)

  useEffect(() => {
    const handleDragEnter = (e) => {
      e.preventDefault()
      dragCounter.current++
      setIsDragging(true)
    }

    const handleDragLeave = (e) => {
      e.preventDefault()
      dragCounter.current--
      if (dragCounter.current === 0) {
        setIsDragging(false)
      }
    }

    const handleDrop = (e) => {
      e.preventDefault()
      dragCounter.current = 0
      setIsDragging(false)
    }

    window.addEventListener("dragenter", handleDragEnter)
    window.addEventListener("dragleave", handleDragLeave)
    window.addEventListener("drop", handleDrop)
    window.addEventListener("dragover", (e) => e.preventDefault())

    return () => {
      window.removeEventListener("dragenter", handleDragEnter)
      window.removeEventListener("dragleave", handleDragLeave)
      window.removeEventListener("drop", handleDrop)
      window.removeEventListener("dragover", (e) => e.preventDefault())
    }
  }, [])

  return isDragging
}
