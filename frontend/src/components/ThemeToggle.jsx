import { useState, useEffect } from "react";
import { Sun, Moon } from "lucide-react";
import "../styles/theme-toggle.css";

const ThemeToggle = () => {
  const [theme, setTheme] = useState(() => {
    // Leer del localStorage o usar 'light' por defecto
    return localStorage.getItem("theme") || "light";
  });

  useEffect(() => {
    // Aplicar el tema al document
    document.documentElement.setAttribute("data-theme", theme);
    localStorage.setItem("theme", theme);
  }, [theme]);

  const toggleTheme = () => {
    setTheme((prevTheme) => (prevTheme === "light" ? "dark" : "light"));
  };

  return (
    <button
      className="theme-toggle"
      onClick={toggleTheme}
      aria-label={`Cambiar a modo ${theme === "light" ? "oscuro" : "claro"}`}
      title={`Modo ${theme === "light" ? "oscuro" : "claro"}`}
    >
      {theme === "light" ? <Moon size={20} /> : <Sun size={20} />}
    </button>
  );
};

export default ThemeToggle;
