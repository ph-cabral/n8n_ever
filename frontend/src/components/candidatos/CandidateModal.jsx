// CandidateModal.jsx
export default function CandidateModal({ item, onClose }) {

  async function pasarAPersonal(id) {
    await fetch(
      `http://10-10-0-159.nip.io:5678/webhook/${id}/pasar-a-personal`,
      {
        method: "POST",
      },
    );
  }


  return (
    <div className="modal-backdrop">
      <div className="modal">
        <h2>Información completa</h2>

        <pre>
          {JSON.stringify(item.perfil, null, 2)}
        </pre>

        <div className="modal-actions">
          <button onClick={onClose}>Cerrar</button>

          <button
            className="btn-primary"
            onClick={() => pasarAPersonal(item.id)}
          >
            ➜ Pasar a Personal
          </button>
        </div>
      </div>
    </div>
  );
}

