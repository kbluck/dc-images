###################################################################################################################################
### Global Arguments. Note that you can override these on the `docker build` command line using `--build-arg <ARG_NAME>=<VALUE>`
###################################################################################################################################

### Base image parameters.
ARG DC_BUSYBOX_BASE_IMAGE="docker.io/library/alpine:latest"

### Versions of key components
ARG DC_BUSYBOX_VERSION="1.37.0"

### Default locale.
ARG DC_DEFAULT_CHARSET="UTF-8"
ARG DC_DEFAULT_LANGUAGE="en_US"
ARG DC_DEFAULT_LOCALE="${DC_DEFAULT_LANGUAGE}.${DC_DEFAULT_CHARSET}"

### Remote user parameters. 
ARG DC_USER_NAME="nonroot"
ARG DC_USER_UID="1000"
ARG DC_USER_GROUP_NAME=${DC_USER_NAME}
ARG DC_USER_GROUP_GID=${DC_USER_UID}
ARG DC_USER_SHELL="/bin/ash"
ARG DC_USER_HOME_DIR="/home/${DC_USER_NAME}"

### Workspace parameters
ARG DC_WORKSPACES_DIR="/workspaces"

### Local volume mounts
ARG DC_USER_CACHE_DIR="${DC_USER_HOME_DIR}/.cache"
ARG DC_USER_LOCAL_DIR="${DC_USER_HOME_DIR}/.local"
ARG DC_USER_LOCAL_STATE_DIR="${DC_USER_LOCAL_DIR}/state"

### Shell configuration parameters.
ARG DC_SHELL_HISTORY_FILE_NAME=".shell_history"
ARG DC_SHELL_HISTORY_FILE_PATH="${DC_USER_LOCAL_STATE_DIR}/${DC_SHELL_HISTORY_FILE_NAME}"
ARG DC_SHELL_PROFILE_SYSTEM_FILE_NAME="profile"
ARG DC_SHELL_PROFILE_SYSTEM_FILE_PATH="/etc/${DC_SHELL_PROFILE_SYSTEM_FILE_NAME}"
ARG DC_SHELL_PROFILE_SYSTEM_DIR="/etc/${DC_SHELL_PROFILE_SYSTEM_FILE_NAME}.d"
ARG DC_SHELL_PROFILE_SYSTEM_GLOB="${DC_SHELL_PROFILE_SYSTEM_DIR}/*.sh"
ARG DC_SHELL_PROFILE_USER_FILE_NAME=".${DC_SHELL_PROFILE_SYSTEM_FILE_NAME}"
ARG DC_SHELL_PROFILE_USER_FILE_PATH="${DC_USER_HOME_DIR}/${DC_SHELL_PROFILE_USER_FILE_NAME}"
ARG DC_SHELL_RC_SYSTEM_FILE_NAME="shrc"
ARG DC_SHELL_RC_SYSTEM_FILE_PATH="/etc/${DC_SHELL_RC_SYSTEM_FILE_NAME}"
ARG DC_SHELL_RC_SYSTEM_DIR="/etc/${DC_SHELL_RC_SYSTEM_FILE_NAME}.d"
ARG DC_SHELL_RC_SYSTEM_GLOB="${DC_SHELL_RC_SYSTEM_DIR}/*.sh"
ARG DC_SHELL_RC_USER_FILE_NAME=".${DC_SHELL_RC_SYSTEM_FILE_NAME}"
ARG DC_SHELL_RC_USER_FILE_PATH="${DC_USER_HOME_DIR}/${DC_SHELL_RC_USER_FILE_NAME}"
ARG DC_SHELL_DEFAULTS_FILE_NAME="shell_defaults"
ARG DC_SHELL_DEFAULTS_FILE_PATH="${DC_SHELL_RC_SYSTEM_DIR}/${DC_SHELL_DEFAULTS_FILE_NAME}"

### SSL configuration parameters
ARG DC_SSL_CERT_FILE_PATH="/etc/ssl/certs/ca-certificates.crt"


###################################################################################################################################
### Build Stage 1: Generate custom configuration for /etc
###################################################################################################################################

### Start from an empty filesystem.
FROM scratch AS custom_config_etc

