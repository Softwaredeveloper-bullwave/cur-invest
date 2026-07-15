# ── Stage 1: build Flutter web ──
# Project needs Flutter >=3.44 / Dart >=3.12 (see pubspec.lock).
# cirruslabs/flutter:stable is frozen at ~3.41 — use a newer Flutter image instead.
# Flutter 3.44.1 ships with Dart 3.12.1, but this project requires >=3.12.2.
FROM ghcr.io/adrianjagielak/flutter:3.44.5 AS build

WORKDIR /app

RUN flutter config --enable-web
RUN flutter precache --web

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG API_BASE_URL=http://127.0.0.1:8000/api/v1
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# ── Stage 2: serve with nginx ──
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
