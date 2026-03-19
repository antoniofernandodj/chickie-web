FROM rust:1.89-slim AS builder

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    curl \
    unzip \
    perl \
    make \
    && rm -rf /var/lib/apt/lists/*

RUN cargo install wasm-bindgen-cli --version "0.2.106" --locked
RUN rustup target add wasm32-unknown-unknown

WORKDIR /app
COPY . .

# Build WASM (frontend)
RUN cargo build --lib \
    --target wasm32-unknown-unknown \
    --no-default-features \
    --features hydrate \
    --release \
    --profile wasm-release

# Processa o WASM com wasm-bindgen
RUN mkdir -p target/site/pkg && \
    wasm-bindgen \
    --target web \
    --out-dir target/site/pkg \
    target/wasm32-unknown-unknown/wasm-release/chickie_web.wasm

# Copia assets
RUN cp -r public/* target/site/ 2>/dev/null || true
RUN cp style/main.scss target/site/ 2>/dev/null || true

# Build servidor
RUN cargo build --bin chickie-web \
    --no-default-features \
    --features ssr \
    --release

# ---- Runtime ----
FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y \
    libssl3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/chickie-web ./
COPY --from=builder /app/target/site ./target/site

ENV LEPTOS_SITE_ROOT=/app/target/site
ENV LEPTOS_SITE_ADDR="0.0.0.0:3000"
ENV RUST_LOG=info

EXPOSE 3000
CMD ["./chickie-web"]