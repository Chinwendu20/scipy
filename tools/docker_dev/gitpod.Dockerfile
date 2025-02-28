# Dockerfile for SciPy - gitpod-based development
# Usage: 
# -------
# 
# To make a local build of the container, from the root directory:
# docker build --rm -f "./tools/docker_dev/gitpod.Dockerfile" -t <build-tag> "."    
# 
# Doing a local shallow clone - keeps the container secure
# and much slimmer than using COPY directly or cloning a remote
ARG BASE_CONTAINER=scipy/scipy-dev:latest
FROM ${BASE_CONTAINER} as clone

# note this only needs to be done for the scipy repo
# submodules can be dealt with in the runtime image
COPY --chown=gitpod . /tmp/scipy_repo
RUN git clone --depth 1 file:////tmp/scipy_repo /tmp/scipy

# Using the Scipy-dev Docker image as a base
# This way, we ensure we have all the needed compilers and dependencies
# while reducing the build time - making this a  build ARG so we can reuse for other images
ARG BASE_CONTAINER=scipy/scipy-dev:latest
FROM ${BASE_CONTAINER} as build

# Build argument - can pass Meson arguments during the build:
ARG BUILD_ARG="python dev.py --build-only -j2" \
    CONDA_ENV=scipy-dev

# -----------------------------------------------------------------------------
USER root

# -----------------------------------------------------------------------------
# ---- ENV variables ----
# ---- Directories needed ----
ENV WORKSPACE=/workspace/scipy/ \
    CONDA_ENV=scipy-dev

# -----------------------------------------------------------------------------
# Change default shell - this avoids issues with Conda later - note we do need
# Login bash here as we are building SciPy inside
# Fix DL4006
SHELL ["/bin/bash","--login", "-o", "pipefail", "-c"]

# -----------------------------------------------------------------------------
# ---- Build Scipy here ----
COPY --from=clone --chown=gitpod /tmp/scipy ${WORKSPACE}

WORKDIR ${WORKSPACE}

# Build scipy to populate the cache used by ccache
# Must re-activate conda to ensure the ccache flags are picked up
RUN git config --global --add safe.directory /workspace/scipy
RUN git submodule update --init --depth=1 -- scipy/_lib/boost && \
    git submodule update --init --depth=1 -- scipy/sparse/linalg/_propack/PROPACK && \ 
    git submodule update --init --depth=1 -- scipy/_lib/unuran && \ 
    git submodule update --init --depth=1 -- scipy/_lib/highs

RUN conda activate ${CONDA_ENV} && \
    ${BUILD_ARG} && \
    ccache -s && \ 
    # needed for rst preview in gitpod
    python3 -m pip install docutils esbonio

# Gitpod will load the repository into /workspace/scipy. We remove the
# directoy from the image to prevent conflicts
RUN sudo rm -rf /workspace/scipy

# Always return to non privileged user
USER gitpod
