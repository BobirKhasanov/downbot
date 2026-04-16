# ---------- BUILD STAGE ----------
FROM golang:1.24-alpine AS builder

# We enable the community repo to ensure we find the heif plugins
RUN apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/v3.21/community \
    build-base \
    pkgconf \
    libheif-dev \
    libwebp-dev \
    libheif-plugins

WORKDIR /app

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build the specific main package
RUN CGO_ENABLED=1 GOOS=linux go build -o govd ./cmd/downbot/main.go

# ---------- RUNTIME STAGE ----------
FROM alpine:3.21

# Install runtime libraries from community repo
RUN apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/v3.21/community \
    libheif \
    libwebp \
    libheif-plugins \
    ca-certificates

WORKDIR /root/

# Copy the binary from the builder stage
COPY --from=builder /app/govd .

# Run the app
CMD ["./govd"]
