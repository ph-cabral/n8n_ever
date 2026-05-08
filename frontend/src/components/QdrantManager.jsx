import React, { useState, useEffect } from 'react'
import './qdrant-manager-styles.css'

const QdrantCollectionManager = () => {
  const [collections, setCollections] = useState([])
  const [loading, setLoading] = useState(true)
  const [showCreateModal, setShowCreateModal] = useState(false)
  const [selectedCollection, setSelectedCollection] = useState(null)
  const [error, setError] = useState(null)
  const [hoveredCard, setHoveredCard] = useState(null)

  // URL base de Qdrant - ajustar según tu configuración
  const QDRANT_URL = 'http://10.10.0.159:6333'

  // Estados del formulario de creación
  const [newCollection, setNewCollection] = useState({
    name: '',
    vector_size: 1536,
    distance: 'Cosine',
    hnsw_config: {
      m: 16,
      ef_construct: 100
    },
    optimizers_config: {
      default_segment_number: 0,
      memmap_threshold: null,
      indexing_threshold: 20000
    },
    wal_config: {
      wal_capacity_mb: 32,
      wal_segments_ahead: 0
    },
    quantization_config: null
  })

  // Plantillas predefinidas para diferentes tipos de colecciones
  const collectionTemplates = {
    talent_cvs: {
      name: 'talent_cvs',
      vector_size: 1536,
      distance: 'Cosine',
      description: 'CVs y perfiles de candidatos'
    },
    knowledge_base: {
      name: 'knowledge_base',
      vector_size: 1536, 
      distance: 'Cosine',
      description: 'Documentos de conocimiento general'
    },
    policies: {
      name: 'policies',
      vector_size: 1536,
      distance: 'Cosine',
      description: 'Políticas y procedimientos de RRHH'
    },
    custom: {
      name: '',
      vector_size: 1536,
      distance: 'Cosine',
      description: 'Colección personalizada'
    }
  }

  // Cargar colecciones al montar el componente
  useEffect(() => {
    fetchCollections()
  }, [])

  const fetchCollections = async () => {
    try {
      setLoading(true)
      const response = await fetch(`${QDRANT_URL}/collections`)
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      
      // Obtener detalles de cada colección
      const collectionsWithDetails = await Promise.all(
        Object.keys(data.result.collections).map(async (collectionName) => {
          try {
            const detailResponse = await fetch(`${QDRANT_URL}/collections/${collectionName}`)
            const detailData = await detailResponse.json()
            
            // Obtener número de puntos
            const countResponse = await fetch(`${QDRANT_URL}/collections/${collectionName}/points/count`)
            const countData = await countResponse.json()
            
            return {
              name: collectionName,
              ...detailData.result,
              points_count: countData.result?.count || 0
            }
          } catch (error) {
            console.error(`Error obteniendo detalles de ${collectionName}:`, error)
            return {
              name: collectionName,
              status: 'error',
              points_count: 0
            }
          }
        })
      )
      
      setCollections(collectionsWithDetails)
      setError(null)
    } catch (error) {
      console.error('Error cargando colecciones:', error)
      setError('Error conectando con Qdrant. Verifica que el servicio esté ejecutándose.')
    } finally {
      setLoading(false)
    }
  }

  const createCollection = async (collectionConfig) => {
    try {
      const payload = {
        vectors: {
          size: parseInt(collectionConfig.vector_size),
          distance: collectionConfig.distance
        },
        hnsw_config: collectionConfig.hnsw_config,
        optimizers_config: collectionConfig.optimizers_config,
        wal_config: collectionConfig.wal_config
      }

      if (collectionConfig.quantization_config) {
        payload.quantization_config = collectionConfig.quantization_config
      }

      const response = await fetch(`${QDRANT_URL}/collections/${collectionConfig.name}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload)
      })

      if (!response.ok) {
        throw new Error(`Error creando colección: ${response.status}`)
      }

      // Recargar colecciones
      await fetchCollections()
      setShowCreateModal(false)
      resetForm()
      
    } catch (error) {
      console.error('Error creando colección:', error)
      setError(`Error creando colección: ${error.message}`)
    }
  }

  const deleteCollection = async (collectionName) => {
    if (!window.confirm(`¿Estás seguro de que quieres eliminar la colección "${collectionName}"? Esta acción no se puede deshacer.`)) {
      return
    }

    try {
      const response = await fetch(`${QDRANT_URL}/collections/${collectionName}`, {
        method: 'DELETE'
      })

      if (!response.ok) {
        throw new Error(`Error eliminando colección: ${response.status}`)
      }

      await fetchCollections()
    } catch (error) {
      console.error('Error eliminando colección:', error)
      setError(`Error eliminando colección: ${error.message}`)
    }
  }

  const resetForm = () => {
    setNewCollection({
      name: '',
      vector_size: 1536,
      distance: 'Cosine',
      hnsw_config: {
        m: 16,
        ef_construct: 100
      },
      optimizers_config: {
        default_segment_number: 0,
        memmap_threshold: null,
        indexing_threshold: 20000
      },
      wal_config: {
        wal_capacity_mb: 32,
        wal_segments_ahead: 0
      },
      quantization_config: null
    })
  }

  const handleTemplateSelect = (templateKey) => {
    const template = collectionTemplates[templateKey]
    setNewCollection(prev => ({
      ...prev,
      name: template.name,
      vector_size: template.vector_size,
      distance: template.distance
    }))
  }

  const getCollectionIcon = (collectionName) => {
    if (collectionName.includes('talent') || collectionName.includes('cv')) {
      return (
        <svg className="icon-blue" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
        </svg>
      )
    } else if (collectionName.includes('knowledge') || collectionName.includes('doc')) {
      return (
        <svg className="icon-green" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
      )
    } else if (collectionName.includes('policies')) {
      return (
        <svg className="icon-purple" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
        </svg>
      )
    } else {
      return (
        <svg className="icon-orange" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
        </svg>
      )
    }
  }

  const getCollectionGradient = (collectionName) => {
    if (collectionName.includes('talent') || collectionName.includes('cv')) {
      return 'gradient-blue'
    } else if (collectionName.includes('knowledge') || collectionName.includes('doc')) {
      return 'gradient-green'
    } else if (collectionName.includes('policies')) {
      return 'gradient-purple'
    } else {
      return 'gradient-orange'
    }
  }

  const getStatusClass = (status) => {
    switch (status) {
      case 'green': return 'status-green'
      case 'yellow': return 'status-yellow'
      case 'red': return 'status-red'
      default: return 'status-gray'
    }
  }

  if (loading) {
    return (
      <div className="loading-container">
        <div className="loading-content">
          <div className="spinner-container">
            <div className="spinner"></div>
            <div className="spinner-ping"></div>
          </div>
          <div className="loading-text">
            <div className="loading-title">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="20" height="20">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
              </svg>
              Conectando con Qdrant
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" width="20" height="20">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <p className="loading-subtitle">Cargando colecciones vectoriales...</p>
            <div className="loading-dots">
              <div className="dot"></div>
              <div className="dot"></div>
              <div className="dot"></div>
            </div>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="qdrant-manager">
      {/* Elementos animados de fondo */}
      <div className="background-elements">
        <div className="blob blob-1"></div>
        <div className="blob blob-2"></div>
        <div className="blob blob-3"></div>
      </div>

      {/* Header */}
      <div className="header">
        <div className="header-content">
          <div className="logo-section">
            <div className="logo-icon">
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
              </svg>
              <div className="status-indicator"></div>
            </div>
            <div>
              <h1 className="header-title">Qdrant Collection Manager</h1>
              <p className="header-subtitle">Vector Database Management</p>
            </div>
          </div>
          <button
            onClick={() => setShowCreateModal(true)}
            className="primary-button"
          >
            <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
            </svg>
            Nueva Colección
          </button>
        </div>
      </div>

      {/* Contenido principal */}
      <div className="main-content">
        {/* Mensaje de error */}
        {error && (
          <div className="error-message">
            <div className="error-content">
              <div className="error-text">
                <p className="error-title">⚠️ Error de Conexión</p>
                <p>{error}</p>
              </div>
              <button
                onClick={() => setError(null)}
                className="error-close"
              >
                ×
              </button>
            </div>
          </div>
        )}

        {/* Estadísticas */}
        <div className="stats-grid">
          <div className="stat-card">
            <div className="stat-content">
              <div className="stat-icon blue">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
                </svg>
              </div>
              <div>
                <p className="stat-label">Total Colecciones</p>
                <p className="stat-value blue">{collections.length}</p>
              </div>
            </div>
          </div>
          
          <div className="stat-card">
            <div className="stat-content">
              <div className="stat-icon green">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                </svg>
              </div>
              <div>
                <p className="stat-label">Total Puntos</p>
                <p className="stat-value green">
                  {collections.reduce((acc, col) => acc + (col.points_count || 0), 0).toLocaleString()}
                </p>
              </div>
            </div>
          </div>
          
          <div className="stat-card">
            <div className="stat-content">
              <div className="stat-icon purple">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
              </div>
              <div>
                <p className="stat-label">Estado del Servicio</p>
                <p className="stat-value status-active">
                  Activo
                  <div className="status-indicator-small"></div>
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Grid de colecciones */}
        <div className="collections-grid">
          {collections.map((collection) => (
            <div
              key={collection.name}
              className="collection-card"
              onMouseEnter={() => setHoveredCard(collection.name)}
              onMouseLeave={() => setHoveredCard(null)}
            >
              {/* Gradiente de fondo */}
              <div className={`card-gradient ${getCollectionGradient(collection.name)}`}></div>
              
              {/* Borde animado */}
              <div className="card-border"></div>
              
              <div className="card-content">
                {/* Header */}
                <div className="card-header">
                  <div className="card-info">
                    <div className="card-icon">
                      {getCollectionIcon(collection.name)}
                      <div className="icon-status"></div>
                    </div>
                    <div>
                      <h3 className="card-title">{collection.name}</h3>
                      <span className={`card-status ${getStatusClass(collection.status)}`}>
                        ✨ {collection.status || 'active'}
                      </span>
                    </div>
                  </div>
                  
                  <div className="card-actions">
                    <button
                      onClick={() => setSelectedCollection(collection)}
                      className="action-button view"
                      title="Ver detalles"
                    >
                      <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                      </svg>
                    </button>
                    <button
                      onClick={() => deleteCollection(collection.name)}
                      className="action-button delete"
                      title="Eliminar"
                    >
                      <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </button>
                  </div>
                </div>

                {/* Stats */}
                <div className="card-stats">
                  <div className="stat-row">
                    <span className="stat-label">
                      <svg className="icon-yellow" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
                      </svg>
                      Puntos:
                    </span>
                    <span className="stat-value-small">{collection.points_count?.toLocaleString() || '0'}</span>
                  </div>
                  <div className="stat-row">
                    <span className="stat-label">
                      <svg className="icon-blue" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                      </svg>
                      Vector Size:
                    </span>
                    <span className="stat-value-small">{collection.config?.params?.vectors?.size || 'N/A'}</span>
                  </div>
                  <div className="stat-row">
                    <span className="stat-label">
                      <svg className="icon-green" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                      </svg>
                      Distancia:
                    </span>
                    <span className="stat-value-small">{collection.config?.params?.vectors?.distance || 'N/A'}</span>
                  </div>
                </div>

                {/* Footer */}
                <div className="card-footer">
                  <div className="footer-left">
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
                    </svg>
                    <span>Qdrant Collection</span>
                  </div>
                  {hoveredCard === collection.name && (
                    <div className="hover-dots">
                      <div className="dot"></div>
                      <div className="dot"></div>
                      <div className="dot"></div>
                    </div>
                  )}
                </div>
              </div>
            </div>
          ))}

          {/* Estado vacío */}
          {collections.length === 0 && (
            <div className="empty-state">
              <div className="empty-icon-container">
                <svg className="empty-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
                </svg>
                <div className="empty-ping"></div>
              </div>
              <h3 className="empty-title">��� ¡Comienza tu aventura vectorial!</h3>
              <p className="empty-description">
                No hay colecciones aún. Crea tu primera colección para comenzar a almacenar y buscar vectores de alta dimensión.
              </p>
              <button
                onClick={() => setShowCreateModal(true)}
                className="empty-button"
              >
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                </svg>
                Crear Primera Colección
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
                </svg>
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Modal de creación */}
      {showCreateModal && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <div className="modal-title-section">
                <h2>
                  <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                  </svg>
                  Crear Nueva Colección
                </h2>
                <p className="modal-subtitle">Configura tu nueva colección vectorial</p>
              </div>
              <button
                onClick={() => setShowCreateModal(false)}
                className="modal-close"
              >
                ×
              </button>
            </div>

            <div className="modal-body">
              {/* Selección de plantillas */}
              <div className="form-section">
                <label className="form-label">
                  <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
                  </svg>
                  Plantillas Predefinidas
                </label>
                <div className="templates-grid">
                  {Object.entries(collectionTemplates).map(([key, template]) => (
                    <button
                      key={key}
                      onClick={() => handleTemplateSelect(key)}
                      className="template-button"
                    >
                      <div className="template-name">{template.name || '��� Personalizada'}</div>
                      <div className="template-description">{template.description}</div>
                    </button>
                  ))}
                </div>
              </div>

              {/* Configuración básica */}
              <div className="form-section">
                <div>
                  <label className="form-label">
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
                    </svg>
                    Nombre de la Colección
                  </label>
                  <input
                    type="text"
                    value={newCollection.name}
                    onChange={(e) => setNewCollection(prev => ({ ...prev, name: e.target.value }))}
                    className="form-input"
                    placeholder="mi_coleccion_vectorial"
                    required
                  />
                </div>

                <div className="form-grid">
                  <div>
                    <label className="form-label">
                      <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                      </svg>
                      Tamaño del Vector
                    </label>
                    <input
                      type="number"
                      value={newCollection.vector_size}
                      onChange={(e) => setNewCollection(prev => ({ ...prev, vector_size: parseInt(e.target.value) }))}
                      className="form-input"
                      min="1"
                      required
                    />
                  </div>

                  <div>
                    <label className="form-label">
                      <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                      </svg>
                      Función de Distancia
                    </label>
                    <select
                      value={newCollection.distance}
                      onChange={(e) => setNewCollection(prev => ({ ...prev, distance: e.target.value }))}
                      className="form-input form-select"
                    >
                      <option value="Cosine">Cosine</option>
                      <option value="Euclidean">Euclidean</option>
                      <option value="Dot">Dot Product</option>
                    </select>
                  </div>
                </div>
              </div>

              {/* Configuración avanzada */}
              <details className="advanced-config">
                <summary className="advanced-summary">
                  <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                  Configuración Avanzada (Opcional)
                  <div>▼</div>
                </summary>
                <div className="advanced-content">
                  <div className="advanced-subsection">
                    <h4>
                      <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                      </svg>
                      HNSW Configuration
                    </h4>
                    <div className="advanced-grid">
                      <div>
                        <label className="advanced-label">M (Connections)</label>
                        <input
                          type="number"
                          value={newCollection.hnsw_config.m}
                          onChange={(e) => setNewCollection(prev => ({
                            ...prev,
                            hnsw_config: { ...prev.hnsw_config, m: parseInt(e.target.value) }
                          }))}
                          className="advanced-input"
                          min="2"
                        />
                      </div>
                      <div>
                        <label className="advanced-label">EF Construct</label>
                        <input
                          type="number"
                          value={newCollection.hnsw_config.ef_construct}
                          onChange={(e) => setNewCollection(prev => ({
                            ...prev,
                            hnsw_config: { ...prev.hnsw_config, ef_construct: parseInt(e.target.value) }
                          }))}
                          className="advanced-input"
                          min="1"
                        />
                      </div>
                    </div>
                  </div>
                </div>
              </details>
            </div>

            <div className="modal-footer">
              <button
                onClick={() => setShowCreateModal(false)}
                className="secondary-button"
              >
                Cancelar
              </button>
              <button
                onClick={() => createCollection(newCollection)}
                disabled={!newCollection.name.trim()}
                className="create-button"
              >
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                </svg>
                Crear Colección
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal de detalles */}
      {selectedCollection && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <div className="modal-title-section">
                <h2>
                  <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                  Detalles de {selectedCollection.name}
                </h2>
                <p className="modal-subtitle">Configuración y estadísticas de la colección</p>
              </div>
              <button
                onClick={() => setSelectedCollection(null)}
                className="modal-close"
              >
                ×
              </button>
            </div>

            <div className="modal-body">
              <div className="details-grid">
                <div className="detail-card">
                  <div className="detail-header">
                    <svg className="icon-green" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                    </svg>
                    <span className="detail-label">Estado:</span>
                  </div>
                  <span className={`card-status ${getStatusClass(selectedCollection.status)}`}>
                    ✨ {selectedCollection.status}
                  </span>
                </div>
                
                <div className="detail-card">
                  <div className="detail-header">
                    <svg className="icon-yellow" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
                    </svg>
                    <span className="detail-label">Puntos:</span>
                  </div>
                  <span className="detail-value blue">{selectedCollection.points_count?.toLocaleString()}</span>
                </div>
                
                <div className="detail-card">
                  <div className="detail-header">
                    <svg className="icon-blue" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                    </svg>
                    <span className="detail-label">Vector Size:</span>
                  </div>
                  <span className="detail-value green">{selectedCollection.config?.params?.vectors?.size}</span>
                </div>
                
                <div className="detail-card">
                  <div className="detail-header">
                    <svg className="icon-purple" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                    </svg>
                    <span className="detail-label">Distancia:</span>
                  </div>
                  <span className="detail-value purple">{selectedCollection.config?.params?.vectors?.distance}</span>
                </div>
              </div>

              {selectedCollection.config && (
                <div className="config-section">
                  <h4 className="config-title">
                    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                    Configuración Completa
                  </h4>
                  <div className="config-content">
                    <pre className="config-json">
                      {JSON.stringify(selectedCollection.config, null, 2)}
                    </pre>
                  </div>
                </div>
              )}
            </div>

            <div className="modal-footer">
              <button
                onClick={() => setSelectedCollection(null)}
                className="secondary-button"
              >
                Cerrar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default QdrantCollectionManager
