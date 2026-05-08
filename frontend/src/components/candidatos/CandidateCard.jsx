export default function CandidateCard({ item, onClick }) {
  return (
    <div className="candidate-card">
      {/* <img
        src="/avatar-placeholder.png"
        alt="preview"
        onClick={onClick}
        className="card-image"
      /> */}

      <div className="card-body">
        <h3>
          {item.nombre} {item.apellido}
        </h3>

        <span
          className={`status status-${item.estado_seleccion?.toLowerCase()}`}
        >
          {item.estado_seleccion}
        </span>
      </div>
    </div>
  );
}
