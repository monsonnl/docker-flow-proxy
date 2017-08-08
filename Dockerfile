# default args for x86_64
ARG ARCH_SRC_DIR=x86_64
ARG ARCH_GO_IMG=golang:1.9-stretch
ARG ARCH_HAP_IMG=haproxy:1.7-alpine

# suggested args for arm32:
# ARCH_SRC_DIR=arm32
# ARCH_GO_IMG=arm32v7/golang:1.9-stretch
# ARCH_HAP_IMG=arm32v7/haproxy:1.7 (if arm32v7 adds 1.7-alpine we can use it for consistency)
# example: docker build --build-arg ARCH_SRC_DIR=arm32 --build-arg ARCH_GO_IMG=arm32v7/golang:1.9-stretch --build-arg ARCH_HAP_IMG=arm32v7/haproxy:1.7 -t docker-flow-proxy:arm32v7 .

# suggested args for arm64:
# ARCH_SRC_DIR=arm64
# ARCH_GO_IMG=arm64v8/golang:1.9-stretch
# ARCH_HAP_IMG=arm64v8/haproxy:1.7-alpine
# example: docker build --build-arg ARCH_SRC_DIR=arm64 --build-arg ARCH_GO_IMG=arm64v8/golang:1.9-stretch --build-arg ARCH_HAP_IMG=arm64v8/haproxy:1.7-alpine -t docker-flow-proxy:arm64v8 .

FROM monsonnl/qemu-wrap-build-files:latest as arch_src

ARG ARCH_GO_IMG

FROM ${ARCH_GO_IMG} AS build

ARG ARCH_SRC_DIR

COPY --from=arch_src /cross-build/${ARCH_SRC_DIR}/usr/bin /usr/bin

RUN [ "cross-build-start" ]

# build dfp
ADD . /src
WORKDIR /src
RUN go get -d -v -t
RUN go test --cover ./... --run UnitTest
RUN go build -v -o docker-flow-proxy

# stage the files and dirs for the build
RUN mkdir /stage_build
COPY errorfiles /stage_build/errorfiles
COPY haproxy.cfg /stage_build/cfg/haproxy.cfg
COPY haproxy.tmpl /stage_build/cfg/tmpl/haproxy.tmpl
WORKDIR /stage_build
RUN mkdir -p ./usr/local/bin && cp /src/docker-flow-proxy ./usr/local/bin/
RUN chmod +x ./usr/local/bin/docker-flow-proxy
RUN mkdir ./lib64 && ln -s /lib/libc.musl-x86_64.so.1 ./lib64/ld-linux-x86-64.so.2
RUN mkdir -p ./cfg/tmpl ./templates ./certs ./logs

RUN [ "cross-build-end" ]


ARG ARCH_HAP_IMG

FROM ${ARCH_HAP_IMG}
MAINTAINER 	Viktor Farcic <viktor@farcic.com>

COPY --from=build /stage_build/ /

ENV CERTS="" \
    CAPTURE_REQUEST_HEADER="" \
    CFG_TEMPLATE_PATH="/cfg/tmpl/haproxy.tmpl" \
    CHECK_RESOLVERS=false \
    CONNECTION_MODE="http-keep-alive" \
    DEBUG="false" \
    DEFAULT_PORTS="80,443:ssl" \
    DO_NOT_RESOLVE_ADDR="false" \
    EXTRA_FRONTEND="" \
    LISTENER_ADDRESS="" \
    MODE="default" \
    PROXY_INSTANCE_NAME="docker-flow" \
    RELOAD_INTERVAL="5000" REPEAT_RELOAD=false \
    SERVICE_NAME="proxy" SERVICE_DOMAIN_ALGO="hdr(host)" \
    STATS_USER="" STATS_USER_ENV="STATS_USER" STATS_PASS="" STATS_PASS_ENV="STATS_PASS" STATS_URI="" STATS_URI_ENV="STATS_URI" \
    TIMEOUT_HTTP_REQUEST="5" TIMEOUT_HTTP_KEEP_ALIVE="15" TIMEOUT_CLIENT="20" TIMEOUT_CONNECT="5" TIMEOUT_QUEUE="30" TIMEOUT_SERVER="20" TIMEOUT_TUNNEL="3600" \
    USERS="" \
    SKIP_ADDRESS_VALIDATION="true" \
    SSL_BIND_OPTIONS="no-sslv3" SSL_BIND_CIPHERS="ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS"

EXPOSE 80
EXPOSE 443
EXPOSE 8080

CMD ["docker-flow-proxy", "server"]
