FROM golang:1-alpine3.22 AS builder

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download
RUN go mod tidy

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o guestbook .

FROM scratch
COPY --from=builder /app/guestbook .
COPY --from=builder /app/public ./public

EXPOSE 3000

ENTRYPOINT ["./guestbook"]



