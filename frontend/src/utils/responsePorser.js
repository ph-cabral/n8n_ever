/**
 * Extrae texto limpio de respuestas de n8n con múltiples formatos
 * @param {*} data - Respuesta de axios
 * @returns {string} - Texto limpio para renderizar
 */
export const parseN8nResponse = (data) => {
  // Caso 1: Array de objetos
  if (Array.isArray(data)) {
    if (data.length === 0) return "Sin respuesta del servidor";

    const first = data[0];
    return (
      first?.output ||
      first?.message ||
      first?.text ||
      first?.content ||
      first?.response ||
      JSON.stringify(first)
    );
  }

  // Caso 2: Objeto con propiedades conocidas
  if (typeof data === "object" && data !== null) {
    return (
      data.output ||
      data.message ||
      data.text ||
      data.content ||
      data.response ||
      data.data?.output ||
      data.data?.message ||
      JSON.stringify(data)
    );
  }

  // Caso 3: String directo
  if (typeof data === "string") {
    return data;
  }

  // Fallback
  return String(data) || "Respuesta no válida";
};
