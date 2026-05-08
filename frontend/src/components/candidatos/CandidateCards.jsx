import { useState, useMemo } from "react";
import CandidateModal from "./CandidateModal"

export default function CandidateCards({ data }) {
  if (!Array.isArray(data)) return null;

  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState(null);

  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    return data.filter((d) => JSON.stringify(d).toLowerCase().includes(q));
  }, [data, search]);

  return (
    <div className="candidates-container">
      {/* Filtro global */}
      <input
        className="input-filter"
        placeholder="Filtrar por cualquier dato..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />

      {/* Grid de cartas */}
      <div className="candidates-grid">
        {filtered.map((candidate) => (
          <div
            key={candidate.id}
            className="candidate-card"
            onClick={() => setSelected(candidate)}
          >
            <div className="card-header">
              <img src={candidate.photo} className="card-photo" />
              <div className="card-info">
                <h3>{candidate.name}</h3>
                <p>{candidate.position}</p>
              </div>
            </div>

            <div className="card-content">
              <div className="card-meta">
                <span className="badge">{candidate.experience}</span>
                <span className="badge">{candidate.location}</span>
              </div>
              <p className="card-preview">{candidate.summary}</p>
            </div>

            <div className="card-footer">
              <button
                onClick={(e) => {
                  e.stopPropagation();
                }}
              >
                Ver perfil
              </button>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                }}
              >
                Contactar
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Modal */}
      {selected && (
        <CandidateModal item={selected} onClose={() => setSelected(null)} />
      )}
    </div>
  );
}
