# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
FROM node:22.21.1-bookworm-slim@sha256:25b3eb23a00590b7499f2a2ce939322727fcce1b15fdd69754fcd09536a3ae2c AS node
FROM python:3.14.0-slim-bookworm@sha256:d13fa0424035d290decef3d575cea23d1b7d5952cdf429df8f5542c71e961576
ARG TARGETARCH
RUN test "$TARGETARCH" = amd64
COPY config/debian.sources /etc/apt/sources.list.d/debian.sources
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git gosu unzip jq procps ripgrep openssh-client \
    xvfb x11-utils mesa-utils libgl1-mesa-dri libglx-mesa0 libglu1-mesa \
    libxrender1 libxext6 libsm6 libice6 libfontconfig1 fonts-dejavu-core \
    shellcheck && rm -rf /var/lib/apt/lists/*
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
COPY versions.env /opt/ai-cad/versions.env
COPY scripts/install-tools.sh /opt/ai-cad/scripts/install-tools.sh
RUN bash /opt/ai-cad/scripts/install-tools.sh
COPY agents/ /opt/agents/
RUN cd /opt/agents && npm ci --omit=dev && \
    ln -s /opt/agents/node_modules/.bin/opencode /usr/local/bin/opencode && \
    ln -s /opt/agents/node_modules/.bin/codex /usr/local/bin/codex && \
    ln -s /opt/agents/node_modules/.bin/claude /usr/local/bin/claude
COPY requirements.lock /opt/ai-cad/requirements.lock
RUN uv venv --python /usr/local/bin/python /opt/cad && \
    uv pip sync --python /opt/cad/bin/python --require-hashes /opt/ai-cad/requirements.lock
ENV PATH="/opt/cad/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin" \
    HOME=/home/agent SHELL=/bin/bash XDG_RUNTIME_DIR=/run/ai-cad DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 \
    OVIS_RUNTIME=herdr-core OVIS_HC_BIN=/opt/ai-cad/scripts/hc-ovis.sh \
    HC_SOCKET=/run/ai-cad/hc.sock OVIS_PTY_SIDECAR_BIN=/opt/ovis/bin/ovis-pty-sidecar \
    HOST=0.0.0.0 PORT=7317 OVIS_STATE_DIR=/home/agent/.config/ovis \
    OVIS_AUTO_UPDATE=0 OVIS_TELEMETRY=0 CAD_UPDATE_CHECK=0 \
    DISABLE_AUTOUPDATER=1 DISABLE_UPDATES=1 \
    PC_CONFIG_FILES=/opt/ai-cad/config/process-compose.yaml \
    PC_SOCKET_PATH=/run/ai-cad/process-compose.sock PC_DISABLE_DOTENV=1 \
    PYTHONUNBUFFERED=1
COPY scripts/ /opt/ai-cad/scripts/
COPY config/ /opt/ai-cad/config/
COPY config/opencode.json /etc/opencode/opencode.json
COPY tests/ /opt/ai-cad/tests/
RUN python /opt/ai-cad/scripts/patch-cad-host.py && \
    chmod +x /opt/ai-cad/scripts/*.sh /opt/ai-cad/tests/*.sh && \
    groupadd -g 1500 agent && useradd -u 1500 -g agent -m -s /bin/bash agent && \
    mkdir -p /workspace /run/ai-cad && \
    process-compose version && hc --version && codex --version && claude --version && opencode --version
WORKDIR /workspace
EXPOSE 7317 3245
HEALTHCHECK --interval=30s --timeout=30s --start-period=120s --retries=3 CMD ["/opt/ai-cad/scripts/healthcheck.sh"]
ENTRYPOINT ["/opt/ai-cad/scripts/entrypoint.sh"]
