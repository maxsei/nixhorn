FROM golang:1.25-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download


COPY main.go main.go
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o patch-longhorn-manager-adm-ctl .

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /app/patch-longhorn-manager-adm-ctl /patch-longhorn-manager-adm-ctl

ENTRYPOINT ["/patch-longhorn-manager-adm-ctl"]
