# Étape de build
FROM golang:1.25 AS builder

WORKDIR /app

# Copier les fichiers de dépendances
COPY go.mod go.sum ./
RUN go mod download
RUN go mod tidy

# Copier le reste du code source
COPY . .

# Compiler l'application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o guestbook .

# Étape finale
FROM scratch

WORKDIR /

# Copier l'exécutable compilé depuis l'étape de build
COPY --from=builder /app/guestbook .

# Copier le dossier public
COPY --from=builder /app/public ./public

# Exposer le port sur lequel l'application écoute
EXPOSE 3000

# Commande pour exécuter l'application
CMD ["./guestbook"]