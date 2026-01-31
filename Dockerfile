# Versions managed in .versions file - these are fallback defaults for local builds
ARG NMAP_VERSION=7.94SVN
ARG GH_VERSION=2.86.0
ARG DOCKER_VERSION=29.2.0

# =============================================================================
# Base builder with common tools
# =============================================================================
FROM debian:bookworm-slim AS base
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget ca-certificates jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Stage: nmap
# =============================================================================
FROM base AS nmap-builder
ARG NMAP_VERSION
RUN mkdir -p /opt/tools/bin /opt/tools/nmap \
    && NMAP_URL=$(curl -sL https://api.github.com/repos/ernw/static-toolbox/releases \
      | jq -r "[.[] | select(.tag_name == \"nmap-v${NMAP_VERSION}\")][0].assets[] | select(.name | endswith(\"x86_64-portable.tar.gz\")) | .browser_download_url") \
    && curl -sL "$NMAP_URL" | tar -xz -C /opt/tools/nmap \
    && printf '#!/bin/sh\nNMAPDIR=/opt/tools/nmap/data exec /opt/tools/nmap/nmap "$@"\n' > /opt/tools/bin/nmap \
    && chmod +x /opt/tools/bin/nmap

# =============================================================================
# Stage: GitHub CLI
# =============================================================================
FROM base AS gh-builder
ARG GH_VERSION
RUN mkdir -p /opt/tools/bin \
    && curl -sL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
      | tar -xz -C /tmp \
    && cp /tmp/gh_${GH_VERSION}_linux_amd64/bin/gh /opt/tools/bin/

# =============================================================================
# Stage: gcloud CLI
# =============================================================================
FROM base AS gcloud-builder
RUN mkdir -p /opt/tools/bin /opt/tools/gcloud-config \
    && curl -sL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz" \
      | tar -xz -C /opt/tools \
    && /opt/tools/google-cloud-sdk/install.sh --quiet --path-update=false \
    && /opt/tools/google-cloud-sdk/bin/gcloud components install \
      app-engine-python app-engine-python-extras cloud-run-proxy gke-gcloud-auth-plugin --quiet \
    && ln -sf /opt/tools/google-cloud-sdk/bin/gcloud /opt/tools/bin/gcloud \
    && ln -sf /opt/tools/google-cloud-sdk/bin/gsutil /opt/tools/bin/gsutil \
    && ln -sf /opt/tools/google-cloud-sdk/bin/bq /opt/tools/bin/bq

# =============================================================================
# Stage: Docker CLI
# =============================================================================
FROM base AS docker-builder
ARG DOCKER_VERSION
RUN mkdir -p /opt/tools/bin \
    && curl -sL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" \
      | tar -xz -C /tmp \
    && cp /tmp/docker/docker /opt/tools/bin/

# =============================================================================
# Stage: make
# =============================================================================
FROM debian:bookworm-slim AS make-builder
RUN apt-get update && apt-get install -y --no-install-recommends make \
    && mkdir -p /opt/tools/bin \
    && cp /usr/bin/make /opt/tools/bin/

# =============================================================================
# Stage: pause binary (static, for scratch)
# =============================================================================
FROM alpine:latest AS pause-builder
RUN apk add --no-cache go \
    && echo 'package main; import ("os"; "os/signal"); func main() { c := make(chan os.Signal, 1); signal.Notify(c); <-c }' > /pause.go \
    && CGO_ENABLED=0 go build -ldflags="-s -w" -o /pause /pause.go

# =============================================================================
# Final minimal image (scratch)
# =============================================================================
FROM scratch

# Copy pause binary
COPY --from=pause-builder /pause /pause

# Copy from all builder stages
COPY --from=nmap-builder --chown=1000:1000 /opt/tools/ /opt/tools/
COPY --from=gh-builder --chown=1000:1000 /opt/tools/ /opt/tools/
COPY --from=gcloud-builder --chown=1000:1000 /opt/tools/ /opt/tools/
COPY --from=docker-builder --chown=1000:1000 /opt/tools/ /opt/tools/
COPY --from=make-builder --chown=1000:1000 /opt/tools/ /opt/tools/

# Labels
LABEL org.opencontainers.image.title="Homelab Tools"
LABEL org.opencontainers.image.description="Development tools: nmap, gh, gcloud, docker, make"
LABEL org.opencontainers.image.source="https://github.com/rgryta/Homelab-Tools"

USER 1000:1000

CMD ["/pause"]
