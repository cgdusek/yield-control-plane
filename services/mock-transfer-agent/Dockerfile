FROM rust:1.95-slim AS builder
WORKDIR /app
COPY . .
RUN cargo build --release -p institutional-yield-mock-transfer-agent

FROM debian:stable-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/* \
  && useradd --system --uid 10001 appuser
COPY --from=builder /app/target/release/institutional-yield-mock-transfer-agent /usr/local/bin/institutional-yield-mock-transfer-agent
USER appuser
EXPOSE 8090
ENTRYPOINT ["/usr/local/bin/institutional-yield-mock-transfer-agent"]