### Set a stripped /etc/passwd user configuration
ARG DC_USER_NAME DC_USER_UID DC_USER_GROUP_NAME DC_USER_GROUP_GID DC_USER_SHELL DC_USER_HOME_DIR
COPY --chmod=u=rwX,go=rX <<EOF "/etc/passwd"
root:!:0:0:root:/root:/sbin/nologin
${DC_USER_NAME}:x:${DC_USER_UID}:${DC_USER_GROUP_GID}:${DC_USER_NAME}:${DC_USER_HOME_DIR}:${DC_USER_SHELL}
EOF

### Set a stripped /etc/group configuration
COPY --chmod=u=rwX,go=rX <<EOF "/etc/group"
root:x:0:root
shadow:x:42:
${DC_USER_GROUP_NAME}:x:${DC_USER_GROUP_GID}:${DC_USER_NAME}
EOF

### Set an empty /etc/fstab configuration
COPY --chmod=u=rwX,go=rX <<EOF "/etc/fstab"
EOF

### The default shell in Busybox is `ash`, a port of `dash` (Debian Almquist Shell), a clone of the POSIX Bourne shell.
### Sourcing behavior of `ash` on shell startup:
###   Non-interactive:       Does not source any scripts.
###   Non-login interactive: Path in the variable `ENV`.
###   Login interactive:     `/etc/profile`, `/etc/profile.d/*.sh`, `~/.profile`, path in the variable `ENV`.
### 
### We will set up the ENV variable to enulate `.rc` behavior, similar to how `.bashrc` or `.zshrc` would work. Keep in mind
### that non-interactive shells, such as would be run by Docker, will not source any of these scripts. Any environment that needs
### to be set no matter what should be set here in the final Dockerfile `ENV` command or in the dev container `containerEnv`.

###  Consolidate common shell initialization into a single script.
ARG  DC_SHELL_DEFAULTS_FILE_PATH
COPY --chmod=u=rwX,go=rX <<EOF "${DC_SHELL_DEFAULTS_FILE_PATH}"
# Ensure path is exported as the reasonable default.
export PATH="\${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"

# If USER is not set, export the current username.
export USER="\${USER:-\${LOGNAME:-$(whoami)}}"
export LOGNAME="\${LOGNAME:-\${USER}}"

# If shell is not set, extract the current user default shell.
export SHELL="\${SHELL:-$(awk -F: -v uid=$(id -u) '\$3 == uid {print \$7}' /etc/passwd)}"

# Set default text pager to `less`
export PAGER="\${PAGER:-less}"

# Make sure locale environment is set.
if [ -z "\$MUSL_LOCPATH" -a -r "/etc/profile.d/00locale.sh" ]; then
    . /etc/profile.d/00locale.sh
fi

# New directories/files default mode is not writeable for group/all.
umask 022

# Use nicer prompt for Busybox ash or bash
_normal=$'\\e[0m'
if [ "\$USER" = root ]; then
	_color=$'\\e[1;31m'
	_symbol=' #'
else
	_color=$'\\e[1;32m'
	_symbol=' $'
fi
if [ -n "\$ZSH_VERSION" ]; then
	PS1="%{\$_color%}[%{\$_normal%}%~%{\$_color%}]\$_symbol %{\$_normal%}"
else
	PS1="\\[\$_color\\][\\[\$_normal\\]\\w\\[\$_color\\]]\$_symbol \\[\$_normal\\]"
fi
unset _normal _color _symbol
EOF

ARG DC_SHELL_PROFILE_SYSTEM_FILE_PATH DC_SHELL_PROFILE_SYSTEM_DIR DC_SHELL_PROFILE_SYSTEM_GLOB DC_SHELL_PROFILE_USER_FILE_PATH

###  Add /etc/profile script for login shells.
COPY --chmod=u=rwX,go=rX <<EOF "${DC_SHELL_PROFILE_SYSTEM_FILE_PATH}"
# If this script is executing, then this is a login shell.
LOGIN="1"

# Source shell defaults
. "${DC_SHELL_DEFAULTS_FILE_PATH}"

# Source any readable shell scripts in shell profile directory
for script in "${DC_SHELL_PROFILE_SYSTEM_GLOB}" ; do
    if [ -r "\$script" ] ; then
        . "\$script"
    fi
