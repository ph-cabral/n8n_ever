FROM n8nio/n8n:latest

USER root

# Instalar Chromium y dependencias en Alpine
RUN apk add --no-cache \
  chromium \
  nss \
  freetype \
  harfbuzz \
  ca-certificates \
  ttf-freefont

# Instalar playwright-core (sin browsers)
RUN npm init -y \
 && npm install playwright-core

ENV PLAYWRIGHT_BROWSERS_PATH=0
ENV CHROME_BIN=/usr/bin/chromium-browser

USER node
