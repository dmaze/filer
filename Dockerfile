# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bookworm-20240513-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.16.3-erlang-26.2.5-debian-bookworm-20240513-slim
#
ARG ELIXIR_VERSION=1.16.3
ARG OTP_VERSION=26.2.5
ARG DEBIAN_VERSION=bookworm-20240513-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
 && apt-get update -y \
 && DEBIAN_FRONTEND=noninteractive \
    apt-get install --no-install-recommends --assume-yes \
      build-essential \
      curl \
      git

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN --mount=type=cache,target=/root/.mix,sharing=locked \
    mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
COPY apps/filer/mix.exs apps/filer/
COPY apps/filer_index/mix.exs apps/filer_index/
COPY apps/filer_store/mix.exs apps/filer_store/
COPY apps/filer_web/mix.exs apps/filer_web/
RUN --mount=type=cache,target=/root/.mix,sharing=locked \
    --mount=type=cache,target=/root/.hex,sharing=locked \
    --mount=type=cache,target=/app/deps,sharing=locked \
    mix deps.get --only $MIX_ENV

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN --mount=type=cache,target=/root/.mix,sharing=locked \
    --mount=type=cache,target=/root/.hex,sharing=locked \
    --mount=type=cache,target=/root/.cache,sharing=locked \
    --mount=type=cache,target=/app/deps,sharing=locked \
    mix deps.compile

COPY apps apps

# compile assets
RUN --mount=type=cache,target=/root/.mix,sharing=locked \
    --mount=type=cache,target=/root/.hex,sharing=locked \
    --mount=type=cache,target=/root/.cache,sharing=locked \
    --mount=type=cache,target=/app/deps,sharing=locked \
    mix assets.deploy

# Compile the release
RUN --mount=type=cache,target=/root/.mix,sharing=locked \
    --mount=type=cache,target=/root/.hex,sharing=locked \
    --mount=type=cache,target=/root/.cache,sharing=locked \
    --mount=type=cache,target=/app/deps,sharing=locked \
    mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel

# individual build stages to build individual releases
FROM builder AS builder_web
RUN --mount=type=cache,target=/root/.mix,sharing=locked \
    --mount=type=cache,target=/root/.hex,sharing=locked \
    --mount=type=cache,target=/root/.cache,sharing=locked \
    --mount=type=cache,target=/app/deps,sharing=locked \
    mix release filer_web

FROM builder AS builder_index
RUN --mount=type=cache,target=/root/.mix,sharing=locked \
    --mount=type=cache,target=/root/.hex,sharing=locked \
    --mount=type=cache,target=/root/.cache,sharing=locked \
    --mount=type=cache,target=/app/deps,sharing=locked \
    mix release filer_index

FROM builder AS builder_store
RUN --mount=type=cache,target=/root/.mix,sharing=locked \
    --mount=type=cache,target=/root/.hex,sharing=locked \
    --mount=type=cache,target=/root/.cache,sharing=locked \
    --mount=type=cache,target=/app/deps,sharing=locked \
    mix release filer_store

FROM builder as builder_all
RUN --mount=type=cache,target=/root/.mix,sharing=locked \
    --mount=type=cache,target=/root/.hex,sharing=locked \
    --mount=type=cache,target=/root/.cache,sharing=locked \
    --mount=type=cache,target=/app/deps,sharing=locked \
    mix release filer

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE} AS runner

RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
 && apt-get update -y \
 && DEBIAN_FRONTEND=noninteractive \
    apt-get install --no-install-recommends --assume-yes \
      ca-certificates \
      libncurses5 \
      libstdc++6 \
      locales \
      openssl \
      tini

# create a non-root user (not "nobody")
RUN adduser --system --no-create-home filer

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
ENV PATH /app/bin:$PATH

# set runner ENV
ENV MIX_ENV="prod"
ENV METRICS_SERVER_PORT 9568

ENTRYPOINT ["tini", "--"]

FROM runner AS runner_gs
RUN --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update -y \
 && DEBIAN_FRONTEND=noninteractive \
    apt-get install --no-install-recommends --assume-yes \
      ghostscript

FROM runner AS runner_web
COPY --from=builder_web "/app/_build/${MIX_ENV}/rel/filer_web" ./
USER filer
ENV PHX_SERVER true
CMD ["filer_web", "start"]

FROM runner_gs AS runner_index
COPY --from=builder_index "/app/_build/${MIX_ENV}/rel/filer_index" ./
USER filer
CMD ["filer_index", "start"]

FROM runner AS runner_store
COPY --from=builder_store "/app/_build/${MIX_ENV}/rel/filer_store" ./
ENV FILER_STORE /store
RUN mkdir "$FILER_STORE" && chown filer "${FILER_STORE}"
VOLUME ["/store"]
USER filer
CMD ["filer_store", "start"]

FROM runner_gs AS runner_all
COPY --from=builder_all "/app/_build/${MIX_ENV}/rel/filer" ./
ENV FILER_STORE /store
ENV PHX_SERVER true
RUN mkdir "$FILER_STORE" && chown filer "${FILER_STORE}"
VOLUME ["/store"]
USER filer
CMD ["filer", "start"]