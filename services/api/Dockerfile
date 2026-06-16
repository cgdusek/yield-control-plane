FROM rust:1.95-slim AS builder
WORKDIR /app
COPY . .
RUN cargo build --release -p institutional-yield-api

FROM debian:stable-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --system --uid 10001 appuser
WORKDIR /app
COPY --from=builder /app/target/release/institutional-yield-api /usr/local/bin/institutional-yield-api
USER appuser
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/institutional-yield-api"]
