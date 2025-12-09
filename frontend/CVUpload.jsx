c// components/CVUpload.tsx
import { useState } from "react";
import axios from "axios";

export function CVUploadForm() {
  const [file, setFile] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!file) return;

    const formData = new FormData();
    formData.append("file", file);
    formData.append("source", "manual_upload");
    formData.append("uploaded_by", "rrhh@everwear.com.ar");

    setLoading(true);
    try {
      const response = await axios.post(
        "http://n8n.everwear.local:5678/webhook/cv-upload",
        formData,
        {
          headers: {
            "Content-Type": "multipart/form-data",
            "X-API-Key": process.env.VITE_N8N_API_KEY,
          },
        }
      );

      console.log("CV procesado:", response.data);
      alert("CV procesado exitosamente");
    } catch (error) {
      console.error("Error:", error);
      alert("Error al procesar CV");
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label className="block text-sm font-medium mb-2">
          Subir documento de entrevista (DOCX)
        </label>
        <input
          type="file"
          accept=".docx"
          onChange={(e) => setFile(e.target.files?.[0] || null)}
          className="border rounded px-3 py-2 w-full"
        />
      </div>
      <button
        type="submit"
        disabled={!file || loading}
        className="bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700 disabled:opacity-50"
      >
        {loading ? "Procesando..." : "Generar CVs"}
      </button>
    </form>
  );
}
