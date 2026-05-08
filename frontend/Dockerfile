FROM node:20-alpine

WORKDIR /app

# Instalar pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copiar archivos de dependencias
COPY package.json pnpm-lock.yaml ./

# Instalar dependencias
RUN pnpm install --frozen-lockfile

# Copiar código fuente
COPY . .

# Exponer puerto
EXPOSE 5050

# Comando de desarrollo
CMD ["pnpm", "dev", "--host", "0.0.0.0"]
