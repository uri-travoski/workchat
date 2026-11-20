# Build stage
FROM golang:alpine AS builder
ENV GOTOOLCHAIN=auto

WORKDIR /build

RUN apk add --no-cache git ca-certificates

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Static pure Go build
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o workchat-server cmd/server/main.go

# Production stage
FROM alpine:3.20

WORKDIR /app

RUN apk add --no-cache ca-certificates tzdata

COPY --from=builder /build/workchat-server /usr/local/bin/workchat-server
COPY --from=builder /build/static ./static

VOLUME /data
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1:8080/healthz || exit 1

ENTRYPOINT ["/usr/local/bin/workchat-server"]
