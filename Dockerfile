# ---------- BUILDER STAGE ----------
FROM golang:1.26-alpine AS builder

ENV CGO_ENABLED=1
ENV GOCACHE=/root/.cache/go-build

WORKDIR /app

# Install build dependencies
RUN --mount=type=cache,target=/var/cache/apk,sharing=locked \
    --mount=type=cache,target=/var/lib/apk,sharing=locked \
    apk add --no-cache \
        --repository="https://dl-cdn.alpinelinux.org/alpine/edge/main" \
        --repository="https://dl-cdn.alpinelinux.org/alpine/edge/community" \
        build-base \
        libheif-dev \
        ffmpeg

# Copy go mod files first (better caching)
COPY go.mod go.sum ./
RUN go mod download

# Copy project files
COPY . .

# Build binary
RUN go build -o govd ./cmd/govd

# ---------- RUNTIME STAGE ----------
FROM alpine:3.22 AS runtime

WORKDIR /app

# Install runtime dependencies (NO version locking)
RUN --mount=type=cache,target=/var/cache/apk,sharing=locked \
    --mount=type=cache,target=/var/lib/apk,sharing=locked \
    apk add --no-cache \
        --repository="https://dl-cdn.alpinelinux.org/alpine/edge/main" \
        --repository="https://dl-cdn.alpinelinux.org/alpine/edge/community" \
        ffmpeg \
        libheif

# Copy built binary from builder
COPY --from=builder /app/govd .

# Expose port (if needed)
EXPOSE 8080

# Run the bot
ENTRYPOINT ["./govd"]
