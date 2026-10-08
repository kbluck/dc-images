# dc-images

Minimal base images for [Dev Containers](https://containers.dev/).

## Images

### `dc-busybox`

`ghcr.io/kbluck/dc-busybox` is a small dev container image built from Alpine Linux. It's meant as a base to build on, not a full
development environment. It ships BusyBox and the `apk` package manager, plus what an IDE needs to attach to the container.

- **Small and flat.** The filesystem is copied from `scratch` into a single layer. The image drops Alpine packages it doesn't
  need (`openssl`, `musl-utils`, `scanelf`, ...) and removes caches, logs, temp files and `/etc` backups.
- **IDE-ready.** Includes `gcompat` (a glibc compatibility layer for musl), so the prebuilt server binaries and extensions that
  IDEs install can run. Locale support comes from `musl-locales`, and the default locale is `en_US.UTF-8`.
- **Non-root by default.** Runs as `nonroot` (UID/GID `1000`). The `root` account is locked and `/etc/shadow` is removed.
  `busybox-suid` handles the few applets that need elevated privileges.
- **Consistent shell startup.** Every BusyBox `ash` shell reads one shared defaults script, then `/etc/profile` for login shells
  and `/etc/shrc` (through `ENV`) for interactive shells. Each of these also reads drop-in scripts from `/etc/profile.d/*.sh` or
  `/etc/shrc.d/*.sh`, and the user's own `~/.profile` or `~/.shrc`.
- **Dev container metadata.** The `devcontainer.metadata` image label sets these defaults, so a `devcontainer.json` can be very
  short:
  - `nonroot` as the container and remote user, with `updateRemoteUserUID` turned on
  - named volumes for `~/.cache` and `~/.local`, so caches and shell history (`~/.local/state/.shell_history`) persist across
    container rebuilds
  - `init`, `SYS_PTRACE` (for debuggers), and `no-new-privileges`
- **Workspace directory.** `/workspaces` is owned by `nonroot` and is the working directory.
- **Multi-platform.** Built for `linux/amd64` and `linux/arm64`.

Image tags match the tags of the Alpine base image the build used, for example `3`, `3.24`, `3.24.2` and `latest`.

#### Usage

A minimal `.devcontainer/devcontainer.json`:

```json
{
  "name": "My Project",
  "image": "ghcr.io/kbluck/dc-busybox:latest"
}
```

To add tools, build a derived image. Use `USER root` to install packages, then switch back to `nonroot`:

```dockerfile
FROM ghcr.io/kbluck/dc-busybox:latest
USER root
RUN apk --no-interactive add git
USER nonroot
```

## Building

### Requirements

- Docker with [Buildx](https://docs.docker.com/build/buildx/) (`docker buildx bake`)
- A builder that supports multi-platform output, such as the `docker-container` driver or Docker Desktop with the containerd
  image store
- For `docker-bake.sh`: a POSIX shell, `git`, `curl`, `jq`, and network access to Docker Hub

### Repository layout

| Path                        | Purpose                                                                      |
|-----------------------------|------------------------------------------------------------------------------|
| `src/dc-busybox/Dockerfile` | Three-stage build: generate `/etc` config, curate the Alpine rootfs, flatten |
| `docker-bake.hcl`           | Bake targets, platforms, OCI annotations and tags                            |
| `docker-bake.sh`            | Wrapper that resolves base image metadata and then calls `docker buildx bake` |

### Build with the wrapper script (recommended)

```sh
sh ./docker-bake.sh            # build all targets
sh ./docker-bake.sh --print    # show the resolved build configuration without building
sh ./docker-bake.sh --push     # build and push to ghcr.io
```

All arguments are passed through to `docker buildx bake`. Before the build, the script:

1. Inspects the current `alpine:latest` manifest to get its version annotation and digest.
2. Queries Docker Hub for every tag that points to that digest, such as `3`, `3.24`, `3.24.2` and `latest`.
3. Reads the Git `origin` URL and the `HEAD` commit for the OCI `source` and `revision` annotations.
4. Pins the build to the base image digest (`alpine@sha256:...`), so the image and its annotations always match the same base.

You can override any of these by setting the matching environment variable:

| Variable                        | Default                                       |
|---------------------------------|-----------------------------------------------|
| `BUSYBOX_BASE_IMAGE_NAME`       | `alpine`                                      |
| `BUSYBOX_BASE_IMAGE_TAG_LATEST` | `latest`                                      |
| `BUSYBOX_BASE_IMAGE_REPOSITORY` | `library/${BUSYBOX_BASE_IMAGE_NAME}`          |
| `BUSYBOX_BASE_IMAGE_URI`        | `docker.io/${REPOSITORY}:${TAG_LATEST}`       |
| `BUSYBOX_BASE_IMAGE_VERSION`    | the base manifest's `image.version` annotation |
| `BUSYBOX_BASE_IMAGE_TAG_LIST`   | Docker Hub tags that share the base digest    |

For example, to build from a specific Alpine release:

```sh
BUSYBOX_BASE_IMAGE_TAG_LATEST=3.23 sh ./docker-bake.sh
```

### Build with Bake directly

`docker buildx bake` also works on its own. The base image then defaults to `docker.io/library/alpine:latest` and the image is
tagged `ghcr.io/kbluck/dc-busybox:latest`, but the version, digest and source annotations are left as placeholders. Set the
`BUSYBOX_*` variables from `docker-bake.hcl` yourself to fill them in.

```sh
docker buildx bake --load --set '*.platform=linux/arm64'   # single-platform build loaded into the local image store
```

### Dockerfile build arguments

The Dockerfile accepts `--build-arg` overrides for the user (`DC_USER_NAME`, `DC_USER_UID`, `DC_USER_SHELL`, ...), the locale
(`DC_DEFAULT_LANGUAGE`, `DC_DEFAULT_CHARSET`), the workspace directory (`DC_WORKSPACES_DIR`), and the shell configuration file
paths. The full list with defaults is at the top of `src/dc-busybox/Dockerfile`.

Builds always run without cache, and Buildx provenance and SBOM attestations are turned off.

## License

[MIT](LICENSE.md) © 2026 Kevin Bluck
