# Filer Scanner

The scanner is a stanalone process that watches the local file system and sends files to the filer application over HTTP.

The scanner does _not_ run as part of the standard application, and in a distributed setup, it is _not_ part of the cluster.  This allows the filer application to run remotely from the files being indexed.  More specifically, it supports running the filer in a container environment: the application is reachable via an HTTP endpoint, and the scanner can push file content there, but this setup does not require outbound calls from the application to the scanner, and this avoids needing filesystem mounts into the container environment.

This can be run locally from this directory as

```sh
MIX_ENV=prod mix run --no-halt
```

The scanner can be configured with environment variables:

`FILER_URL` -- URL to the base of the filer application, defaults to `http://localhost:4000/`

`FILER_PATH` -- Local filesystem path containing data to index, defaults to `./data`

`FILER_CONTINUOUS` -- If set to `true` (or `yes` or `1`) then launch a continuous file-system watcher, otherwise exit after a single scan, defaults to `false`
