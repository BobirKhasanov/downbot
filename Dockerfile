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

# Copy the entire source
COPY . .

# DECISION: We use "." so Go finds the main package wherever it is in /app
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o govd .

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
