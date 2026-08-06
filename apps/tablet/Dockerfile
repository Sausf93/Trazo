# App tablet de Trazo (Flutter web) — build multi-etapa + Nginx.
#   1) compila la app web con la imagen oficial de Flutter
#   2) sirve el resultado estático con Nginx
#
# La URL de la API se hornea en compilación (el navegador corre en el host, así
# que apunta al puerto publicado del backend).
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# Dependencias primero (mejor cache).
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

# Resto del proyecto (incluye web/ y assets/) y build.
COPY . .
RUN flutter build web --release --dart-define=API_URL=http://localhost:8000

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
