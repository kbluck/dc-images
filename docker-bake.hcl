variable "BUSYBOX_BASE_IMAGE_NAME" {
  default = "docker.io/library/alpine"
}
variable "BUSYBOX_BASE_IMAGE_VERSION" {
  default = "latest"
}
variable "BUSYBOX_BASE_IMAGE_TAG_LIST" {
  default = "${BUSYBOX_BASE_IMAGE_VERSION}"
}
variable "BUSYBOX_BASE_IMAGE_SHA256" {
  default = "sha256"
}
variable "BUSYBOX_BASE_IMAGE" {
  # If the SHA256 string matches the SHA256 pattern, use it for the base image identifier: "name@digest".
  # Otherwise, fall back to "name:tag".
  default = ( length( regexall( "^sha256:[0-9a-f]{64}$", BUSYBOX_BASE_IMAGE_SHA256 ) ) > 0
    ? "${BUSYBOX_BASE_IMAGE_NAME}@${BUSYBOX_BASE_IMAGE_SHA256}"
    : "${BUSYBOX_BASE_IMAGE_NAME}:${BUSYBOX_BASE_IMAGE_VERSION}"
  )
}

variable "BUSYBOX_BUILD_IMAGE_NAME" {
  default = "ghcr.io/kbluck/dc-busybox"
}
variable "BUSYBOX_BUILD_IMAGE_URL" {
  default = "https://${BUSYBOX_BUILD_IMAGE_NAME}"
}
variable "BUSYBOX_BUILD_IMAGE_VERSION" {
  default = "${BUSYBOX_BASE_IMAGE_VERSION}"
}
variable "BUSYBOX_BUILD_IMAGE_SOURCE" {
  default = "https://github.com"
}
variable "BUSYBOX_BUILD_IMAGE_REVISION" {
  default = "HEAD"
}

group "default" {
  targets = [ "dc-busybox" ]
}

target "dc-busybox" {
  context = "."
  dockerfile = "src/dc-busybox/Dockerfile"
  platforms = [ "linux/amd64", "linux/arm64" ]
  args = {
    DC_BUSYBOX_BASE_IMAGE = "${BUSYBOX_BASE_IMAGE}"
  }
  annotations = [
    "index:org.opencontainers.image.title=BusyBox Dev Container",
    "index,manifest:org.opencontainers.image.description=BusyBox Dev Container.",
    "index:org.opencontainers.image.source=${BUSYBOX_BUILD_IMAGE_SOURCE}",
    "index:org.opencontainers.image.url=${BUSYBOX_BUILD_IMAGE_URL}",
    "index:org.opencontainers.image.vendor=Kevin Bluck",
    "index:org.opencontainers.image.authors=Kevin Bluck (kbluck@users.noreply.github.com)",
    "index:org.opencontainers.image.licenses=MIT",
    "index:org.opencontainers.image.version=${BUSYBOX_BUILD_IMAGE_VERSION}",
    "index:org.opencontainers.image.revision=${BUSYBOX_BUILD_IMAGE_REVISION}",
    "index:org.opencontainers.image.base.name=${BUSYBOX_BASE_IMAGE_NAME}:${BUSYBOX_BASE_IMAGE_VERSION}",
    "index:org.opencontainers.image.base.digest=${BUSYBOX_BASE_IMAGE_SHA256}",
    "index:org.opencontainers.image.created=${timestamp()}",
  ]
  tags = [ for TAG in split(",", BUSYBOX_BASE_IMAGE_TAG_LIST) : "${BUSYBOX_BUILD_IMAGE_NAME}:${TAG}" ]

  # Disable automatic buildx attestations
  attest = [ "type=provenance,disabled=true", "type=sbom,disabled=true" ]
  provenance = false
  sbom = false

  # Don't use build cache
  no-cache = true
}
