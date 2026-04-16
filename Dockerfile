# ---------- BUILD STAGE ----------
FROM golang:1.26-alpine AS builder

# Install essential build tools and libraries
RUN apk add --no-cache \
    build-base \
    pkgconf \
    libheif-dev \
    libwebp-dev

WORKDIR /app

# 1. Copy only dependency files first
COPY go.mod go.sum ./
RUN go mod download

# 2. Copy the rest of the source
COPY . .

# 3. Build with memory-efficient flags
# -ldflags="-s -w" reduces binary size
# We target the specific main.go file
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o govd ./cmd/downbot/main.go

# ---------- RUNTIME STAGE ----------
FROM alpine:3.21

# Install runtime libraries
RUN apk add --no-cache \
    libheif \
    libwebp \
    ca-certificates

WORKDIR /root/

# Copy only the compiled binary
COPY --from=builder /app/govd .

# Run the application
CMD ["./govd"]
