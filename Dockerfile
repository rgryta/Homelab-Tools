# Versions managed in .versions file - these are fallback defaults for local builds
ARG NMAP_VERSION=7.94SVN

FROM debian:bookworm-slim

ARG NMAP_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
    make curl unzip wget ca-certificates gnupg jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/tools/bin

# Install nmap (static binary from ernw/static-toolbox)
RUN NMAP_URL=$(curl -sL https://api.github.com/repos/ernw/static-toolbox/releases \
      | jq -r "[.[] | select(.tag_name == \"nmap-v${NMAP_VERSION}\")][0].assets[] | select(.name | endswith(\"x86_64-portable.tar.gz\")) | .browser_download_url") \
    && mkdir -p /opt/tools/nmap \
    && curl -sL "$NMAP_URL" | tar -xz -C /opt/tools/nmap \
    && printf '#!/bin/sh\nNMAPDIR=/opt/tools/nmap/data exec /opt/tools/nmap/nmap "$@"\n' > /opt/tools/bin/nmap \
    && chmod +x /opt/tools/bin/nmap

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && cp /usr/bin/gh /opt/tools/bin/

# Install Google Chrome (copy entire installation to /opt/tools for volume sharing)
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
      | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
      > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update && apt-get install -y google-chrome-stable \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && cp -a /opt/google/chrome /opt/tools/chrome \
    && printf '#!/bin/bash\nexport CHROME_WRAPPER="/opt/tools/bin/google-chrome"\nexec /opt/tools/chrome/chrome "$@"\n' > /opt/tools/bin/google-chrome \
    && chmod +x /opt/tools/bin/google-chrome

# Install gcloud CLI
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      > /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update && apt-get install -y google-cloud-cli \
      google-cloud-cli-app-engine-python google-cloud-cli-app-engine-python-extras \
      google-cloud-cli-cloud-run-proxy google-cloud-cli-gke-gcloud-auth-plugin \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && cp -a /usr/lib/google-cloud-sdk /opt/tools/ \
    && ln -sf /opt/tools/google-cloud-sdk/bin/gcloud /opt/tools/bin/gcloud \
    && ln -sf /opt/tools/google-cloud-sdk/bin/gsutil /opt/tools/bin/gsutil \
    && ln -sf /opt/tools/google-cloud-sdk/bin/bq /opt/tools/bin/bq

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/debian/gpg \
      | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bookworm stable" \
      > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y docker-ce-cli \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && cp /usr/bin/docker /opt/tools/bin/

# Copy make
RUN cp /usr/bin/make /opt/tools/bin/

# Create gcloud config directory
RUN mkdir -p /opt/tools/gcloud-config

# Set ownership for non-root usage
RUN chown -R 1000:1000 /opt/tools

# Labels for version tracking
LABEL org.opencontainers.image.title="Homelab Tools"
LABEL org.opencontainers.image.description="Development tools: nmap, gh, gcloud, docker, chrome"
LABEL org.opencontainers.image.source="https://github.com/rgryta/Homelab-Tools"
LABEL nmap.version="${NMAP_VERSION}"

CMD ["tail", "-f", "/dev/null"]
