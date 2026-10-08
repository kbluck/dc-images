# These variables might be overridden by environment variables.
BUSYBOX_BASE_IMAGE_NAME=${BUSYBOX_BASE_IMAGE_NAME:-"alpine"}
BUSYBOX_BASE_IMAGE_TAG_LATEST=${BUSYBOX_BASE_IMAGE_TAG_LATEST:-"latest"}

# These default are kind of specific to Docker Official Images like 'alpine', so they might also need to be overridden.
BUSYBOX_BASE_IMAGE_REPOSITORY=${BUSYBOX_BASE_IMAGE_REPOSITORY:-"library/${BUSYBOX_BASE_IMAGE_NAME}"}
BUSYBOX_BASE_IMAGE_URI=${BUSYBOX_BASE_IMAGE_URI:-"docker.io/${BUSYBOX_BASE_IMAGE_REPOSITORY}:${BUSYBOX_BASE_IMAGE_TAG_LATEST}"}

# This variable assumes that the base image includes the annotation "org.opencontainers.image.version" in its first manifest
# that contains the correct version string. If not, it can also be overridden.
BUSYBOX_BASE_IMAGE_VERSION=${BUSYBOX_BASE_IMAGE_VERSION:-"$(                \
  docker buildx imagetools inspect ${BUSYBOX_BASE_IMAGE_URI} --raw          \
    | jq -r '.manifests[0].annotations["org.opencontainers.image.version"]' \
)"}

# Extracted from the base image manifest. For some reason, --raw doesn't include it, so we use --format.
BUSYBOX_BASE_IMAGE_SHA256=$(                                                                                    \
    docker buildx imagetools inspect ${BUSYBOX_BASE_IMAGE_URI} --format '{{json .Manifest.Digest}}' | tr -d '"' \
)

# This assumes that the base image is located on Docker Hub. If not, this variable can be overridden.
# It should be a comma-separated list of the desired tags for the built image.
BUSYBOX_BASE_IMAGE_TAG_LIST=${BUSYBOX_BASE_IMAGE_TAG_LIST:-"$(                                            \
    curl -s "https://hub.docker.com/v2/repositories/${BUSYBOX_BASE_IMAGE_REPOSITORY}/tags/?page_size=100" \
      | jq -r --arg DIGEST "${BUSYBOX_BASE_IMAGE_SHA256}"                                                 \
           '.results[] | select(.digest == $DIGEST or (.images[]? | .digest) == $DIGEST) | .name'         \
      | sort | tr '\n' ',' | sed 's/,$//'                                                                 \
)"}

# Extract and transform the Git repository parameters.
BUSYBOX_BUILD_IMAGE_SOURCE="$( git remote get-url origin | sed -E -e 's|git@([^:]+):|https://\1/|' -e 's|\.git$||' )"
BUSYBOX_BUILD_IMAGE_REVISION="$( git rev-parse HEAD )"

# OK, finally we can bake the image. Add the necessary environment variables to docker's context.
BUSYBOX_BASE_IMAGE_NAME="${BUSYBOX_BASE_IMAGE_NAME}"           \
BUSYBOX_BASE_IMAGE_VERSION="${BUSYBOX_BASE_IMAGE_VERSION}"     \
BUSYBOX_BASE_IMAGE_SHA256="${BUSYBOX_BASE_IMAGE_SHA256}"       \
BUSYBOX_BASE_IMAGE_TAG_LIST="${BUSYBOX_BASE_IMAGE_TAG_LIST}"   \
BUSYBOX_BUILD_IMAGE_SOURCE="${BUSYBOX_BUILD_IMAGE_SOURCE}"     \
BUSYBOX_BUILD_IMAGE_REVISION="${BUSYBOX_BUILD_IMAGE_REVISION}" \
docker buildx bake "$@"
