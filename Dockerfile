# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bookworm-20240423-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.16.2-erlang-26.2.5-debian-bookworm-20240423-slim
#
ARG ELIXIR_VERSION=1.16.2
ARG OTP_VERSION=26.2.5
ARG DEBIAN_VERSION=bookworm-20240423-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y \
 && DEBIAN_FRONTEND=noninteractive \
    apt-get install --no-install-recommends --assume-yes \
      build-essential \
      curl \
      git \
 && apt-get clean \
 && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
COPY apps/filer/mix.exs apps/filer/
COPY apps/filer_index/mix.exs apps/filer_index/
COPY apps/filer_store/mix.exs apps/filer_store/
COPY apps/filer_web/mix.exs apps/filer_web/
RUN mix deps.get --only $MIX_ENV

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY apps apps

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel

# individual build stages to build individual releases
FROM builder AS builder_web
RUN mix release filer_web

FROM builder AS builder_index
RUN mix release filer_index

FROM builder AS builder_store
RUN mix release filer_store

FROM builder as builder_all
RUN mix release filer

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE} AS runner

RUN apt-get update -y \
 && DEBIAN_FRONTEND=noninteractive \
    apt-get install --no-install-recommends --assume-yes \
      ca-certificates \
      libncurses5 \
      libstdc++6 \
      locales \
      openssl \
      tini \
 && apt-get clean \
 && rm -f /var/lib/apt/lists/*_*

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

ENTRYPOINT ["tini", "--"]

FROM runner AS runner_web
COPY --from=builder_web "/app/_build/${MIX_ENV}/rel/filer_web" ./
USER filer
ENV PHX_SERVER true
CMD ["filer_web", "start"]

FROM runner AS runner_index
RUN apt-get update -y \
 && DEBIAN_FRONTEND=noninteractive \
    apt-get install --no-install-recommends --assume-yes \
      ghostscript \
 && apt-get clean \
 && rm -f /var/lib/apt/lists/*_*
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

FROM runner AS runner_all
RUN apt-get update -y \
 && DEBIAN_FRONTEND=noninteractive \
    apt-get install --no-install-recommends --assume-yes \
      ghostscript \
 && apt-get clean \
 && rm -f /var/lib/apt/lists/*_*
COPY --from=builder_all "/app/_build/${MIX_ENV}/rel/filer" ./
ENV FILER_STORE /store
ENV PHX_SERVER true
RUN mkdir "$FILER_STORE" && chown filer "${FILER_STORE}"
VOLUME ["/store"]
USER filer
CMD ["filer", "start"]