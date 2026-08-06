# Panel web de Trazo — imagen de desarrollo.
# Sirve Vite en modo dev con hot-reload, accesible desde fuera del contenedor.
FROM node:20-alpine

WORKDIR /app

# Instala dependencias primero para aprovechar la cache de capas.
COPY package.json package-lock.json* ./
RUN npm install

# Copia el resto del código.
COPY . .

# Vite dev server.
EXPOSE 5173

# --host expone el servidor en 0.0.0.0 para que sea accesible desde el host.
CMD ["npm", "run", "dev", "--", "--host"]
