--
-- PostgreSQL database dump
--

\restrict 5WxhQ1w7KbKJiY9T98GRfua3EvNfxlgddaUpTmwEJ6MtJfFX3arAe0YRj11UOWP

-- Dumped from database version 15.15 (Debian 15.15-1.pgdg12+1)
-- Dumped by pg_dump version 15.15 (Debian 15.15-1.pgdg12+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: n8n
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO n8n;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: n8n
--

COMMENT ON SCHEMA public IS '';


--
-- Name: rag_system; Type: SCHEMA; Schema: -; Owner: n8n
--

CREATE SCHEMA rag_system;


ALTER SCHEMA rag_system OWNER TO n8n;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA rag_system;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: dominio_documento; Type: TYPE; Schema: rag_system; Owner: n8n
--

CREATE TYPE rag_system.dominio_documento AS ENUM (
    'CANDIDATOS',
    'PERSONAL',
    'KNOWLEDGE_BASE',
    'CONOCIMIENTO'
);


ALTER TYPE rag_system.dominio_documento OWNER TO n8n;

--
-- Name: estado_documento; Type: TYPE; Schema: rag_system; Owner: n8n
--

CREATE TYPE rag_system.estado_documento AS ENUM (
    'PENDIENTE',
    'PROCESANDO',
    'PENDIENTE_VALIDACION',
    'APROBADO',
    'RECHAZADO'
);


ALTER TYPE rag_system.estado_documento OWNER TO n8n;

--
-- Name: fuente_ingesta; Type: TYPE; Schema: rag_system; Owner: n8n
--

CREATE TYPE rag_system.fuente_ingesta AS ENUM (
    'EMAIL',
    'UPLOAD_WEB',
    'API',
    'MIGRACION'
);


ALTER TYPE rag_system.fuente_ingesta OWNER TO n8n;

--
-- Name: tipo_documento; Type: TYPE; Schema: rag_system; Owner: n8n
--

CREATE TYPE rag_system.tipo_documento AS ENUM (
    'CV',
    'PERFIL_ENTREVISTA',
    'PERFIL_PUESTO',
    'CERTIFICADO',
    'CARTA_PRESENTACION',
    'INSTRUCTIVO',
    'PROCEDIMIENTO',
    'POLITICA_RRHH',
    'OTRO'
);


ALTER TYPE rag_system.tipo_documento OWNER TO n8n;

--
-- Name: tipo_relacion_documento; Type: TYPE; Schema: rag_system; Owner: n8n
--

CREATE TYPE rag_system.tipo_relacion_documento AS ENUM (
    'CV_PRINCIPAL',
    'CERTIFICADO',
    'ENTREVISTA',
    'EVALUACION',
    'OTRO'
);


ALTER TYPE rag_system.tipo_relacion_documento OWNER TO n8n;

--
-- Name: increment_workflow_version(); Type: FUNCTION; Schema: public; Owner: n8n
--

CREATE FUNCTION public.increment_workflow_version() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
			BEGIN
				IF NEW."versionCounter" IS NOT DISTINCT FROM OLD."versionCounter" THEN
					NEW."versionCounter" = OLD."versionCounter" + 1;
				END IF;
				RETURN NEW;
			END;
			$$;


ALTER FUNCTION public.increment_workflow_version() OWNER TO n8n;

--
-- Name: actualizar_hash_candidato(); Type: FUNCTION; Schema: rag_system; Owner: n8n
--

CREATE FUNCTION rag_system.actualizar_hash_candidato() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.hash_candidato := rag_system.calcular_hash_candidato(
    NEW.nombre,
    NEW.apellido,
    NEW.email,
    NEW.telefono
  );
  RETURN NEW;
END;
$$;


ALTER FUNCTION rag_system.actualizar_hash_candidato() OWNER TO n8n;

--
-- Name: aprobar_documento(integer, integer, jsonb, integer); Type: FUNCTION; Schema: rag_system; Owner: n8n
--

CREATE FUNCTION rag_system.aprobar_documento(p_staging_id integer, p_candidato_id integer DEFAULT NULL::integer, p_datos_estructurados jsonb DEFAULT '{}'::jsonb, p_aprobado_por integer DEFAULT NULL::integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_documento_aprobado_id INT;
    v_staging_record RECORD;
BEGIN
    -- Obtener el documento de staging
    SELECT * INTO v_staging_record 
    FROM rag_system.documento_staging 
    WHERE id = p_staging_id AND estado IN ('PENDIENTE', 'PROCESANDO', 'PENDIENTE_VALIDACION');
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Documento staging no encontrado o ya procesado: %', p_staging_id;
    END IF;
    
    -- Insertar en documento_aprobado
    INSERT INTO rag_system.documento_aprobado (
        hash_archivo,
        nombre_archivo,
        mime_type,
        tamanio_bytes,
        texto_raw,
        texto_limpio,
        tipo_documento,
        dominio,
        candidato_id,
        datos_estructurados,
        metadata,
        fuente,
        creado_por,
        created_at,
        aprobado_por,
        aprobado_at
    ) VALUES (
        v_staging_record.hash_archivo,
        v_staging_record.nombre_archivo,
        v_staging_record.mime_type,
        v_staging_record.tamanio_bytes,
        v_staging_record.texto_raw,
        v_staging_record.texto_limpio,
        v_staging_record.tipo_preliminar,
        v_staging_record.dominio_preliminar,
        p_candidato_id,
        p_datos_estructurados,
        v_staging_record.metadata || jsonb_build_object(
            'aprobado_automaticamente', CASE WHEN p_aprobado_por IS NULL THEN true ELSE false END,
            'confianza_clasificacion', v_staging_record.confianza_clasificacion
        ),
        v_staging_record.fuente,
        v_staging_record.creado_por,
        v_staging_record.created_at,
        p_aprobado_por,
        NOW()
    ) RETURNING id INTO v_documento_aprobado_id;
    
    -- Actualizar staging con referencia (para auditoría temporal)
    UPDATE rag_system.documento_staging 
    SET 
        documento_aprobado_id = v_documento_aprobado_id,
        estado = 'APROBADO',
        updated_at = NOW()
    WHERE id = p_staging_id;
    
    -- Eliminar de staging después de un delay (para permitir que el workflow termine)
    -- Esto se hace mejor desde n8n con un delay
    
    RETURN v_documento_aprobado_id;
END;
$$;


ALTER FUNCTION rag_system.aprobar_documento(p_staging_id integer, p_candidato_id integer, p_datos_estructurados jsonb, p_aprobado_por integer) OWNER TO n8n;

--
-- Name: calcular_hash_candidato(text, text, text, text); Type: FUNCTION; Schema: rag_system; Owner: n8n
--

CREATE FUNCTION rag_system.calcular_hash_candidato(p_nombre text, p_apellido text, p_email text, p_telefono text) RETURNS character
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
  RETURN encode(
    digest(
      COALESCE(p_nombre, '') || '|' ||
      COALESCE(p_apellido, '') || '|' ||
      COALESCE(p_email, '') || '|' ||
      COALESCE(p_telefono, ''),
      'sha256'
    ),
    'hex'
  )::CHAR(64);
END;
$$;


ALTER FUNCTION rag_system.calcular_hash_candidato(p_nombre text, p_apellido text, p_email text, p_telefono text) OWNER TO n8n;

--
-- Name: limpiar_staging_aprobados(); Type: FUNCTION; Schema: rag_system; Owner: n8n
--

CREATE FUNCTION rag_system.limpiar_staging_aprobados() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_eliminados INT := 0;
BEGIN
    -- Eliminar documentos que ya fueron aprobados hace más de 1 hora
    DELETE FROM rag_system.documento_staging 
    WHERE estado = 'APROBADO' 
      AND documento_aprobado_id IS NOT NULL 
      AND updated_at < NOW() - INTERVAL '1 hour';
    
    GET DIAGNOSTICS v_eliminados = ROW_COUNT;
    
    RETURN v_eliminados;
END;
$$;


ALTER FUNCTION rag_system.limpiar_staging_aprobados() OWNER TO n8n;

--
-- Name: rechazar_documento(integer, text, integer); Type: FUNCTION; Schema: rag_system; Owner: n8n
--

CREATE FUNCTION rag_system.rechazar_documento(p_staging_id integer, p_motivo text, p_rechazado_por integer DEFAULT NULL::integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_documento_rechazado_id INT;
    v_staging_record RECORD;
BEGIN
    -- Obtener el documento de staging
    SELECT * INTO v_staging_record 
    FROM rag_system.documento_staging 
    WHERE id = p_staging_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Documento staging no encontrado: %', p_staging_id;
    END IF;
    
    -- Insertar en documento_rechazado
    INSERT INTO rag_system.documento_rechazado (
        hash_archivo,
        nombre_archivo,
        mime_type,
        tamanio_bytes,
        texto_raw,
        texto_limpio,
        tipo_preliminar,
        dominio_preliminar,
        confianza_clasificacion,
        motivo_rechazo,
        metadata,
        fuente,
        creado_por,
        rechazado_por,
        created_at,
        rechazado_at
    ) VALUES (
        v_staging_record.hash_archivo,
        v_staging_record.nombre_archivo,
        v_staging_record.mime_type,
        v_staging_record.tamanio_bytes,
        v_staging_record.texto_raw,
        v_staging_record.texto_limpio,
        v_staging_record.tipo_preliminar,
        v_staging_record.dominio_preliminar,
        v_staging_record.confianza_clasificacion,
        p_motivo,
        v_staging_record.metadata,
        v_staging_record.fuente,
        v_staging_record.creado_por,
        p_rechazado_por,
        v_staging_record.created_at,
        NOW()
    ) RETURNING id INTO v_documento_rechazado_id;
    
    -- Eliminar de staging
    DELETE FROM rag_system.documento_staging WHERE id = p_staging_id;
    
    RETURN v_documento_rechazado_id;
END;
$$;


ALTER FUNCTION rag_system.rechazar_documento(p_staging_id integer, p_motivo text, p_rechazado_por integer) OWNER TO n8n;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: rag_system; Owner: n8n
--

CREATE FUNCTION rag_system.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION rag_system.update_updated_at_column() OWNER TO n8n;

--
-- Name: upsert_candidato(text, text, text, text, jsonb, text); Type: FUNCTION; Schema: rag_system; Owner: n8n
--

CREATE FUNCTION rag_system.upsert_candidato(p_nombre text, p_apellido text, p_email text, p_telefono text, p_perfil jsonb, p_fuente_original text DEFAULT 'cv_ingesta'::text) RETURNS TABLE(id integer, nombre text, apellido text, email text, telefono text, perfil jsonb, fuente_original text, estado_seleccion text, created_at timestamp without time zone, updated_at timestamp without time zone, candidato_uuid uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'rag_system', 'public'
    AS $$
DECLARE
  v_email_final TEXT;
  v_nombre_clean TEXT;
  v_apellido_clean TEXT;
  v_telefono_clean TEXT;
  v_candidato_id INT;
BEGIN
  -- ========================================
  -- PASO 1: Limpiar valores (TRIM + NULLIF)
  -- ========================================
  v_nombre_clean := NULLIF(TRIM(COALESCE(p_nombre, '')), '');
  v_apellido_clean := NULLIF(TRIM(COALESCE(p_apellido, '')), '');
  v_email_final := NULLIF(TRIM(COALESCE(p_email, '')), '');
  v_telefono_clean := NULLIF(TRIM(COALESCE(p_telefono, '')), '');
  
  -- Si email está vacío, generar uno temporal
  IF v_email_final IS NULL THEN
    v_email_final := 'temp_' || gen_random_uuid()::TEXT;
  END IF;
  
  -- ========================================
  -- PASO 2: UPSERT (Insertar o actualizar)
  -- ========================================
  INSERT INTO rag_system.candidato (
    nombre,
    apellido,
    email,
    telefono,
    perfil,
    fuente_original,
    estado_seleccion,
    created_at,
    updated_at
  ) VALUES (
    v_nombre_clean,
    v_apellido_clean,
    v_email_final,
    v_telefono_clean,
    COALESCE(p_perfil, '{}'::JSONB),
    COALESCE(p_fuente_original, 'cv_ingesta'),
    'NUEVO',
    NOW(),
    NOW()
  )
  ON CONFLICT (email) DO UPDATE SET
    nombre = CASE 
               WHEN v_nombre_clean IS NOT NULL THEN v_nombre_clean 
               ELSE candidato.nombre 
             END,
    apellido = CASE 
                 WHEN v_apellido_clean IS NOT NULL THEN v_apellido_clean 
                 ELSE candidato.apellido 
               END,
    telefono = CASE 
                 WHEN v_telefono_clean IS NOT NULL THEN v_telefono_clean 
                 ELSE candidato.telefono 
               END,
    perfil = COALESCE(p_perfil, candidato.perfil),
    updated_at = NOW();
  
  -- ========================================
  -- PASO 3: Retornar el registro insertado/actualizado
  -- ========================================
  RETURN QUERY
  SELECT
    c.id,
    c.nombre,
    c.apellido,
    c.email,
    c.telefono,
    c.perfil,
    c.fuente_original,
    c.estado_seleccion,
    c.created_at,
    c.updated_at,
    c.candidato_uuid
  FROM rag_system.candidato c
  WHERE c.email = v_email_final
  ORDER BY c.updated_at DESC
  LIMIT 1;
    
END;
$$;


ALTER FUNCTION rag_system.upsert_candidato(p_nombre text, p_apellido text, p_email text, p_telefono text, p_perfil jsonb, p_fuente_original text) OWNER TO n8n;

--
-- Name: FUNCTION upsert_candidato(p_nombre text, p_apellido text, p_email text, p_telefono text, p_perfil jsonb, p_fuente_original text); Type: COMMENT; Schema: rag_system; Owner: n8n
--

COMMENT ON FUNCTION rag_system.upsert_candidato(p_nombre text, p_apellido text, p_email text, p_telefono text, p_perfil jsonb, p_fuente_original text) IS 'Inserta un nuevo candidato o actualiza uno existente (basado en email).
RETORNA: Los datos del candidato creado/actualizado.

Parámetros:
- p_nombre: Nombre del candidato
- p_apellido: Apellido del candidato
- p_email: Email (si es NULL, se genera temporal)
- p_telefono: Teléfono
- p_perfil: Objeto JSONB con datos del perfil
- p_fuente_original: Origen (default: "cv_ingesta")

Ejemplo de uso:
  SELECT * FROM rag_system.upsert_candidato(
    ''Juan'', ''Pérez'', ''juan@example.com'', ''1234567890'',
    ''{}'':JSONB, ''cv_ingesta''
  );
';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: annotation_tag_entity; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.annotation_tag_entity (
    id character varying(16) NOT NULL,
    name character varying(24) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.annotation_tag_entity OWNER TO n8n;

--
-- Name: auth_identity; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.auth_identity (
    "userId" uuid,
    "providerId" character varying(64) NOT NULL,
    "providerType" character varying(32) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.auth_identity OWNER TO n8n;

--
-- Name: auth_provider_sync_history; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.auth_provider_sync_history (
    id integer NOT NULL,
    "providerType" character varying(32) NOT NULL,
    "runMode" text NOT NULL,
    status text NOT NULL,
    "startedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "endedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    scanned integer NOT NULL,
    created integer NOT NULL,
    updated integer NOT NULL,
    disabled integer NOT NULL,
    error text
);


ALTER TABLE public.auth_provider_sync_history OWNER TO n8n;

--
-- Name: auth_provider_sync_history_id_seq; Type: SEQUENCE; Schema: public; Owner: n8n
--

CREATE SEQUENCE public.auth_provider_sync_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auth_provider_sync_history_id_seq OWNER TO n8n;

--
-- Name: auth_provider_sync_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: n8n
--

ALTER SEQUENCE public.auth_provider_sync_history_id_seq OWNED BY public.auth_provider_sync_history.id;


--
-- Name: binary_data; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.binary_data (
    "fileId" uuid NOT NULL,
    "sourceType" character varying(50) NOT NULL,
    "sourceId" character varying(255) NOT NULL,
    data bytea NOT NULL,
    "mimeType" character varying(255),
    "fileName" character varying(255),
    "fileSize" integer NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    CONSTRAINT "CHK_binary_data_sourceType" CHECK ((("sourceType")::text = ANY ((ARRAY['execution'::character varying, 'chat_message_attachment'::character varying])::text[])))
);


ALTER TABLE public.binary_data OWNER TO n8n;

--
-- Name: COLUMN binary_data."sourceType"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.binary_data."sourceType" IS 'Source the file belongs to, e.g. ''execution''';


--
-- Name: COLUMN binary_data."sourceId"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.binary_data."sourceId" IS 'ID of the source, e.g. execution ID';


--
-- Name: COLUMN binary_data.data; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.binary_data.data IS 'Raw, not base64 encoded';


--
-- Name: COLUMN binary_data."fileSize"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.binary_data."fileSize" IS 'In bytes';


--
-- Name: chat_hub_agents; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.chat_hub_agents (
    id uuid NOT NULL,
    name character varying(256) NOT NULL,
    description character varying(512),
    "systemPrompt" text NOT NULL,
    "ownerId" uuid NOT NULL,
    "credentialId" character varying(36),
    provider character varying(16) NOT NULL,
    model character varying(64) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    tools json DEFAULT '[]'::json NOT NULL
);


ALTER TABLE public.chat_hub_agents OWNER TO n8n;

--
-- Name: COLUMN chat_hub_agents.provider; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.chat_hub_agents.provider IS 'ChatHubProvider enum: "openai", "anthropic", "google", "n8n"';


--
-- Name: COLUMN chat_hub_agents.model; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.chat_hub_agents.model IS 'Model name used at the respective Model node, ie. "gpt-4"';


--
-- Name: COLUMN chat_hub_agents.tools; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.chat_hub_agents.tools IS 'Tools available to the agent as JSON node definitions';


--
-- Name: chat_hub_messages; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.chat_hub_messages (
    id uuid NOT NULL,
    "sessionId" uuid NOT NULL,
    "previousMessageId" uuid,
    "revisionOfMessageId" uuid,
    "retryOfMessageId" uuid,
    type character varying(16) NOT NULL,
    name character varying(128) NOT NULL,
    content text NOT NULL,
    provider character varying(16),
    model character varying(64),
    "workflowId" character varying(36),
    "executionId" integer,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "agentId" character varying(36),
    status character varying(16) DEFAULT 'success'::character varying NOT NULL,
    attachments json
);


ALTER TABLE public.chat_hub_messages OWNER TO n8n;

--
-- Name: COLUMN chat_hub_messages.type; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.chat_hub_messages.type IS 'ChatHubMessageType enum: "human", "ai", "system", "tool", "generic"';


--
-- Name: COLUMN chat_hub_messages.provider; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.chat_hub_messages.provider IS 'ChatHubProvider enum: "openai", "anthropic", "google", "n8n"';


--
-- Name: COLUMN chat_hub_messages.model; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.chat_hub_messages.model IS 'Model name used at the respective Model node, ie. "gpt-4"';


--
-- Name: COLUMN chat_hub_messages."agentId"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.chat_hub_messages."agentId" IS 'ID of the custom agent (if provider is "custom-agent")';


--
-- Name: COLUMN chat_hub_messages.status; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.chat_hub_messages.status IS 'ChatHubMessageStatus enum, eg. "success", "error", "running", "cancelled"';


--
-- Name: COLUMN chat_hub_messages.attachments; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.chat_hub_messages.attachments IS 'File attachments for the message (if any), stored as JSON. Files are stored as base64-encoded data URLs.';


--
-- Name: chat_hub_sessions; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.chat_hub_sessions (
    id uuid NOT NULL,
    title character varying(256) NOT NULL,
    "ownerId" uuid NOT NULL,
    "lastMessageAt" timestamp(3) with time zone,
    "credentialId" character varying(36),
    provider character varying(16),
    model character varying(64),
    "workflowId" character varying(36),
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "agentId" character varying(36),
    "agentName" character varying(128),
    tools json DEFAULT '[]'::json NOT NULL
);


ALTER TABLE public.chat_hub_sessions OWNER TO n8n;

--
-- Name: COLUMN chat_hub_sessions.provider; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.chat_hub_sessions.provider IS 'ChatHubProvider enum: "openai", "anthropic", "google", "n8n"';


--
-- Name: COLUMN chat_hub_sessions.model; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.chat_hub_sessions.model IS 'Model name used at the respective Model node, ie. "gpt-4"';


--
-- Name: COLUMN chat_hub_sessions."agentId"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.chat_hub_sessions."agentId" IS 'ID of the custom agent (if provider is "custom-agent")';


--
-- Name: COLUMN chat_hub_sessions."agentName"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.chat_hub_sessions."agentName" IS 'Cached name of the custom agent (if provider is "custom-agent")';


--
-- Name: COLUMN chat_hub_sessions.tools; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.chat_hub_sessions.tools IS 'Tools available to the agent as JSON node definitions';


--
-- Name: credentials_entity; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.credentials_entity (
    name character varying(128) NOT NULL,
    data text NOT NULL,
    type character varying(128) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    id character varying(36) NOT NULL,
    "isManaged" boolean DEFAULT false NOT NULL,
    "isGlobal" boolean DEFAULT false NOT NULL
);


ALTER TABLE public.credentials_entity OWNER TO n8n;

--
-- Name: data_table; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.data_table (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.data_table OWNER TO n8n;

--
-- Name: data_table_column; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.data_table_column (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    type character varying(32) NOT NULL,
    index integer NOT NULL,
    "dataTableId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.data_table_column OWNER TO n8n;

--
-- Name: COLUMN data_table_column.type; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.data_table_column.type IS 'Expected: string, number, boolean, or date (not enforced as a constraint)';


--
-- Name: COLUMN data_table_column.index; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.data_table_column.index IS 'Column order, starting from 0 (0 = first column)';


--
-- Name: event_destinations; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.event_destinations (
    id uuid NOT NULL,
    destination jsonb NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.event_destinations OWNER TO n8n;

--
-- Name: execution_annotation_tags; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.execution_annotation_tags (
    "annotationId" integer NOT NULL,
    "tagId" character varying(24) NOT NULL
);


ALTER TABLE public.execution_annotation_tags OWNER TO n8n;

--
-- Name: execution_annotations; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.execution_annotations (
    id integer NOT NULL,
    "executionId" integer NOT NULL,
    vote character varying(6),
    note text,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.execution_annotations OWNER TO n8n;

--
-- Name: execution_annotations_id_seq; Type: SEQUENCE; Schema: public; Owner: n8n
--

CREATE SEQUENCE public.execution_annotations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.execution_annotations_id_seq OWNER TO n8n;

--
-- Name: execution_annotations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: n8n
--

ALTER SEQUENCE public.execution_annotations_id_seq OWNED BY public.execution_annotations.id;


--
-- Name: execution_data; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.execution_data (
    "executionId" integer NOT NULL,
    "workflowData" json NOT NULL,
    data text NOT NULL
);


ALTER TABLE public.execution_data OWNER TO n8n;

--
-- Name: execution_entity; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.execution_entity (
    id integer NOT NULL,
    finished boolean NOT NULL,
    mode character varying NOT NULL,
    "retryOf" character varying,
    "retrySuccessId" character varying,
    "startedAt" timestamp(3) with time zone,
    "stoppedAt" timestamp(3) with time zone,
    "waitTill" timestamp(3) with time zone,
    status character varying NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "deletedAt" timestamp(3) with time zone,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.execution_entity OWNER TO n8n;

--
-- Name: execution_entity_id_seq; Type: SEQUENCE; Schema: public; Owner: n8n
--

CREATE SEQUENCE public.execution_entity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.execution_entity_id_seq OWNER TO n8n;

--
-- Name: execution_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: n8n
--

ALTER SEQUENCE public.execution_entity_id_seq OWNED BY public.execution_entity.id;


--
-- Name: execution_metadata; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.execution_metadata (
    id integer NOT NULL,
    "executionId" integer NOT NULL,
    key character varying(255) NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.execution_metadata OWNER TO n8n;

--
-- Name: execution_metadata_temp_id_seq; Type: SEQUENCE; Schema: public; Owner: n8n
--

CREATE SEQUENCE public.execution_metadata_temp_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.execution_metadata_temp_id_seq OWNER TO n8n;

--
-- Name: execution_metadata_temp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: n8n
--

ALTER SEQUENCE public.execution_metadata_temp_id_seq OWNED BY public.execution_metadata.id;


--
-- Name: folder; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.folder (
    id character varying(36) NOT NULL,
    name character varying(128) NOT NULL,
    "parentFolderId" character varying(36),
    "projectId" character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.folder OWNER TO n8n;

--
-- Name: folder_tag; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.folder_tag (
    "folderId" character varying(36) NOT NULL,
    "tagId" character varying(36) NOT NULL
);


ALTER TABLE public.folder_tag OWNER TO n8n;

--
-- Name: insights_by_period; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.insights_by_period (
    id integer NOT NULL,
    "metaId" integer NOT NULL,
    type integer NOT NULL,
    value bigint NOT NULL,
    "periodUnit" integer NOT NULL,
    "periodStart" timestamp(0) with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.insights_by_period OWNER TO n8n;

--
-- Name: COLUMN insights_by_period.type; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.insights_by_period.type IS '0: time_saved_minutes, 1: runtime_milliseconds, 2: success, 3: failure';


--
-- Name: COLUMN insights_by_period."periodUnit"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.insights_by_period."periodUnit" IS '0: hour, 1: day, 2: week';


--
-- Name: insights_by_period_id_seq; Type: SEQUENCE; Schema: public; Owner: n8n
--

ALTER TABLE public.insights_by_period ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.insights_by_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: insights_metadata; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.insights_metadata (
    "metaId" integer NOT NULL,
    "workflowId" character varying(16),
    "projectId" character varying(36),
    "workflowName" character varying(128) NOT NULL,
    "projectName" character varying(255) NOT NULL
);


ALTER TABLE public.insights_metadata OWNER TO n8n;

--
-- Name: insights_metadata_metaId_seq; Type: SEQUENCE; Schema: public; Owner: n8n
--

ALTER TABLE public.insights_metadata ALTER COLUMN "metaId" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."insights_metadata_metaId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: insights_raw; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.insights_raw (
    id integer NOT NULL,
    "metaId" integer NOT NULL,
    type integer NOT NULL,
    value bigint NOT NULL,
    "timestamp" timestamp(0) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.insights_raw OWNER TO n8n;

--
-- Name: COLUMN insights_raw.type; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.insights_raw.type IS '0: time_saved_minutes, 1: runtime_milliseconds, 2: success, 3: failure';


--
-- Name: insights_raw_id_seq; Type: SEQUENCE; Schema: public; Owner: n8n
--

ALTER TABLE public.insights_raw ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.insights_raw_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: installed_nodes; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.installed_nodes (
    name character varying(200) NOT NULL,
    type character varying(200) NOT NULL,
    "latestVersion" integer DEFAULT 1 NOT NULL,
    package character varying(241) NOT NULL
);


ALTER TABLE public.installed_nodes OWNER TO n8n;

--
-- Name: installed_packages; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.installed_packages (
    "packageName" character varying(214) NOT NULL,
    "installedVersion" character varying(50) NOT NULL,
    "authorName" character varying(70),
    "authorEmail" character varying(70),
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.installed_packages OWNER TO n8n;

--
-- Name: invalid_auth_token; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.invalid_auth_token (
    token character varying(512) NOT NULL,
    "expiresAt" timestamp(3) with time zone NOT NULL
);


ALTER TABLE public.invalid_auth_token OWNER TO n8n;

--
-- Name: migrations; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.migrations (
    id integer NOT NULL,
    "timestamp" bigint NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE public.migrations OWNER TO n8n;

--
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: n8n
--

CREATE SEQUENCE public.migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.migrations_id_seq OWNER TO n8n;

--
-- Name: migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: n8n
--

ALTER SEQUENCE public.migrations_id_seq OWNED BY public.migrations.id;


--
-- Name: oauth_access_tokens; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.oauth_access_tokens (
    token character varying NOT NULL,
    "clientId" character varying NOT NULL,
    "userId" uuid NOT NULL
);


ALTER TABLE public.oauth_access_tokens OWNER TO n8n;

--
-- Name: oauth_authorization_codes; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.oauth_authorization_codes (
    code character varying(255) NOT NULL,
    "clientId" character varying NOT NULL,
    "userId" uuid NOT NULL,
    "redirectUri" character varying NOT NULL,
    "codeChallenge" character varying NOT NULL,
    "codeChallengeMethod" character varying(255) NOT NULL,
    "expiresAt" bigint NOT NULL,
    state character varying,
    used boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.oauth_authorization_codes OWNER TO n8n;

--
-- Name: COLUMN oauth_authorization_codes."expiresAt"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.oauth_authorization_codes."expiresAt" IS 'Unix timestamp in milliseconds';


--
-- Name: oauth_clients; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.oauth_clients (
    id character varying NOT NULL,
    name character varying(255) NOT NULL,
    "redirectUris" json NOT NULL,
    "grantTypes" json NOT NULL,
    "clientSecret" character varying(255),
    "clientSecretExpiresAt" bigint,
    "tokenEndpointAuthMethod" character varying(255) DEFAULT 'none'::character varying NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.oauth_clients OWNER TO n8n;

--
-- Name: COLUMN oauth_clients."tokenEndpointAuthMethod"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.oauth_clients."tokenEndpointAuthMethod" IS 'Possible values: none, client_secret_basic or client_secret_post';


--
-- Name: oauth_refresh_tokens; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.oauth_refresh_tokens (
    token character varying(255) NOT NULL,
    "clientId" character varying NOT NULL,
    "userId" uuid NOT NULL,
    "expiresAt" bigint NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.oauth_refresh_tokens OWNER TO n8n;

--
-- Name: COLUMN oauth_refresh_tokens."expiresAt"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.oauth_refresh_tokens."expiresAt" IS 'Unix timestamp in milliseconds';


--
-- Name: oauth_user_consents; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.oauth_user_consents (
    id integer NOT NULL,
    "userId" uuid NOT NULL,
    "clientId" character varying NOT NULL,
    "grantedAt" bigint NOT NULL
);


ALTER TABLE public.oauth_user_consents OWNER TO n8n;

--
-- Name: COLUMN oauth_user_consents."grantedAt"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.oauth_user_consents."grantedAt" IS 'Unix timestamp in milliseconds';


--
-- Name: oauth_user_consents_id_seq; Type: SEQUENCE; Schema: public; Owner: n8n
--

ALTER TABLE public.oauth_user_consents ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.oauth_user_consents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: project; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.project (
    id character varying(36) NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(36) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    icon json,
    description character varying(512)
);


ALTER TABLE public.project OWNER TO n8n;

--
-- Name: project_relation; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.project_relation (
    "projectId" character varying(36) NOT NULL,
    "userId" uuid NOT NULL,
    role character varying NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.project_relation OWNER TO n8n;

--
-- Name: role; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.role (
    slug character varying(128) NOT NULL,
    "displayName" text,
    description text,
    "roleType" text,
    "systemRole" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.role OWNER TO n8n;

--
-- Name: COLUMN role.slug; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.role.slug IS 'Unique identifier of the role for example: "global:owner"';


--
-- Name: COLUMN role."displayName"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.role."displayName" IS 'Name used to display in the UI';


--
-- Name: COLUMN role.description; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.role.description IS 'Text describing the scope in more detail of users';


--
-- Name: COLUMN role."roleType"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.role."roleType" IS 'Type of the role, e.g., global, project, or workflow';


--
-- Name: COLUMN role."systemRole"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.role."systemRole" IS 'Indicates if the role is managed by the system and cannot be edited';


--
-- Name: role_scope; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.role_scope (
    "roleSlug" character varying(128) NOT NULL,
    "scopeSlug" character varying(128) NOT NULL
);


ALTER TABLE public.role_scope OWNER TO n8n;

--
-- Name: scope; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.scope (
    slug character varying(128) NOT NULL,
    "displayName" text,
    description text
);


ALTER TABLE public.scope OWNER TO n8n;

--
-- Name: COLUMN scope.slug; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.scope.slug IS 'Unique identifier of the scope for example: "project:create"';


--
-- Name: COLUMN scope."displayName"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.scope."displayName" IS 'Name used to display in the UI';


--
-- Name: COLUMN scope.description; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.scope.description IS 'Text describing the scope in more detail of users';


--
-- Name: settings; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.settings (
    key character varying(255) NOT NULL,
    value text NOT NULL,
    "loadOnStartup" boolean DEFAULT false NOT NULL
);


ALTER TABLE public.settings OWNER TO n8n;

--
-- Name: shared_credentials; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.shared_credentials (
    "credentialsId" character varying(36) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    role text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.shared_credentials OWNER TO n8n;

--
-- Name: shared_workflow; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.shared_workflow (
    "workflowId" character varying(36) NOT NULL,
    "projectId" character varying(36) NOT NULL,
    role text NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.shared_workflow OWNER TO n8n;

--
-- Name: tag_entity; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.tag_entity (
    name character varying(24) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    id character varying(36) NOT NULL
);


ALTER TABLE public.tag_entity OWNER TO n8n;

--
-- Name: test_case_execution; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.test_case_execution (
    id character varying(36) NOT NULL,
    "testRunId" character varying(36) NOT NULL,
    "executionId" integer,
    status character varying NOT NULL,
    "runAt" timestamp(3) with time zone,
    "completedAt" timestamp(3) with time zone,
    "errorCode" character varying,
    "errorDetails" json,
    metrics json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    inputs json,
    outputs json
);


ALTER TABLE public.test_case_execution OWNER TO n8n;

--
-- Name: test_run; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.test_run (
    id character varying(36) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    status character varying NOT NULL,
    "errorCode" character varying,
    "errorDetails" json,
    "runAt" timestamp(3) with time zone,
    "completedAt" timestamp(3) with time zone,
    metrics json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.test_run OWNER TO n8n;

--
-- Name: user; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public."user" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying(255),
    "firstName" character varying(32),
    "lastName" character varying(32),
    password character varying(255),
    "personalizationAnswers" json,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    settings json,
    disabled boolean DEFAULT false NOT NULL,
    "mfaEnabled" boolean DEFAULT false NOT NULL,
    "mfaSecret" text,
    "mfaRecoveryCodes" text,
    "lastActiveAt" date,
    "roleSlug" character varying(128) DEFAULT 'global:member'::character varying NOT NULL
);


ALTER TABLE public."user" OWNER TO n8n;

--
-- Name: user_api_keys; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.user_api_keys (
    id character varying(36) NOT NULL,
    "userId" uuid NOT NULL,
    label character varying(100) NOT NULL,
    "apiKey" character varying NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    scopes json,
    audience character varying DEFAULT 'public-api'::character varying NOT NULL
);


ALTER TABLE public.user_api_keys OWNER TO n8n;

--
-- Name: variables; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.variables (
    key character varying(50) NOT NULL,
    type character varying(50) DEFAULT 'string'::character varying NOT NULL,
    value character varying(255),
    id character varying(36) NOT NULL,
    "projectId" character varying(36)
);


ALTER TABLE public.variables OWNER TO n8n;

--
-- Name: webhook_entity; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.webhook_entity (
    "webhookPath" character varying NOT NULL,
    method character varying NOT NULL,
    node character varying NOT NULL,
    "webhookId" character varying,
    "pathLength" integer,
    "workflowId" character varying(36) NOT NULL
);


ALTER TABLE public.webhook_entity OWNER TO n8n;

--
-- Name: workflow_dependency; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.workflow_dependency (
    id integer NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "workflowVersionId" integer NOT NULL,
    "dependencyType" character varying(32) NOT NULL,
    "dependencyKey" character varying(255) NOT NULL,
    "dependencyInfo" json,
    "indexVersionId" smallint DEFAULT 1 NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL
);


ALTER TABLE public.workflow_dependency OWNER TO n8n;

--
-- Name: COLUMN workflow_dependency."workflowVersionId"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.workflow_dependency."workflowVersionId" IS 'Version of the workflow';


--
-- Name: COLUMN workflow_dependency."dependencyType"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.workflow_dependency."dependencyType" IS 'Type of dependency: "credential", "nodeType", "webhookPath", or "workflowCall"';


--
-- Name: COLUMN workflow_dependency."dependencyKey"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.workflow_dependency."dependencyKey" IS 'ID or name of the dependency';


--
-- Name: COLUMN workflow_dependency."dependencyInfo"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.workflow_dependency."dependencyInfo" IS 'Additional info about the dependency, interpreted based on type';


--
-- Name: COLUMN workflow_dependency."indexVersionId"; Type: COMMENT; Schema: public; Owner: n8n
--

COMMENT ON COLUMN public.workflow_dependency."indexVersionId" IS 'Version of the index structure';


--
-- Name: workflow_dependency_id_seq; Type: SEQUENCE; Schema: public; Owner: n8n
--

ALTER TABLE public.workflow_dependency ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.workflow_dependency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: workflow_entity; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.workflow_entity (
    name character varying(128) NOT NULL,
    active boolean NOT NULL,
    nodes json NOT NULL,
    connections json NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    settings json,
    "staticData" json,
    "pinData" json,
    "versionId" character(36) NOT NULL,
    "triggerCount" integer DEFAULT 0 NOT NULL,
    id character varying(36) NOT NULL,
    meta json,
    "parentFolderId" character varying(36) DEFAULT NULL::character varying,
    "isArchived" boolean DEFAULT false NOT NULL,
    "versionCounter" integer DEFAULT 1 NOT NULL,
    description text,
    "activeVersionId" character varying(36)
);


ALTER TABLE public.workflow_entity OWNER TO n8n;

--
-- Name: workflow_history; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.workflow_history (
    "versionId" character varying(36) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    authors character varying(255) NOT NULL,
    "createdAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    "updatedAt" timestamp(3) with time zone DEFAULT CURRENT_TIMESTAMP(3) NOT NULL,
    nodes json NOT NULL,
    connections json NOT NULL,
    name character varying(128),
    autosaved boolean DEFAULT false NOT NULL,
    description text
);


ALTER TABLE public.workflow_history OWNER TO n8n;

--
-- Name: workflow_statistics; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.workflow_statistics (
    count integer DEFAULT 0,
    "latestEvent" timestamp(3) with time zone,
    name character varying(128) NOT NULL,
    "workflowId" character varying(36) NOT NULL,
    "rootCount" integer DEFAULT 0
);


ALTER TABLE public.workflow_statistics OWNER TO n8n;

--
-- Name: workflows_tags; Type: TABLE; Schema: public; Owner: n8n
--

CREATE TABLE public.workflows_tags (
    "workflowId" character varying(36) NOT NULL,
    "tagId" character varying(36) NOT NULL
);


ALTER TABLE public.workflows_tags OWNER TO n8n;

--
-- Name: candidato; Type: TABLE; Schema: rag_system; Owner: n8n
--

CREATE TABLE rag_system.candidato (
    id integer NOT NULL,
    nombre character varying(100),
    apellido character varying(100),
    email character varying(255),
    telefono character varying(50),
    perfil jsonb DEFAULT '{}'::jsonb,
    estado_seleccion character varying(50) DEFAULT 'NUEVO'::character varying,
    fuente_original character varying(100),
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    candidato_uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    hash_candidato character(64) NOT NULL
);


ALTER TABLE rag_system.candidato OWNER TO n8n;

--
-- Name: candidato_documento; Type: TABLE; Schema: rag_system; Owner: n8n
--

CREATE TABLE rag_system.candidato_documento (
    id integer NOT NULL,
    candidato_id integer NOT NULL,
    documento_id integer NOT NULL,
    tipo_relacion rag_system.tipo_relacion_documento NOT NULL,
    confianza numeric(3,2),
    creado_at timestamp without time zone DEFAULT now()
);


ALTER TABLE rag_system.candidato_documento OWNER TO n8n;

--
-- Name: candidato_documento_id_seq; Type: SEQUENCE; Schema: rag_system; Owner: n8n
--

CREATE SEQUENCE rag_system.candidato_documento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rag_system.candidato_documento_id_seq OWNER TO n8n;

--
-- Name: candidato_documento_id_seq; Type: SEQUENCE OWNED BY; Schema: rag_system; Owner: n8n
--

ALTER SEQUENCE rag_system.candidato_documento_id_seq OWNED BY rag_system.candidato_documento.id;


--
-- Name: candidato_id_seq; Type: SEQUENCE; Schema: rag_system; Owner: n8n
--

CREATE SEQUENCE rag_system.candidato_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rag_system.candidato_id_seq OWNER TO n8n;

--
-- Name: candidato_id_seq; Type: SEQUENCE OWNED BY; Schema: rag_system; Owner: n8n
--

ALTER SEQUENCE rag_system.candidato_id_seq OWNED BY rag_system.candidato.id;


--
-- Name: documento_aprobado; Type: TABLE; Schema: rag_system; Owner: n8n
--

CREATE TABLE rag_system.documento_aprobado (
    id integer NOT NULL,
    tipo rag_system.tipo_documento NOT NULL,
    dominio rag_system.dominio_documento NOT NULL,
    hash_archivo character(64) NOT NULL,
    nombre_archivo character varying(255) NOT NULL,
    texto_limpio text NOT NULL,
    datos_estructurados jsonb DEFAULT '{}'::jsonb,
    candidato_id integer,
    metadata jsonb DEFAULT '{}'::jsonb,
    embeddings_generados boolean DEFAULT false,
    indexado_en_qdrant boolean DEFAULT false,
    qdrant_collection character varying(100),
    aprobado_por integer,
    aprobado_at timestamp without time zone DEFAULT now(),
    mime_type character varying(100) DEFAULT 'application/pdf'::character varying NOT NULL,
    tamanio_bytes bigint DEFAULT 0 NOT NULL,
    texto_raw text,
    fuente rag_system.fuente_ingesta DEFAULT 'UPLOAD_WEB'::rag_system.fuente_ingesta NOT NULL,
    creado_por integer,
    created_at timestamp without time zone DEFAULT now(),
    documento_uuid uuid DEFAULT gen_random_uuid(),
    datos_extraidos boolean DEFAULT false,
    indexado boolean DEFAULT false,
    procesado_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE rag_system.documento_aprobado OWNER TO n8n;

--
-- Name: documento_aprobado_id_seq; Type: SEQUENCE; Schema: rag_system; Owner: n8n
--

CREATE SEQUENCE rag_system.documento_aprobado_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rag_system.documento_aprobado_id_seq OWNER TO n8n;

--
-- Name: documento_aprobado_id_seq; Type: SEQUENCE OWNED BY; Schema: rag_system; Owner: n8n
--

ALTER SEQUENCE rag_system.documento_aprobado_id_seq OWNED BY rag_system.documento_aprobado.id;


--
-- Name: documento_chunk; Type: TABLE; Schema: rag_system; Owner: n8n
--

CREATE TABLE rag_system.documento_chunk (
    id integer NOT NULL,
    documento_id integer NOT NULL,
    contenido text NOT NULL,
    posicion integer NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    embedding_generado boolean DEFAULT false,
    qdrant_point_id character varying(100),
    created_at timestamp without time zone DEFAULT now(),
    documento_uuid uuid NOT NULL,
    chunk_uuid uuid DEFAULT gen_random_uuid() NOT NULL
);


ALTER TABLE rag_system.documento_chunk OWNER TO n8n;

--
-- Name: documento_chunk_id_seq; Type: SEQUENCE; Schema: rag_system; Owner: n8n
--

CREATE SEQUENCE rag_system.documento_chunk_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rag_system.documento_chunk_id_seq OWNER TO n8n;

--
-- Name: documento_chunk_id_seq; Type: SEQUENCE OWNED BY; Schema: rag_system; Owner: n8n
--

ALTER SEQUENCE rag_system.documento_chunk_id_seq OWNED BY rag_system.documento_chunk.id;


--
-- Name: documento_rechazado; Type: TABLE; Schema: rag_system; Owner: n8n
--

CREATE TABLE rag_system.documento_rechazado (
    id integer NOT NULL,
    hash_archivo character(64) NOT NULL,
    nombre_archivo character varying(255) NOT NULL,
    mime_type character varying(100) NOT NULL,
    tamanio_bytes bigint NOT NULL,
    texto_raw text,
    texto_limpio text,
    tipo_preliminar rag_system.tipo_documento,
    dominio_preliminar rag_system.dominio_documento,
    confianza_clasificacion numeric(3,2),
    motivo_rechazo text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    fuente rag_system.fuente_ingesta NOT NULL,
    creado_por integer,
    rechazado_por integer,
    created_at timestamp without time zone DEFAULT now(),
    rechazado_at timestamp without time zone DEFAULT now()
);


ALTER TABLE rag_system.documento_rechazado OWNER TO n8n;

--
-- Name: documento_rechazado_id_seq; Type: SEQUENCE; Schema: rag_system; Owner: n8n
--

CREATE SEQUENCE rag_system.documento_rechazado_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rag_system.documento_rechazado_id_seq OWNER TO n8n;

--
-- Name: documento_rechazado_id_seq; Type: SEQUENCE OWNED BY; Schema: rag_system; Owner: n8n
--

ALTER SEQUENCE rag_system.documento_rechazado_id_seq OWNED BY rag_system.documento_rechazado.id;


--
-- Name: documento_staging; Type: TABLE; Schema: rag_system; Owner: n8n
--

CREATE TABLE rag_system.documento_staging (
    id integer NOT NULL,
    tipo rag_system.tipo_documento,
    dominio rag_system.dominio_documento,
    confianza_clasificacion numeric(3,2),
    estado rag_system.estado_documento DEFAULT 'PENDIENTE'::rag_system.estado_documento NOT NULL,
    hash_archivo character(64) NOT NULL,
    nombre_archivo character varying(255) NOT NULL,
    mime_type character varying(100) NOT NULL,
    tamanio_bytes bigint NOT NULL,
    texto_raw text,
    texto_limpio text,
    metadata jsonb DEFAULT '{}'::jsonb,
    fuente rag_system.fuente_ingesta NOT NULL,
    creado_por integer,
    created_at timestamp without time zone DEFAULT now(),
    procesado_at timestamp without time zone,
    error_procesamiento text,
    documento_aprobado_id integer,
    updated_at timestamp without time zone DEFAULT now(),
    documento_uuid uuid DEFAULT gen_random_uuid() NOT NULL,
    datos_estructurados jsonb DEFAULT '{}'::jsonb NOT NULL
);


ALTER TABLE rag_system.documento_staging OWNER TO n8n;

--
-- Name: documento_staging_id_seq; Type: SEQUENCE; Schema: rag_system; Owner: n8n
--

CREATE SEQUENCE rag_system.documento_staging_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rag_system.documento_staging_id_seq OWNER TO n8n;

--
-- Name: documento_staging_id_seq; Type: SEQUENCE OWNED BY; Schema: rag_system; Owner: n8n
--

ALTER SEQUENCE rag_system.documento_staging_id_seq OWNED BY rag_system.documento_staging.id;


--
-- Name: rag_consulta; Type: TABLE; Schema: rag_system; Owner: n8n
--

CREATE TABLE rag_system.rag_consulta (
    id integer NOT NULL,
    query_original text NOT NULL,
    query_procesado text,
    usuario_id integer,
    chunks_recuperados integer[],
    candidatos_retornados integer[],
    respuesta_generada text,
    latencia_ms integer,
    tokens_usados integer,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE rag_system.rag_consulta OWNER TO n8n;

--
-- Name: rag_consulta_id_seq; Type: SEQUENCE; Schema: rag_system; Owner: n8n
--

CREATE SEQUENCE rag_system.rag_consulta_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rag_system.rag_consulta_id_seq OWNER TO n8n;

--
-- Name: rag_consulta_id_seq; Type: SEQUENCE OWNED BY; Schema: rag_system; Owner: n8n
--

ALTER SEQUENCE rag_system.rag_consulta_id_seq OWNED BY rag_system.rag_consulta.id;


--
-- Name: usuario; Type: TABLE; Schema: rag_system; Owner: n8n
--

CREATE TABLE rag_system.usuario (
    id integer NOT NULL,
    username character varying(100) NOT NULL,
    email character varying(255),
    activo boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE rag_system.usuario OWNER TO n8n;

--
-- Name: usuario_id_seq; Type: SEQUENCE; Schema: rag_system; Owner: n8n
--

CREATE SEQUENCE rag_system.usuario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rag_system.usuario_id_seq OWNER TO n8n;

--
-- Name: usuario_id_seq; Type: SEQUENCE OWNED BY; Schema: rag_system; Owner: n8n
--

ALTER SEQUENCE rag_system.usuario_id_seq OWNED BY rag_system.usuario.id;


--
-- Name: v_candidatos_completos; Type: VIEW; Schema: rag_system; Owner: n8n
--

CREATE VIEW rag_system.v_candidatos_completos AS
SELECT
    NULL::integer AS id,
    NULL::character varying(100) AS nombre,
    NULL::character varying(100) AS apellido,
    NULL::character varying(255) AS email,
    NULL::jsonb AS perfil,
    NULL::bigint AS documentos_aprobados,
    NULL::timestamp without time zone AS ultimo_documento;


ALTER TABLE rag_system.v_candidatos_completos OWNER TO n8n;

--
-- Name: v_docs_pendientes; Type: VIEW; Schema: rag_system; Owner: n8n
--

CREATE VIEW rag_system.v_docs_pendientes AS
 SELECT documento_staging.id,
    documento_staging.nombre_archivo,
    documento_staging.tipo AS tipo_preliminar,
    documento_staging.dominio AS dominio_preliminar,
    documento_staging.confianza_clasificacion,
    documento_staging.estado,
    documento_staging.created_at,
    (EXTRACT(epoch FROM (now() - (documento_staging.created_at)::timestamp with time zone)) / (3600)::numeric) AS horas_esperando
   FROM rag_system.documento_staging
  WHERE (documento_staging.estado = ANY (ARRAY['PENDIENTE'::rag_system.estado_documento, 'PROCESANDO'::rag_system.estado_documento]))
  ORDER BY documento_staging.created_at;


ALTER TABLE rag_system.v_docs_pendientes OWNER TO n8n;

--
-- Name: auth_provider_sync_history id; Type: DEFAULT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.auth_provider_sync_history ALTER COLUMN id SET DEFAULT nextval('public.auth_provider_sync_history_id_seq'::regclass);


--
-- Name: execution_annotations id; Type: DEFAULT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.execution_annotations ALTER COLUMN id SET DEFAULT nextval('public.execution_annotations_id_seq'::regclass);


--
-- Name: execution_entity id; Type: DEFAULT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.execution_entity ALTER COLUMN id SET DEFAULT nextval('public.execution_entity_id_seq'::regclass);


--
-- Name: execution_metadata id; Type: DEFAULT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.execution_metadata ALTER COLUMN id SET DEFAULT nextval('public.execution_metadata_temp_id_seq'::regclass);


--
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- Name: candidato id; Type: DEFAULT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.candidato ALTER COLUMN id SET DEFAULT nextval('rag_system.candidato_id_seq'::regclass);


--
-- Name: candidato_documento id; Type: DEFAULT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.candidato_documento ALTER COLUMN id SET DEFAULT nextval('rag_system.candidato_documento_id_seq'::regclass);


--
-- Name: documento_aprobado id; Type: DEFAULT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_aprobado ALTER COLUMN id SET DEFAULT nextval('rag_system.documento_aprobado_id_seq'::regclass);


--
-- Name: documento_chunk id; Type: DEFAULT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_chunk ALTER COLUMN id SET DEFAULT nextval('rag_system.documento_chunk_id_seq'::regclass);


--
-- Name: documento_rechazado id; Type: DEFAULT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_rechazado ALTER COLUMN id SET DEFAULT nextval('rag_system.documento_rechazado_id_seq'::regclass);


--
-- Name: documento_staging id; Type: DEFAULT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_staging ALTER COLUMN id SET DEFAULT nextval('rag_system.documento_staging_id_seq'::regclass);


--
-- Name: rag_consulta id; Type: DEFAULT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.rag_consulta ALTER COLUMN id SET DEFAULT nextval('rag_system.rag_consulta_id_seq'::regclass);


--
-- Name: usuario id; Type: DEFAULT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.usuario ALTER COLUMN id SET DEFAULT nextval('rag_system.usuario_id_seq'::regclass);


--
-- Name: test_run PK_011c050f566e9db509a0fadb9b9; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.test_run
    ADD CONSTRAINT "PK_011c050f566e9db509a0fadb9b9" PRIMARY KEY (id);


--
-- Name: installed_packages PK_08cc9197c39b028c1e9beca225940576fd1a5804; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.installed_packages
    ADD CONSTRAINT "PK_08cc9197c39b028c1e9beca225940576fd1a5804" PRIMARY KEY ("packageName");


--
-- Name: execution_metadata PK_17a0b6284f8d626aae88e1c16e4; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.execution_metadata
    ADD CONSTRAINT "PK_17a0b6284f8d626aae88e1c16e4" PRIMARY KEY (id);


--
-- Name: project_relation PK_1caaa312a5d7184a003be0f0cb6; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "PK_1caaa312a5d7184a003be0f0cb6" PRIMARY KEY ("projectId", "userId");


--
-- Name: chat_hub_sessions PK_1eafef1273c70e4464fec703412; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "PK_1eafef1273c70e4464fec703412" PRIMARY KEY (id);


--
-- Name: folder_tag PK_27e4e00852f6b06a925a4d83a3e; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "PK_27e4e00852f6b06a925a4d83a3e" PRIMARY KEY ("folderId", "tagId");


--
-- Name: role PK_35c9b140caaf6da09cfabb0d675; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT "PK_35c9b140caaf6da09cfabb0d675" PRIMARY KEY (slug);


--
-- Name: project PK_4d68b1358bb5b766d3e78f32f57; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT "PK_4d68b1358bb5b766d3e78f32f57" PRIMARY KEY (id);


--
-- Name: workflow_dependency PK_52325e34cd7a2f0f67b0f3cad65; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.workflow_dependency
    ADD CONSTRAINT "PK_52325e34cd7a2f0f67b0f3cad65" PRIMARY KEY (id);


--
-- Name: invalid_auth_token PK_5779069b7235b256d91f7af1a15; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.invalid_auth_token
    ADD CONSTRAINT "PK_5779069b7235b256d91f7af1a15" PRIMARY KEY (token);


--
-- Name: shared_workflow PK_5ba87620386b847201c9531c58f; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "PK_5ba87620386b847201c9531c58f" PRIMARY KEY ("workflowId", "projectId");


--
-- Name: folder PK_6278a41a706740c94c02e288df8; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "PK_6278a41a706740c94c02e288df8" PRIMARY KEY (id);


--
-- Name: data_table_column PK_673cb121ee4a8a5e27850c72c51; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "PK_673cb121ee4a8a5e27850c72c51" PRIMARY KEY (id);


--
-- Name: annotation_tag_entity PK_69dfa041592c30bbc0d4b84aa00; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.annotation_tag_entity
    ADD CONSTRAINT "PK_69dfa041592c30bbc0d4b84aa00" PRIMARY KEY (id);


--
-- Name: oauth_refresh_tokens PK_74abaed0b30711b6532598b0392; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.oauth_refresh_tokens
    ADD CONSTRAINT "PK_74abaed0b30711b6532598b0392" PRIMARY KEY (token);


--
-- Name: chat_hub_messages PK_7704a5add6baed43eef835f0bfb; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "PK_7704a5add6baed43eef835f0bfb" PRIMARY KEY (id);


--
-- Name: execution_annotations PK_7afcf93ffa20c4252869a7c6a23; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.execution_annotations
    ADD CONSTRAINT "PK_7afcf93ffa20c4252869a7c6a23" PRIMARY KEY (id);


--
-- Name: oauth_user_consents PK_85b9ada746802c8993103470f05; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "PK_85b9ada746802c8993103470f05" PRIMARY KEY (id);


--
-- Name: migrations PK_8c82d7f526340ab734260ea46be; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT "PK_8c82d7f526340ab734260ea46be" PRIMARY KEY (id);


--
-- Name: installed_nodes PK_8ebd28194e4f792f96b5933423fc439df97d9689; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.installed_nodes
    ADD CONSTRAINT "PK_8ebd28194e4f792f96b5933423fc439df97d9689" PRIMARY KEY (name);


--
-- Name: shared_credentials PK_8ef3a59796a228913f251779cff; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "PK_8ef3a59796a228913f251779cff" PRIMARY KEY ("credentialsId", "projectId");


--
-- Name: test_case_execution PK_90c121f77a78a6580e94b794bce; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "PK_90c121f77a78a6580e94b794bce" PRIMARY KEY (id);


--
-- Name: user_api_keys PK_978fa5caa3468f463dac9d92e69; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.user_api_keys
    ADD CONSTRAINT "PK_978fa5caa3468f463dac9d92e69" PRIMARY KEY (id);


--
-- Name: execution_annotation_tags PK_979ec03d31294cca484be65d11f; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "PK_979ec03d31294cca484be65d11f" PRIMARY KEY ("annotationId", "tagId");


--
-- Name: webhook_entity PK_b21ace2e13596ccd87dc9bf4ea6; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.webhook_entity
    ADD CONSTRAINT "PK_b21ace2e13596ccd87dc9bf4ea6" PRIMARY KEY ("webhookPath", method);


--
-- Name: insights_by_period PK_b606942249b90cc39b0265f0575; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.insights_by_period
    ADD CONSTRAINT "PK_b606942249b90cc39b0265f0575" PRIMARY KEY (id);


--
-- Name: workflow_history PK_b6572dd6173e4cd06fe79937b58; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.workflow_history
    ADD CONSTRAINT "PK_b6572dd6173e4cd06fe79937b58" PRIMARY KEY ("versionId");


--
-- Name: scope PK_bfc45df0481abd7f355d6187da1; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.scope
    ADD CONSTRAINT "PK_bfc45df0481abd7f355d6187da1" PRIMARY KEY (slug);


--
-- Name: oauth_clients PK_c4759172d3431bae6f04e678e0d; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.oauth_clients
    ADD CONSTRAINT "PK_c4759172d3431bae6f04e678e0d" PRIMARY KEY (id);


--
-- Name: settings PK_dc0fe14e6d9943f268e7b119f69ab8bd; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT "PK_dc0fe14e6d9943f268e7b119f69ab8bd" PRIMARY KEY (key);


--
-- Name: oauth_access_tokens PK_dcd71f96a5d5f4bf79e67d322bf; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT "PK_dcd71f96a5d5f4bf79e67d322bf" PRIMARY KEY (token);


--
-- Name: data_table PK_e226d0001b9e6097cbfe70617cb; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "PK_e226d0001b9e6097cbfe70617cb" PRIMARY KEY (id);


--
-- Name: user PK_ea8f538c94b6e352418254ed6474a81f; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "PK_ea8f538c94b6e352418254ed6474a81f" PRIMARY KEY (id);


--
-- Name: insights_raw PK_ec15125755151e3a7e00e00014f; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.insights_raw
    ADD CONSTRAINT "PK_ec15125755151e3a7e00e00014f" PRIMARY KEY (id);


--
-- Name: chat_hub_agents PK_f39a3b36bbdf0e2979ddb21cf78; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.chat_hub_agents
    ADD CONSTRAINT "PK_f39a3b36bbdf0e2979ddb21cf78" PRIMARY KEY (id);


--
-- Name: insights_metadata PK_f448a94c35218b6208ce20cf5a1; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "PK_f448a94c35218b6208ce20cf5a1" PRIMARY KEY ("metaId");


--
-- Name: oauth_authorization_codes PK_fb91ab932cfbd694061501cc20f; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.oauth_authorization_codes
    ADD CONSTRAINT "PK_fb91ab932cfbd694061501cc20f" PRIMARY KEY (code);


--
-- Name: binary_data PK_fc3691585b39408bb0551122af6; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.binary_data
    ADD CONSTRAINT "PK_fc3691585b39408bb0551122af6" PRIMARY KEY ("fileId");


--
-- Name: role_scope PK_role_scope; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "PK_role_scope" PRIMARY KEY ("roleSlug", "scopeSlug");


--
-- Name: oauth_user_consents UQ_083721d99ce8db4033e2958ebb4; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "UQ_083721d99ce8db4033e2958ebb4" UNIQUE ("userId", "clientId");


--
-- Name: data_table_column UQ_8082ec4890f892f0bc77473a123; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "UQ_8082ec4890f892f0bc77473a123" UNIQUE ("dataTableId", name);


--
-- Name: data_table UQ_b23096ef747281ac944d28e8b0d; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "UQ_b23096ef747281ac944d28e8b0d" UNIQUE ("projectId", name);


--
-- Name: user UQ_e12875dfb3b1d92d7d7c5377e2; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "UQ_e12875dfb3b1d92d7d7c5377e2" UNIQUE (email);


--
-- Name: auth_identity auth_identity_pkey; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT auth_identity_pkey PRIMARY KEY ("providerId", "providerType");


--
-- Name: auth_provider_sync_history auth_provider_sync_history_pkey; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.auth_provider_sync_history
    ADD CONSTRAINT auth_provider_sync_history_pkey PRIMARY KEY (id);


--
-- Name: credentials_entity credentials_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.credentials_entity
    ADD CONSTRAINT credentials_entity_pkey PRIMARY KEY (id);


--
-- Name: event_destinations event_destinations_pkey; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.event_destinations
    ADD CONSTRAINT event_destinations_pkey PRIMARY KEY (id);


--
-- Name: execution_data execution_data_pkey; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.execution_data
    ADD CONSTRAINT execution_data_pkey PRIMARY KEY ("executionId");


--
-- Name: execution_entity pk_e3e63bbf986767844bbe1166d4e; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.execution_entity
    ADD CONSTRAINT pk_e3e63bbf986767844bbe1166d4e PRIMARY KEY (id);


--
-- Name: workflow_statistics pk_workflow_statistics; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.workflow_statistics
    ADD CONSTRAINT pk_workflow_statistics PRIMARY KEY ("workflowId", name);


--
-- Name: workflows_tags pk_workflows_tags; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT pk_workflows_tags PRIMARY KEY ("workflowId", "tagId");


--
-- Name: tag_entity tag_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.tag_entity
    ADD CONSTRAINT tag_entity_pkey PRIMARY KEY (id);


--
-- Name: variables variables_pkey; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.variables
    ADD CONSTRAINT variables_pkey PRIMARY KEY (id);


--
-- Name: workflow_entity workflow_entity_pkey; Type: CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.workflow_entity
    ADD CONSTRAINT workflow_entity_pkey PRIMARY KEY (id);


--
-- Name: candidato_documento candidato_documento_candidato_id_documento_id_key; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.candidato_documento
    ADD CONSTRAINT candidato_documento_candidato_id_documento_id_key UNIQUE (candidato_id, documento_id);


--
-- Name: candidato_documento candidato_documento_pkey; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.candidato_documento
    ADD CONSTRAINT candidato_documento_pkey PRIMARY KEY (id);


--
-- Name: candidato candidato_email_key; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.candidato
    ADD CONSTRAINT candidato_email_key UNIQUE (email);


--
-- Name: candidato candidato_hash_candidato_key; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.candidato
    ADD CONSTRAINT candidato_hash_candidato_key UNIQUE (hash_candidato);


--
-- Name: candidato candidato_pkey; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.candidato
    ADD CONSTRAINT candidato_pkey PRIMARY KEY (id);


--
-- Name: documento_aprobado documento_aprobado_hash_archivo_key; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_aprobado
    ADD CONSTRAINT documento_aprobado_hash_archivo_key UNIQUE (hash_archivo);


--
-- Name: documento_aprobado documento_aprobado_pkey; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_aprobado
    ADD CONSTRAINT documento_aprobado_pkey PRIMARY KEY (id);


--
-- Name: documento_chunk documento_chunk_pkey; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_chunk
    ADD CONSTRAINT documento_chunk_pkey PRIMARY KEY (id);


--
-- Name: documento_rechazado documento_rechazado_hash_archivo_key; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_rechazado
    ADD CONSTRAINT documento_rechazado_hash_archivo_key UNIQUE (hash_archivo);


--
-- Name: documento_rechazado documento_rechazado_pkey; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_rechazado
    ADD CONSTRAINT documento_rechazado_pkey PRIMARY KEY (id);


--
-- Name: documento_staging documento_staging_hash_archivo_key; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_staging
    ADD CONSTRAINT documento_staging_hash_archivo_key UNIQUE (hash_archivo);


--
-- Name: documento_staging documento_staging_pkey; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_staging
    ADD CONSTRAINT documento_staging_pkey PRIMARY KEY (id);


--
-- Name: rag_consulta rag_consulta_pkey; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.rag_consulta
    ADD CONSTRAINT rag_consulta_pkey PRIMARY KEY (id);


--
-- Name: documento_chunk uq_doc_chunk; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_chunk
    ADD CONSTRAINT uq_doc_chunk UNIQUE (documento_id, posicion);


--
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (id);


--
-- Name: usuario usuario_username_key; Type: CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.usuario
    ADD CONSTRAINT usuario_username_key UNIQUE (username);


--
-- Name: IDX_14f68deffaf858465715995508; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX "IDX_14f68deffaf858465715995508" ON public.folder USING btree ("projectId", id);


--
-- Name: IDX_1d8ab99d5861c9388d2dc1cf73; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX "IDX_1d8ab99d5861c9388d2dc1cf73" ON public.insights_metadata USING btree ("workflowId");


--
-- Name: IDX_1e31657f5fe46816c34be7c1b4; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX "IDX_1e31657f5fe46816c34be7c1b4" ON public.workflow_history USING btree ("workflowId");


--
-- Name: IDX_1ef35bac35d20bdae979d917a3; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX "IDX_1ef35bac35d20bdae979d917a3" ON public.user_api_keys USING btree ("apiKey");


--
-- Name: IDX_56900edc3cfd16612e2ef2c6a8; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX "IDX_56900edc3cfd16612e2ef2c6a8" ON public.binary_data USING btree ("sourceType", "sourceId");


--
-- Name: IDX_5f0643f6717905a05164090dde; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX "IDX_5f0643f6717905a05164090dde" ON public.project_relation USING btree ("userId");


--
-- Name: IDX_60b6a84299eeb3f671dfec7693; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX "IDX_60b6a84299eeb3f671dfec7693" ON public.insights_by_period USING btree ("periodStart", type, "periodUnit", "metaId");


--
-- Name: IDX_61448d56d61802b5dfde5cdb00; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX "IDX_61448d56d61802b5dfde5cdb00" ON public.project_relation USING btree ("projectId");


--
-- Name: IDX_63d7bbae72c767cf162d459fcc; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX "IDX_63d7bbae72c767cf162d459fcc" ON public.user_api_keys USING btree ("userId", label);


--
-- Name: IDX_8e4b4774db42f1e6dda3452b2a; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX "IDX_8e4b4774db42f1e6dda3452b2a" ON public.test_case_execution USING btree ("testRunId");


--
-- Name: IDX_97f863fa83c4786f1956508496; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX "IDX_97f863fa83c4786f1956508496" ON public.execution_annotations USING btree ("executionId");


--
-- Name: IDX_UniqueRoleDisplayName; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX "IDX_UniqueRoleDisplayName" ON public.role USING btree ("displayName");


--
-- Name: IDX_a3697779b366e131b2bbdae297; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX "IDX_a3697779b366e131b2bbdae297" ON public.execution_annotation_tags USING btree ("tagId");


--
-- Name: IDX_a4ff2d9b9628ea988fa9e7d0bf; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX "IDX_a4ff2d9b9628ea988fa9e7d0bf" ON public.workflow_dependency USING btree ("workflowId");


--
-- Name: IDX_ae51b54c4bb430cf92f48b623f; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX "IDX_ae51b54c4bb430cf92f48b623f" ON public.annotation_tag_entity USING btree (name);


--
-- Name: IDX_c1519757391996eb06064f0e7c; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX "IDX_c1519757391996eb06064f0e7c" ON public.execution_annotation_tags USING btree ("annotationId");


--
-- Name: IDX_cec8eea3bf49551482ccb4933e; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX "IDX_cec8eea3bf49551482ccb4933e" ON public.execution_metadata USING btree ("executionId", key);


--
-- Name: IDX_d6870d3b6e4c185d33926f423c; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX "IDX_d6870d3b6e4c185d33926f423c" ON public.test_run USING btree ("workflowId");


--
-- Name: IDX_e48a201071ab85d9d09119d640; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX "IDX_e48a201071ab85d9d09119d640" ON public.workflow_dependency USING btree ("dependencyKey");


--
-- Name: IDX_e7fe1cfda990c14a445937d0b9; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX "IDX_e7fe1cfda990c14a445937d0b9" ON public.workflow_dependency USING btree ("dependencyType");


--
-- Name: IDX_execution_entity_deletedAt; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX "IDX_execution_entity_deletedAt" ON public.execution_entity USING btree ("deletedAt");


--
-- Name: IDX_role_scope_scopeSlug; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX "IDX_role_scope_scopeSlug" ON public.role_scope USING btree ("scopeSlug");


--
-- Name: IDX_workflow_entity_name; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX "IDX_workflow_entity_name" ON public.workflow_entity USING btree (name);


--
-- Name: idx_07fde106c0b471d8cc80a64fc8; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX idx_07fde106c0b471d8cc80a64fc8 ON public.credentials_entity USING btree (type);


--
-- Name: idx_16f4436789e804e3e1c9eeb240; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX idx_16f4436789e804e3e1c9eeb240 ON public.webhook_entity USING btree ("webhookId", method, "pathLength");


--
-- Name: idx_812eb05f7451ca757fb98444ce; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX idx_812eb05f7451ca757fb98444ce ON public.tag_entity USING btree (name);


--
-- Name: idx_execution_entity_stopped_at_status_deleted_at; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX idx_execution_entity_stopped_at_status_deleted_at ON public.execution_entity USING btree ("stoppedAt", status, "deletedAt") WHERE (("stoppedAt" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- Name: idx_execution_entity_wait_till_status_deleted_at; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX idx_execution_entity_wait_till_status_deleted_at ON public.execution_entity USING btree ("waitTill", status, "deletedAt") WHERE (("waitTill" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- Name: idx_execution_entity_workflow_id_started_at; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX idx_execution_entity_workflow_id_started_at ON public.execution_entity USING btree ("workflowId", "startedAt") WHERE (("startedAt" IS NOT NULL) AND ("deletedAt" IS NULL));


--
-- Name: idx_workflows_tags_workflow_id; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX idx_workflows_tags_workflow_id ON public.workflows_tags USING btree ("workflowId");


--
-- Name: pk_credentials_entity_id; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX pk_credentials_entity_id ON public.credentials_entity USING btree (id);


--
-- Name: pk_tag_entity_id; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX pk_tag_entity_id ON public.tag_entity USING btree (id);


--
-- Name: pk_workflow_entity_id; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX pk_workflow_entity_id ON public.workflow_entity USING btree (id);


--
-- Name: project_relation_role_idx; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX project_relation_role_idx ON public.project_relation USING btree (role);


--
-- Name: project_relation_role_project_idx; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX project_relation_role_project_idx ON public.project_relation USING btree ("projectId", role);


--
-- Name: user_role_idx; Type: INDEX; Schema: public; Owner: n8n
--

CREATE INDEX user_role_idx ON public."user" USING btree ("roleSlug");


--
-- Name: variables_global_key_unique; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX variables_global_key_unique ON public.variables USING btree (key) WHERE ("projectId" IS NULL);


--
-- Name: variables_project_key_unique; Type: INDEX; Schema: public; Owner: n8n
--

CREATE UNIQUE INDEX variables_project_key_unique ON public.variables USING btree ("projectId", key) WHERE ("projectId" IS NOT NULL);


--
-- Name: idx_aprobado_candidato; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_aprobado_candidato ON rag_system.documento_aprobado USING btree (candidato_id);


--
-- Name: idx_aprobado_tipo; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_aprobado_tipo ON rag_system.documento_aprobado USING btree (tipo);


--
-- Name: idx_candidato_datos_completos_unique; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE UNIQUE INDEX idx_candidato_datos_completos_unique ON rag_system.candidato USING btree (lower(TRIM(BOTH FROM nombre)), lower(TRIM(BOTH FROM apellido)), COALESCE(lower(TRIM(BOTH FROM email)), '___SIN_EMAIL___'::text), COALESCE(lower(TRIM(BOTH FROM telefono)), '___SIN_TELEFONO___'::text));


--
-- Name: idx_candidato_email; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_candidato_email ON rag_system.candidato USING btree (email);


--
-- Name: idx_candidato_email_temp; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_candidato_email_temp ON rag_system.candidato USING btree (email) WHERE ((email)::text ~~ 'temp_%'::text);


--
-- Name: idx_candidato_hash; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_candidato_hash ON rag_system.candidato USING btree (hash_candidato);


--
-- Name: idx_candidato_perfil; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_candidato_perfil ON rag_system.candidato USING gin (perfil);


--
-- Name: idx_candidato_uuid; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE UNIQUE INDEX idx_candidato_uuid ON rag_system.candidato USING btree (candidato_uuid);


--
-- Name: idx_chunk_doc; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_chunk_doc ON rag_system.documento_chunk USING btree (documento_id);


--
-- Name: idx_chunk_documento_uuid; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_chunk_documento_uuid ON rag_system.documento_chunk USING btree (documento_uuid);


--
-- Name: idx_chunk_metadata; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_chunk_metadata ON rag_system.documento_chunk USING gin (metadata);


--
-- Name: idx_chunk_uuid; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE UNIQUE INDEX idx_chunk_uuid ON rag_system.documento_chunk USING btree (chunk_uuid);


--
-- Name: idx_documento_staging_uuid; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE UNIQUE INDEX idx_documento_staging_uuid ON rag_system.documento_staging USING btree (documento_uuid);


--
-- Name: idx_rag_fecha; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_rag_fecha ON rag_system.rag_consulta USING btree (created_at DESC);


--
-- Name: idx_rag_usuario; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_rag_usuario ON rag_system.rag_consulta USING btree (usuario_id);


--
-- Name: idx_rechazado_fecha; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_rechazado_fecha ON rag_system.documento_rechazado USING btree (rechazado_at);


--
-- Name: idx_rechazado_hash; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_rechazado_hash ON rag_system.documento_rechazado USING btree (hash_archivo);


--
-- Name: idx_staging_estado; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_staging_estado ON rag_system.documento_staging USING btree (estado);


--
-- Name: idx_staging_hash; Type: INDEX; Schema: rag_system; Owner: n8n
--

CREATE INDEX idx_staging_hash ON rag_system.documento_staging USING btree (hash_archivo);


--
-- Name: v_candidatos_completos _RETURN; Type: RULE; Schema: rag_system; Owner: n8n
--

CREATE OR REPLACE VIEW rag_system.v_candidatos_completos AS
 SELECT c.id,
    c.nombre,
    c.apellido,
    c.email,
    c.perfil,
    count(da.id) AS documentos_aprobados,
    max(da.aprobado_at) AS ultimo_documento
   FROM (rag_system.candidato c
     LEFT JOIN rag_system.documento_aprobado da ON ((c.id = da.candidato_id)))
  GROUP BY c.id;


--
-- Name: workflow_entity workflow_version_increment; Type: TRIGGER; Schema: public; Owner: n8n
--

CREATE TRIGGER workflow_version_increment BEFORE UPDATE ON public.workflow_entity FOR EACH ROW EXECUTE FUNCTION public.increment_workflow_version();


--
-- Name: candidato trigger_actualizar_hash_candidato; Type: TRIGGER; Schema: rag_system; Owner: n8n
--

CREATE TRIGGER trigger_actualizar_hash_candidato BEFORE INSERT OR UPDATE ON rag_system.candidato FOR EACH ROW EXECUTE FUNCTION rag_system.actualizar_hash_candidato();


--
-- Name: documento_staging update_staging_updated_at; Type: TRIGGER; Schema: rag_system; Owner: n8n
--

CREATE TRIGGER update_staging_updated_at BEFORE UPDATE ON rag_system.documento_staging FOR EACH ROW EXECUTE FUNCTION rag_system.update_updated_at_column();


--
-- Name: workflow_entity FK_08d6c67b7f722b0039d9d5ed620; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.workflow_entity
    ADD CONSTRAINT "FK_08d6c67b7f722b0039d9d5ed620" FOREIGN KEY ("activeVersionId") REFERENCES public.workflow_history("versionId") ON DELETE RESTRICT;


--
-- Name: insights_metadata FK_1d8ab99d5861c9388d2dc1cf733; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "FK_1d8ab99d5861c9388d2dc1cf733" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- Name: workflow_history FK_1e31657f5fe46816c34be7c1b4b; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.workflow_history
    ADD CONSTRAINT "FK_1e31657f5fe46816c34be7c1b4b" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_1f4998c8a7dec9e00a9ab15550e; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_1f4998c8a7dec9e00a9ab15550e" FOREIGN KEY ("revisionOfMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- Name: oauth_user_consents FK_21e6c3c2d78a097478fae6aaefa; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "FK_21e6c3c2d78a097478fae6aaefa" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: insights_metadata FK_2375a1eda085adb16b24615b69c; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.insights_metadata
    ADD CONSTRAINT "FK_2375a1eda085adb16b24615b69c" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE SET NULL;


--
-- Name: chat_hub_messages FK_25c9736e7f769f3a005eef4b372; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_25c9736e7f769f3a005eef4b372" FOREIGN KEY ("retryOfMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- Name: execution_metadata FK_31d0b4c93fb85ced26f6005cda3; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.execution_metadata
    ADD CONSTRAINT "FK_31d0b4c93fb85ced26f6005cda3" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- Name: shared_credentials FK_416f66fc846c7c442970c094ccf; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "FK_416f66fc846c7c442970c094ccf" FOREIGN KEY ("credentialsId") REFERENCES public.credentials_entity(id) ON DELETE CASCADE;


--
-- Name: variables FK_42f6c766f9f9d2edcc15bdd6e9b; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.variables
    ADD CONSTRAINT "FK_42f6c766f9f9d2edcc15bdd6e9b" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: chat_hub_agents FK_441ba2caba11e077ce3fbfa2cd8; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.chat_hub_agents
    ADD CONSTRAINT "FK_441ba2caba11e077ce3fbfa2cd8" FOREIGN KEY ("ownerId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: project_relation FK_5f0643f6717905a05164090dde7; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_5f0643f6717905a05164090dde7" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: project_relation FK_61448d56d61802b5dfde5cdb002; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_61448d56d61802b5dfde5cdb002" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: insights_by_period FK_6414cfed98daabbfdd61a1cfbc0; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.insights_by_period
    ADD CONSTRAINT "FK_6414cfed98daabbfdd61a1cfbc0" FOREIGN KEY ("metaId") REFERENCES public.insights_metadata("metaId") ON DELETE CASCADE;


--
-- Name: oauth_authorization_codes FK_64d965bd072ea24fb6da55468cd; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.oauth_authorization_codes
    ADD CONSTRAINT "FK_64d965bd072ea24fb6da55468cd" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_6afb260449dd7a9b85355d4e0c9; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_6afb260449dd7a9b85355d4e0c9" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE SET NULL;


--
-- Name: insights_raw FK_6e2e33741adef2a7c5d66befa4e; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.insights_raw
    ADD CONSTRAINT "FK_6e2e33741adef2a7c5d66befa4e" FOREIGN KEY ("metaId") REFERENCES public.insights_metadata("metaId") ON DELETE CASCADE;


--
-- Name: oauth_access_tokens FK_7234a36d8e49a1fa85095328845; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT "FK_7234a36d8e49a1fa85095328845" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: installed_nodes FK_73f857fc5dce682cef8a99c11dbddbc969618951; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.installed_nodes
    ADD CONSTRAINT "FK_73f857fc5dce682cef8a99c11dbddbc969618951" FOREIGN KEY (package) REFERENCES public.installed_packages("packageName") ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: oauth_access_tokens FK_78b26968132b7e5e45b75876481; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT "FK_78b26968132b7e5e45b75876481" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: chat_hub_sessions FK_7bc13b4c7e6afbfaf9be326c189; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_7bc13b4c7e6afbfaf9be326c189" FOREIGN KEY ("credentialId") REFERENCES public.credentials_entity(id) ON DELETE SET NULL;


--
-- Name: folder FK_804ea52f6729e3940498bd54d78; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "FK_804ea52f6729e3940498bd54d78" FOREIGN KEY ("parentFolderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- Name: shared_credentials FK_812c2852270da1247756e77f5a4; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.shared_credentials
    ADD CONSTRAINT "FK_812c2852270da1247756e77f5a4" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: test_case_execution FK_8e4b4774db42f1e6dda3452b2af; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "FK_8e4b4774db42f1e6dda3452b2af" FOREIGN KEY ("testRunId") REFERENCES public.test_run(id) ON DELETE CASCADE;


--
-- Name: data_table_column FK_930b6e8faaf88294cef23484160; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.data_table_column
    ADD CONSTRAINT "FK_930b6e8faaf88294cef23484160" FOREIGN KEY ("dataTableId") REFERENCES public.data_table(id) ON DELETE CASCADE;


--
-- Name: folder_tag FK_94a60854e06f2897b2e0d39edba; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "FK_94a60854e06f2897b2e0d39edba" FOREIGN KEY ("folderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- Name: execution_annotations FK_97f863fa83c4786f19565084960; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.execution_annotations
    ADD CONSTRAINT "FK_97f863fa83c4786f19565084960" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- Name: chat_hub_agents FK_9c61ad497dcbae499c96a6a78ba; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.chat_hub_agents
    ADD CONSTRAINT "FK_9c61ad497dcbae499c96a6a78ba" FOREIGN KEY ("credentialId") REFERENCES public.credentials_entity(id) ON DELETE SET NULL;


--
-- Name: chat_hub_sessions FK_9f9293d9f552496c40e0d1a8f80; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_9f9293d9f552496c40e0d1a8f80" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- Name: execution_annotation_tags FK_a3697779b366e131b2bbdae2976; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "FK_a3697779b366e131b2bbdae2976" FOREIGN KEY ("tagId") REFERENCES public.annotation_tag_entity(id) ON DELETE CASCADE;


--
-- Name: shared_workflow FK_a45ea5f27bcfdc21af9b4188560; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "FK_a45ea5f27bcfdc21af9b4188560" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: workflow_dependency FK_a4ff2d9b9628ea988fa9e7d0bf8; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.workflow_dependency
    ADD CONSTRAINT "FK_a4ff2d9b9628ea988fa9e7d0bf8" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: oauth_user_consents FK_a651acea2f6c97f8c4514935486; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.oauth_user_consents
    ADD CONSTRAINT "FK_a651acea2f6c97f8c4514935486" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_refresh_tokens FK_a699f3ed9fd0c1b19bc2608ac53; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.oauth_refresh_tokens
    ADD CONSTRAINT "FK_a699f3ed9fd0c1b19bc2608ac53" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: folder FK_a8260b0b36939c6247f385b8221; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.folder
    ADD CONSTRAINT "FK_a8260b0b36939c6247f385b8221" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: oauth_authorization_codes FK_aa8d3560484944c19bdf79ffa16; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.oauth_authorization_codes
    ADD CONSTRAINT "FK_aa8d3560484944c19bdf79ffa16" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_acf8926098f063cdbbad8497fd1; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_acf8926098f063cdbbad8497fd1" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE SET NULL;


--
-- Name: oauth_refresh_tokens FK_b388696ce4d8be7ffbe8d3e4b69; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.oauth_refresh_tokens
    ADD CONSTRAINT "FK_b388696ce4d8be7ffbe8d3e4b69" FOREIGN KEY ("clientId") REFERENCES public.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: execution_annotation_tags FK_c1519757391996eb06064f0e7c8; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.execution_annotation_tags
    ADD CONSTRAINT "FK_c1519757391996eb06064f0e7c8" FOREIGN KEY ("annotationId") REFERENCES public.execution_annotations(id) ON DELETE CASCADE;


--
-- Name: data_table FK_c2a794257dee48af7c9abf681de; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.data_table
    ADD CONSTRAINT "FK_c2a794257dee48af7c9abf681de" FOREIGN KEY ("projectId") REFERENCES public.project(id) ON DELETE CASCADE;


--
-- Name: project_relation FK_c6b99592dc96b0d836d7a21db91; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.project_relation
    ADD CONSTRAINT "FK_c6b99592dc96b0d836d7a21db91" FOREIGN KEY (role) REFERENCES public.role(slug);


--
-- Name: test_run FK_d6870d3b6e4c185d33926f423c8; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.test_run
    ADD CONSTRAINT "FK_d6870d3b6e4c185d33926f423c8" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: shared_workflow FK_daa206a04983d47d0a9c34649ce; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.shared_workflow
    ADD CONSTRAINT "FK_daa206a04983d47d0a9c34649ce" FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: folder_tag FK_dc88164176283de80af47621746; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.folder_tag
    ADD CONSTRAINT "FK_dc88164176283de80af47621746" FOREIGN KEY ("tagId") REFERENCES public.tag_entity(id) ON DELETE CASCADE;


--
-- Name: user_api_keys FK_e131705cbbc8fb589889b02d457; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.user_api_keys
    ADD CONSTRAINT "FK_e131705cbbc8fb589889b02d457" FOREIGN KEY ("userId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: chat_hub_messages FK_e22538eb50a71a17954cd7e076c; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_e22538eb50a71a17954cd7e076c" FOREIGN KEY ("sessionId") REFERENCES public.chat_hub_sessions(id) ON DELETE CASCADE;


--
-- Name: test_case_execution FK_e48965fac35d0f5b9e7f51d8c44; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.test_case_execution
    ADD CONSTRAINT "FK_e48965fac35d0f5b9e7f51d8c44" FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE SET NULL;


--
-- Name: chat_hub_messages FK_e5d1fa722c5a8d38ac204746662; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.chat_hub_messages
    ADD CONSTRAINT "FK_e5d1fa722c5a8d38ac204746662" FOREIGN KEY ("previousMessageId") REFERENCES public.chat_hub_messages(id) ON DELETE CASCADE;


--
-- Name: chat_hub_sessions FK_e9ecf8ede7d989fcd18790fe36a; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.chat_hub_sessions
    ADD CONSTRAINT "FK_e9ecf8ede7d989fcd18790fe36a" FOREIGN KEY ("ownerId") REFERENCES public."user"(id) ON DELETE CASCADE;


--
-- Name: user FK_eaea92ee7bfb9c1b6cd01505d56; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT "FK_eaea92ee7bfb9c1b6cd01505d56" FOREIGN KEY ("roleSlug") REFERENCES public.role(slug);


--
-- Name: role_scope FK_role; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "FK_role" FOREIGN KEY ("roleSlug") REFERENCES public.role(slug) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: role_scope FK_scope; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.role_scope
    ADD CONSTRAINT "FK_scope" FOREIGN KEY ("scopeSlug") REFERENCES public.scope(slug) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: auth_identity auth_identity_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.auth_identity
    ADD CONSTRAINT "auth_identity_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."user"(id);


--
-- Name: execution_data execution_data_fk; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.execution_data
    ADD CONSTRAINT execution_data_fk FOREIGN KEY ("executionId") REFERENCES public.execution_entity(id) ON DELETE CASCADE;


--
-- Name: execution_entity fk_execution_entity_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.execution_entity
    ADD CONSTRAINT fk_execution_entity_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: webhook_entity fk_webhook_entity_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.webhook_entity
    ADD CONSTRAINT fk_webhook_entity_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: workflow_entity fk_workflow_parent_folder; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.workflow_entity
    ADD CONSTRAINT fk_workflow_parent_folder FOREIGN KEY ("parentFolderId") REFERENCES public.folder(id) ON DELETE CASCADE;


--
-- Name: workflow_statistics fk_workflow_statistics_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.workflow_statistics
    ADD CONSTRAINT fk_workflow_statistics_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: workflows_tags fk_workflows_tags_tag_id; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT fk_workflows_tags_tag_id FOREIGN KEY ("tagId") REFERENCES public.tag_entity(id) ON DELETE CASCADE;


--
-- Name: workflows_tags fk_workflows_tags_workflow_id; Type: FK CONSTRAINT; Schema: public; Owner: n8n
--

ALTER TABLE ONLY public.workflows_tags
    ADD CONSTRAINT fk_workflows_tags_workflow_id FOREIGN KEY ("workflowId") REFERENCES public.workflow_entity(id) ON DELETE CASCADE;


--
-- Name: candidato_documento candidato_documento_candidato_id_fkey; Type: FK CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.candidato_documento
    ADD CONSTRAINT candidato_documento_candidato_id_fkey FOREIGN KEY (candidato_id) REFERENCES rag_system.candidato(id) ON DELETE CASCADE;


--
-- Name: candidato_documento candidato_documento_documento_id_fkey; Type: FK CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.candidato_documento
    ADD CONSTRAINT candidato_documento_documento_id_fkey FOREIGN KEY (documento_id) REFERENCES rag_system.documento_aprobado(id) ON DELETE CASCADE;


--
-- Name: documento_aprobado documento_aprobado_aprobado_por_fkey; Type: FK CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_aprobado
    ADD CONSTRAINT documento_aprobado_aprobado_por_fkey FOREIGN KEY (aprobado_por) REFERENCES rag_system.usuario(id);


--
-- Name: documento_aprobado documento_aprobado_candidato_id_fkey; Type: FK CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_aprobado
    ADD CONSTRAINT documento_aprobado_candidato_id_fkey FOREIGN KEY (candidato_id) REFERENCES rag_system.candidato(id);


--
-- Name: documento_aprobado documento_aprobado_creado_por_fkey; Type: FK CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_aprobado
    ADD CONSTRAINT documento_aprobado_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES rag_system.usuario(id);


--
-- Name: documento_chunk documento_chunk_documento_id_fkey; Type: FK CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_chunk
    ADD CONSTRAINT documento_chunk_documento_id_fkey FOREIGN KEY (documento_id) REFERENCES rag_system.documento_aprobado(id) ON DELETE CASCADE;


--
-- Name: documento_rechazado documento_rechazado_creado_por_fkey; Type: FK CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_rechazado
    ADD CONSTRAINT documento_rechazado_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES rag_system.usuario(id);


--
-- Name: documento_rechazado documento_rechazado_rechazado_por_fkey; Type: FK CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_rechazado
    ADD CONSTRAINT documento_rechazado_rechazado_por_fkey FOREIGN KEY (rechazado_por) REFERENCES rag_system.usuario(id);


--
-- Name: documento_staging documento_staging_creado_por_fkey; Type: FK CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.documento_staging
    ADD CONSTRAINT documento_staging_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES rag_system.usuario(id);


--
-- Name: rag_consulta rag_consulta_usuario_id_fkey; Type: FK CONSTRAINT; Schema: rag_system; Owner: n8n
--

ALTER TABLE ONLY rag_system.rag_consulta
    ADD CONSTRAINT rag_consulta_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES rag_system.usuario(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: n8n
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


--
-- PostgreSQL database dump complete
--

\unrestrict 5WxhQ1w7KbKJiY9T98GRfua3EvNfxlgddaUpTmwEJ6MtJfFX3arAe0YRj11UOWP

