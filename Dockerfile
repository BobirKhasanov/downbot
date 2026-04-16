# ---------- BUILD STAGE ----------
FROM golang:1.24-alpine AS builder

# Install build-base and core dev libraries
RUN apk add --no-cache \
    build-base \
    pkgconf \
    libheif-dev \
    libwebp-dev

WORKDIR /app

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build the specific main package path
RUN CGO_ENABLED=1 GOOS=linux go build -o govd ./cmd/downbot/main.go

# ---------- RUNTIME STAGE ----------
FROM alpine:3.21

# Install core runtime libraries
# We add libheif and libwebp. 
# Note: Basic decoding is included in libheif.
RUN apk add --no-cache \
    libheif \
    libwebp \
    ca-certificates

WORKDIR /root/

# Copy the binary from the builder stage
COPY --from=builder /app/govd .

# Run the app
CMD ["./govd"]
