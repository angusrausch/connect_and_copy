FROM ubuntu:20.04

# Cause dnsutil is weird
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Australia/Brisbane
RUN apt-get update && \
    apt-get install -y dnsutils cifs-utils tzdata \
        wireguard iproute2 openresolv iputils-ping smbclient rsync


RUN wg genkey | tee private.key | wg pubkey > public.key

COPY ./entrypoint.sh /

ENTRYPOINT [ "/bin/bash", "-c", "/entrypoint.sh" ]