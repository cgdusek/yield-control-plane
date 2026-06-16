FROM rust:1.95-slim AS builder
WORKDIR /app
COPY . .
RUN cargo build --release -p institutional-yield-worker

FROM debian:stable-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --system --uid 10001 appuser
COPY --from=builder /app/target/release/institutional-yield-worker /usr/local/bin/institutional-yield-worker
USER appuser
ENTRYPOINT ["/usr/local/bin/institutional-yield-worker"]
