# ---- Build Stage ----
FROM rust:1.90-slim AS builder

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    curl \
    unzip \
    perl \
    && rm -rf /var/lib/apt/lists/*

# Instala cargo-leptos e wasm target
RUN cargo install cargo-leptos --locked
RUN rustup target add wasm32-unknown-unknown

WORKDIR /app

# Cache de dependências
COPY Cargo.toml Cargo.lock ./
RUN mkdir -p src && \
    echo "fn main() {}" > src/main.rs && \
    echo "" > src/lib.rs && \
    echo "" > src/app.rs
RUN cargo leptos build --release || true

# Build real
COPY . .
RUN cargo leptos build --release

# ---- Runtime Stage ----
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y \
    libssl3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copia o binário e os assets gerados
COPY --from=builder /app/target/release/chickie-web ./
COPY --from=builder /app/target/site ./target/site

ENV LEPTOS_SITE_ROOT=/app/target/site
ENV RUST_LOG=info

EXPOSE 3000

CMD ["./chickie-web"]
