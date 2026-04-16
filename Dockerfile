# ---------- BUILD STAGE ----------
FROM golang:1.26-alpine AS builder

RUN apk add --no-cache \
    build-base \
    pkgconf \
    libheif-dev \
    libwebp-dev

WORKDIR /app

# Copy dependency files
COPY go.mod go.sum ./
RUN go mod download

# Copy the entire source code
COPY . .

# DECISION: Find the main.go file and build it wherever it lives
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o govd $(find . -name "main.go" | head -n 1)

# ---------- RUNTIME STAGE ----------
FROM alpine:3.21

RUN apk add --no-cache \
    libheif \
    libwebp \
    ca-certificates

WORKDIR /root/

# Copy the binary from the builder stage
COPY --from=builder /app/govd .

# Run the app
CMD ["./govd"]
