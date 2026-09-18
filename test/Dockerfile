FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates make openssh-client sudo util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash developer

WORKDIR /repo
