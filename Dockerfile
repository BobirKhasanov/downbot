# ---------- BUILD STAGE ----------
FROM golang:1.24-alpine AS builder

# Install build dependencies
# We replace libheif-plugins-all with specific working packages
RUN apk add --no-cache \
    build-base \
    pkgconf \
    libheif-dev \
    libwebp-dev \
    libheif-avif \
    libheif-jpeg \
    libheif-aom

WORKDIR /app

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build focusing on the specific main package path
RUN CGO_ENABLED=1 GOOS=linux go build -o govd ./cmd/downbot/main.go

# ---------- RUNTIME STAGE ----------
FROM alpine:3.21

# Install runtime libraries
# libheif-aom and libheif-avif are the standard for AVIF/HEIC in Alpine 3.21
RUN apk add --no-cache \
    libheif \
    libwebp \
    libheif-avif \
    libheif-jpeg \
    libheif-aom \
    ca-certificates

WORKDIR /root/

# Copy the binary from the builder stage
COPY --from=builder /app/govd .

# Run the app
CMD ["./govd"]
