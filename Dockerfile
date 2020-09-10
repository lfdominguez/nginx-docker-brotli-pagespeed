FROM debian:buster-slim

RUN apt-get update && \
    apt-get install -y wget gnupg2 git \
    build-essential zlib1g-dev libpcre3 libpcre3-dev unzip uuid-dev
#   wget libgd2-xpm-dev libgeoip-dev libperl-dev libxslt1-dev lsb-release ca-certificates debhelper libssl-dev
RUN apt-key adv --no-tty  --keyserver hkp://pool.sks-keyservers.net:80 --recv-keys 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62
RUN echo "deb-src http://nginx.org/packages/mainline/debian/ buster nginx" >> /etc/apt/sources.list

WORKDIR /tmp

ENV NGINX_BASE_VERSION 1.19.2
ENV NGINX_VERSION "1.19.2-1~buster"

RUN apt-get update && \
    apt-get build-dep -y nginx && \
    apt-get source nginx=${NGINX_VERSION}

ENV NPS_VERSION=1.13.35.2

RUN wget -O- https://github.com/apache/incubator-pagespeed-ngx/archive/v${NPS_VERSION}-stable.tar.gz | tar -xz

RUN nps_dir=$(find . -name "*pagespeed-ngx-*" -type d) && \
    cd "$nps_dir" && \
    psol_url=https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz && \
    [ -e scripts/format_binary_url.sh ] && psol_url=$(scripts/format_binary_url.sh PSOL_BINARY_URL) && \
    wget -O- ${psol_url} | tar -xz && \
    cd ..

RUN git clone --depth=1 --recurse-submodules https://github.com/google/ngx_brotli.git


RUN sed -i 's/--with-stream_ssl_preread_module/--with-stream_ssl_preread_module --add-module=\/tmp\/ngx_brotli --add-module=\/tmp\/incubator-pagespeed-ngx-${NPS_VERSION}-stable/g' /tmp/nginx-${NGINX_BASE_VERSION}/debian/rules && \
    cd /tmp/nginx-${NGINX_BASE_VERSION} && dpkg-buildpackage -uc -b

FROM debian:buster-slim

ENV NGINX_VERSION "1.19.2-1~buster"

COPY --from=0 /tmp/nginx_${NGINX_VERSION}_amd64.deb /tmp/nginx.deb
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    apt install -y /tmp/nginx.deb && \
    rm -rf /var/lib/apt/lists/*

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

VOLUME ["/var/cache/nginx"]
VOLUME ["/var/cache/pagespeed"]

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