done
unset script

# Source any readable user shell profile script.
if [ -r "${DC_SHELL_PROFILE_USER_FILE_PATH}" ] ; then
    . "${DC_SHELL_PROFILE_USER_FILE_PATH}"
fi
EOF

###  Add /etc/sh.rc script for non-login shells. Will be assigned to $ENV.
ARG  DC_SHELL_RC_SYSTEM_FILE_PATH DC_SHELL_RC_SYSTEM_DIR DC_SHELL_RC_SYSTEM_GLOB DC_SHELL_RC_USER_FILE_PATH
COPY --chmod=u=rwX,go=rX <<EOF "${DC_SHELL_RC_SYSTEM_FILE_PATH}"
# Source shell defaults only if this is not a login shell
if [ -z "\$LOGIN" ]; then
    . "${DC_SHELL_DEFAULTS_FILE_PATH}"
fi

# Source any readable shell scripts in shell RC directory
for script in "${DC_SHELL_RC_SYSTEM_GLOB}" ; do
    if [ -r "\$script" ] ; then
        . "\$script"
    fi
done
unset script

# Source any readable user shell RC script.
if [ -r "${DC_SHELL_RC_USER_FILE_PATH}" ] ; then
    . "${DC_SHELL_RC_USER_FILE_PATH}"
fi
EOF


###################################################################################################################################
### Build Stage 2: Build curated OS image.
###################################################################################################################################

### Start from a fresh OS image.
FROM ${DC_BUSYBOX_BASE_IMAGE} AS build_dev_image

### Configure system packages. Preinstalled packages:
### Linux filesystem:          alpine-baselayout-data
### Standard C library:        musl musl-utils pax-utils scanelf
### Busybox System Utilities:  busybox libcrypto3 libssl3 openssl ssl_client
### APK Package Manager:       apk-tools ca-certificates-bundle libapk zlib
RUN <<-EOF

### Update APK package index.
    apk --no-interactive update

### Purge unwanted pre-installed packages.
    apk --no-interactive del ca-certificates openssl

### Upgrade remaining packages installed by the base image.
    apk --no-interactive upgrade

### Purge unused profile scripts included in `alpine-baselayout`.
    rm -f /etc/profile.d/20locale.* /etc/profile.d/color_prompt.*
EOF

### Add Busybox packages. Preinstalled packages:
###   `busybox`:               Implements a large number of common UNIX applets (e.g., cat, cp, ls, rm) via symlinks.
###   `busybox-binsh`:         Points /bin/sh to the `ash` POSIX shell applet.
###   `ssl_client`:            Minimal SSL helper binary used by wget to avoid a full-size TLS implementation.
### Add new packages:
###   `busybox-suid`:          `/bin/bbsuid` providing a locked-down SUID-root path for commands that require elevated permissions:
### Not installing:
###   `busybox-extras`:        Less common or legacy net/terminal applets: conspy, dumpleases, ftpget, ftpput, tcpsvd, telnet, tftp
###   `busybox-ifupdown`:      Config files and helpers for network interfaces via legacy network applets (e.g., ifup, ifdown).
###   `busybox-openrc`:        OpenRC init scripts and configs to run background service daemons (e.g., crond, syslogd, ntpd).
###   `busybox-extras-openrc`: OpenRC init configs for tools in `busybox-extras` (e.g. a telnet server listening on startup).
###   `busybox-mdev-openrc`:   Boot mappings for mdev (lightweight udev replacement).
RUN apk --no-interactive add busybox-suid

### Install GNU C Library compatibility layer for musl to serve compiled IDE extensions that require glibc.
RUN apk --no-interactive add gcompat libucontext musl-obstack

### Install basic support for locale. MUSL does not have this by default.
RUN apk --no-interactive add libintl musl-locales

### Copy custom configuration from the /etc stage.
COPY --from=custom_config_etc /etc /etc

### Create /private. Set cache, log, private and temp folders to be writable by anybody. Symlink temps to /var/tmp.
RUN <<-EOF
    mkdir -p /private /var/cache /var/log /var/tmp
    ln -sf /var/tmp /private/tmp
    rm -rf /tmp
    ln -sf /var/tmp /tmp
    chmod -R 777 /private /var/cache /var/log /var/tmp
