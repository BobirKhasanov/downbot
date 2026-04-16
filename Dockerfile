# ---------- BUILD STAGE ----------
FROM golang:1.26-alpine AS builder

RUN apk add --no-cache \
    build-base \
    pkgconf \
    libheif-dev \
    libwebp-dev

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build the binary
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o govd $(find . -name "main.go" | head -n 1)

# ---------- RUNTIME STAGE ----------
FROM alpine:3.21

# DECISION: We must include ffmpeg here for the bot to process videos
RUN apk add --no-cache \
    libheif \
    libwebp \
    ca-certificates \
    ffmpeg

WORKDIR /root/

# Copy the binary from the builder
COPY --from=builder /app/govd .

# Run the app
CMD ["./govd"]
