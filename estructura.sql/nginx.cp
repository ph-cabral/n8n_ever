# nginx.conf - Configuración con soporte para archivos grandes
events {
    worker_connections 1024;
}

http {
    upstream n8n_backend {
        server n8n:5678;
    }

    upstream frontend {
        server frontend:5050;
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=webhook_limit:10m rate=10r/s;

    # ?? CONFIGURACIÓN GLOBAL PARA ARCHIVOS GRANDES
    client_max_body_size 100M;           # Tamaño máximo de archivo
    client_body_timeout 300s;            # Timeout para subida
    client_body_buffer_size 128k;        # Buffer para body
    proxy_read_timeout 300s;             # Timeout lectura proxy
    proxy_connect_timeout 300s;          # Timeout conexión proxy
    proxy_send_timeout 300s;             # Timeout envío proxy
    send_timeout 300s;                   # Timeout envío general

    server {
        listen 80;
        server_name 10.10.0.159;

        # Frontend
        location / {
            proxy_pass http://frontend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # n8n webhooks (con rate limiting y soporte archivos grandes)
        location /webhook/ {
            limit_req zone=webhook_limit burst=20 nodelay;
            
            # ?? CRÍTICO: Deshabilitar buffering para archivos grandes
            proxy_request_buffering off;
            proxy_buffering off;
            
            proxy_pass http://n8n_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # ?? Configuración específica para esta ruta
            client_max_body_size 100M;
            proxy_read_timeout 300s;
            proxy_connect_timeout 300s;
            proxy_send_timeout 300s;
            
            # CORS para desarrollo
            add_header Access-Control-Allow-Origin "http://10.10.0.159:5050" always;
            add_header Access-Control-Allow-Origin "http://10.10.0.159" always;
            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With" always;
            add_header Access-Control-Max-Age 3600 always;
            
            if ($request_method = 'OPTIONS') {
                return 204;
            }
        }

        # n8n editor (proteger en producción)
        location /n8n/ {
            # Agregar auth básica en producción
            # auth_basic "Restricted";
            # auth_basic_user_file /etc/nginx/.htpasswd;
            
            proxy_pass http://n8n_backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            
            # WebSocket support para el editor
            proxy_http_version 1.1;
            proxy_read_timeout 86400;
        }

        # ?? ENDPOINT ESPECÍFICO PARA UPLOAD (opcional, más restrictivo)
        location /webhook-test/calidad {
            limit_req zone=webhook_limit burst=5 nodelay;
            
            proxy_request_buffering off;
            client_max_body_size 150M;  # Más espacio para este endpoint
            
            proxy_pass http://n8n_backend/webhook-test/calidad;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            
            proxy_read_timeout 600s;  # 10 minutos para archivos muy grandes
            
            add_header Access-Control-Allow-Origin "*" always;
            add_header Access-Control-Allow-Methods "POST, OPTIONS" always;
            add_header Access-Control-Allow-Headers "Content-Type" always;
            
            if ($request_method = 'OPTIONS') {
                return 204;
            }
        }
    }
}
