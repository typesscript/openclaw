FROM node:22-bookworm

# -----------------------------
# Install Bun (required for build scripts)
# -----------------------------
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# -----------------------------
# Optional system packages hook
# -----------------------------
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# -----------------------------
# Install deps
# -----------------------------
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

# -----------------------------
# Build app
# -----------------------------
COPY . .
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build

# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# -----------------------------
# Permissions (important for Render/containers)
# -----------------------------
RUN chown -R node:node /app
RUN mkdir /data && chown -R node:node /data

# -----------------------------
# Security: run as non-root
# -----------------------------
USER node

# -----------------------------
# Start gateway server
# -----------------------------
# --bind lan exposes to 0.0.0.0 so Render can detect it
# --port 8080 matches Render default PORT
CMD ["node", "dist/index.js", "gateway", "--allow-unconfigured", "--bind", "lan", "--port", "8080"]
