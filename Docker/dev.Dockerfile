# syntax=docker/dockerfile:1

FROM golang:1.25.3

# Définir le répertoire de travail
WORKDIR /app

ENV GOPROXY=direct
ENV GOINSECURE="github.com,proxy.golang.org"
ENV GOSUMDB=off

# Installer Air pour le hot-reloading (version compatible avec Go 1.23)
RUN go install github.com/cosmtrek/air@v1.49.0

# Télécharger les dépendances Go
COPY go.mod go.sum ./
RUN go mod download

# Copier le code source et les fichiers de configuration
COPY . .

# Créer le dossier tmp pour Air
RUN mkdir -p tmp

# Exposer le port 3000
EXPOSE 3000

# Utiliser Air pour le hot-reloading
CMD ["air", "-c", ".air.toml"]
 