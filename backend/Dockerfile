# Builds the API and its admin tools into a small image with no shell.
FROM golang:1.27.3 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# Static binaries, so the runtime image needs no C library.
ENV CGO_ENABLED=0
RUN go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api \
 && go build -trimpath -ldflags="-s -w" -o /out/admin ./cmd/admin \
 && go build -trimpath -ldflags="-s -w" -o /out/backup ./cmd/backup

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/ /app/
USER nonroot
EXPOSE 8080
ENV HTTP_ADDR=:8080 LOG_FORMAT=json
ENTRYPOINT ["/app/api"]
