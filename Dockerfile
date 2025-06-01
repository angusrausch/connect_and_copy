FROM alpine:3.22.0

# Cause dnsutil is weird
# ENV DEBIAN_FRONTEND=noninteractive
# ENV TZ=Australia/Brisbane
RUN apk update && \
    apk add --no-cache \
        bind-tools cifs-utils tzdata \
        wireguard-tools iproute2 openresolv iputils rsync bash iptables openssh



RUN wg genkey | tee private.key | wg pubkey > public.key

COPY ./entrypoint.sh /

ENTRYPOINT [ "/bin/bash", "-c", "/entrypoint.sh" ]