EOF

### Create user home volume mount points. Set user home as owned by remote user.
ARG DC_USER_NAME DC_USER_GROUP_NAME DC_USER_HOME_DIR DC_USER_CACHE_DIR DC_USER_LOCAL_STATE_DIR DC_SHELL_HISTORY_FILE_PATH
RUN <<-EOF
    mkdir -p ${DC_USER_CACHE_DIR}       ${DC_USER_LOCAL_STATE_DIR}
    touch    ${DC_SHELL_HISTORY_FILE_PATH}
    chown -R ${DC_USER_NAME}:${DC_USER_GROUP_NAME} ${DC_USER_HOME_DIR}
EOF

### Add the dev container workspace path. Set as owned by remote user.
ARG DC_WORKSPACES_DIR
RUN <<-EOF
    mkdir -p /build/${DC_WORKSPACES_DIR}
    chown ${DC_USER_NAME}:${DC_USER_GROUP_NAME} /build/${DC_WORKSPACES_DIR}
EOF

### Purge unused or unwanted cruft.
RUN <<-EOF

### Remove /etc backup files ending with a hyphen.
    find /etc -type f -name '*-' -exec rm -f {} +

### Remove unused /etc files
    rm -f /etc/shadow*

### Remove unused /etc directories
    rm -rf /etc/opt
EOF

### Consolidate filesystem into a fresh copy under /build to eliminate filesystem cruft.
RUN mkdir -p /build && tar -cf - /bin /etc /home /lib /private /run /sbin /tmp /usr /var 2>/dev/null | tar -xf - -C /build

###################################################################################################################################
### Build Stage 3: Assemble final container image.
###################################################################################################################################

### Start from an empty filesystem.
FROM scratch

### Copy entire optimized filesystem as single layer. Exclude APT lists, caches, docs, hardware, logs, mail, and tempfiles.
COPY --from=build_dev_image --exclude=**/cache/* --exclude=**/log/* --exclude=**/tmp/* build/ /

### Set up container environment.
ARG DC_USER_NAME DC_USER_GROUP_NAME DC_USER_HOME_DIR DC_USER_CACHE_DIR DC_USER_LOCAL_DIR DC_WORKSPACES_DIR \
    DC_SSL_CERT_FILE_PATH DC_SHELL_RC_SYSTEM_FILE_PATH DC_SHELL_HISTORY_FILE_PATH  DC_BUSYBOX_VERSION DC_DEFAULT_LOCALE

ENV BUSYBOX_VERSION=${DC_BUSYBOX_VERSION} \
    ENV=${DC_SHELL_RC_SYSTEM_FILE_PATH} \
    SSL_CERT_FILE=${DC_SSL_CERT_FILE_PATH} \
    LANG=${DC_DEFAULT_LOCALE} \
    LC_ALL=${DC_DEFAULT_LOCALE}

USER    ${DC_USER_NAME}
WORKDIR ${DC_WORKSPACES_DIR}

### Set DevContainer metadata on the image.
LABEL devcontainer.metadata='[{ \
"containerUser": "'${DC_USER_NAME}'", \
"remoteUser":    "'${DC_USER_NAME}'", \
"remoteEnv": { \
  "HISTFILE": "'${DC_SHELL_HISTORY_FILE_PATH}'" \
}, \
"mounts": [{ \
  "type":   "volume", \
  "source": "${localWorkspaceFolderBasename}-user-cache", \
  "target": "'${DC_USER_CACHE_DIR}'" \
},{ \
  "type":   "volume", \
  "source": "${localWorkspaceFolderBasename}-user-local", \
  "target": "'${DC_USER_LOCAL_DIR}'" \
}], \
"capAdd": [ "SYS_PTRACE" ], \
"init": true, \
"privileged": false, \
"securityOpt": [ "no-new-privileges=true" ], \
"shutdownAction": "stopContainer", \
"updateRemoteUserUID": true, \
"userEnvProbe": "loginInteractiveShell" \
}]'

ENTRYPOINT [ "/bin/sh" ]
