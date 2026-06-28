# Source: https://github.com/buildbot/buildbot/blob/e055ebda6b4800b4762e45088b23b736e046cecf/worker/Dockerfile
FROM        buildbot/buildbot-worker:v4.3.0 as buildbot
FROM        gentoo/stage3:20260616
LABEL       org.opencontainers.image.authors="alicef@gentoo.org"

USER root

# Install required packages and updates
RUN emerge-webrsync

COPY <<-EOT /etc/portage/binrepos.conf/gentoobinhost.conf
[gentoo]
priority = 9999
sync-uri = https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64/

# Introduced in portage-3.0.74 for per-repo verification choices
verify-signature = true
# Default value with >=portage-3.0.77
location = /var/cache/binhost/gentoo
EOT

COPY <<-EOT /etc/portage/make.conf
FEATURES="getbinpkg"
COMMON_FLAGS="-O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"
LC_MESSAGES=C.UTF-8
EOT

COPY <<-EOT /etc/portage/package.accept_keywords/dumb-init
>=sys-process/dumb-init-1.2.5-r1 ~amd64
EOT

RUN emerge --quiet --usepkg \
    llvm-core/llvm \
    llvm-core/clang \
    llvm-core/lld \
    sys-devel/gcc \
    dev-lang/python:3.14 \
    dev-python/ruamel-yaml \
    dev-python/pip \
    app-containers/docker-cli \
    app-alternatives/bc \
    sys-apps/kmod \
    dev-build/libtool \
    dev-build/automake \
    sys-devel/bison \
    sys-devel/flex \
    app-editors/vim \
    net-misc/wget \
    dev-build/autoconf \
    dev-vcs/git \
    sys-libs/binutils-libs \
    sys-devel/binutils \
    sys-process/dumb-init

#RUN update-alternatives --install /usr/bin/clang clang 100

# Install python required packages
RUN pip3 install --break-system-packages --upgrade pip
RUN pip3 install  --break-system-packages virtualenv
RUN pip3 install  --break-system-packages lavacli
RUN pip3 install  --break-system-packages beautifulsoup4
RUN pip3 install  --break-system-packages lxml
RUN pip3 install  --break-system-packages jsonschema
RUN pip3 install  --break-system-packages pyyaml
RUN pip3 install  --break-system-packages remote-pdb
RUN pip3 install  --break-system-packages python-dateutil
RUN pip3 install  --break-system-packages twisted[tls]
# Install newer jq fork version compatible with latest pip
#RUN cp /usr/include/python3.11/cpython/* /usr/include/python3.11/

# the following package has compilation errors with GCC 15, so we use a fork:
# https://github.com/kernelci/jq.py/pull/1
#RUN pip3 install  --break-system-packages jq@git+https://github.com/kernelci/jq.py.git@1.7.0.post1
RUN pip3 install  --break-system-packages jq@git+https://github.com/tollsimy/jq.py.git@1.9.1.post1

RUN pip3 install  --break-system-packages --use-deprecated=legacy-resolver git+https://github.com/kernelci/kcidb.git@v9

# Create fileserver folder for passing files to lava
RUN mkdir -p /var/www/fileserver
RUN useradd -ms /bin/bash buildbot
RUN chown -R buildbot /var/www/fileserver

ARG DOCKER_GID
RUN groupadd -g $DOCKER_GID docker
RUN usermod --append -G docker buildbot

USER root
COPY --from=buildbot /buildbot/buildbot.tac /buildbot/
COPY --from=buildbot /usr/src/buildbot-worker /usr/src/buildbot-worker
COPY --from=buildbot /buildbot_venv /buildbot_venv
RUN pip3 install --break-system-packages /usr/src/buildbot-worker
RUN mkdir -p /buildbot
RUN chown -R buildbot /buildbot
WORKDIR /buildbot

# Add kcidb configuration (if you are not sending to kernelci just comment out this)
COPY .kernelci-ci-gkernelci.json /home/buildbot/.kernelci-ci-gkernelci.json
ARG GOOGLE_APPLICATION_CREDENTIALS=~/.kernelci-ci-gkernelci.json

#COPY update-llvm.sh /
#RUN apt-get -y remove llvm lld && sh /update-llvm.sh

# Getting lava settings from docker-compose.yml
ARG LAVA_TOKEN
ARG LAVA_USER
ARG LAVA_SERVER

USER buildbot
RUN mkdir -p ~/.config/
RUN printf 'buildbot:\n  uri: http://$LAVA_USER:$LAVA_TOKEN@$LAVA_SERVER/RPC2' > ~/.config/lavacli.yaml
RUN lavacli identities add --uri http://$LAVA_USER:$LAVA_TOKEN@$LAVA_SERVER/RPC2 buildbot

COPY labs.yaml /home/buildbot

# See https://www.gentoo.org/downloads/signatures/
RUN gpg --keyserver hkps://keys.gentoo.org --receive-keys 13EBBDBEDE7A12775DFDB1BABB572E0E2D182910

CMD [ "/usr/bin/dumb-init", "/buildbot_venv/bin/twistd", "--pidfile=", "-ny", "buildbot.tac" ]
