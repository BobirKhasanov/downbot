# ---------- BUILD STAGE ----------
FROM golang:1.24-alpine AS builder

# We need build-base (gcc, etc.) for CGO to work with image libraries
RUN apk add --no-cache \
    build-base \
    pkgconf \
    libheif-dev \
    libwebp-dev \
    libheif-plugins-all

WORKDIR /app

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# DECISION: We point to ./cmd/downbot/main.go and enable CGO
RUN CGO_ENABLED=1 GOOS=linux go build -o govd ./cmd/downbot/main.go

# ---------- RUNTIME STAGE ----------
FROM alpine:3.21

# IMPORTANT: The binary needs the shared libraries to run.
# We install the runtime versions (not -dev) here.
RUN apk add --no-cache \
    libheif \
    libwebp \
    libheif-plugins-all \
    ca-certificates

WORKDIR /root/

# Copy the binary from the builder stage
COPY --from=builder /app/govd .

# Run the app
CMD ["./govd"]
