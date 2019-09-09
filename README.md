# OS161 in Docker

[![Build Status](https://travis-ci.com/johnramsden/os161-docker.svg?branch=master)](https://travis-ci.com/johnramsden/os161-docker)

## Pull from Docker Hub

Docker Hub images are built from the code in this repository. Alternatively [build an image from source](#Build).

```shell
docker pull johnramsden/os161
```

## Build

If you would prefer to build your own image instead of using a pre-built one, clone this repository and build from source.

```shell
docker build . -t os161
```

## Usage

Place code to mount into container on local filesystem, `~/os161` used in below example.

Run container, mounting a directory into the container:

```shell
docker run --interactive --tty \
    --volume="${HOME}/os161:/home/os161/os161" johnramsden/os161
```

Now after compiling a kernel, it can be started.

```shell
sys161 kernel
```

## Multiple Terminals

To open up multiple terminals use `tmux` inside the container.

or `docker exec` into an already running container.

```shell
docker exec --interactive --tty <id> /bin/bash
```

---

References:

* https://sites.google.com/site/os161ubc/os161-installation
* http://www.ece.ubc.ca/~os161/download/cs161-ubuntu.sh

Licenced MIT
