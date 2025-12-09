// src/hooks/useTheme.js
import { useEffect, useState } from "react";

export const useTheme = () => {
  const [theme, setTheme] = useState(() => {
    return localStorage.getItem("theme") || "light";
  });

  useEffect(() => {
    const linkId = "bootswatch-theme";
    let link = document.getElementById(linkId);

    if (!link) {
      link = document.createElement("link");
      link.id = linkId;
      link.rel = "stylesheet";

      // 🔥 INSERTAR AL PRINCIPIO DEL <head> (antes que todo)
      const firstLink = document.head.querySelector("link");
      if (firstLink) {
        document.head.insertBefore(link, firstLink);
      } else {
        document.head.prepend(link); // Al inicio si no hay links
      }
    }

    // Cambiar tema
    link.href = theme === "dark" ? "/themes/dark.css" : "/themes/white.css";

    document.documentElement.setAttribute("data-theme", theme);
    localStorage.setItem("theme", theme);
  }, [theme]);

  const toggleTheme = () => {
    setTheme((prev) => (prev === "light" ? "dark" : "light"));
  };

  return { theme, toggleTheme };
};
