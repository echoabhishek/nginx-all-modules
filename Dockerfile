FROM centos:7
MAINTAINER Abhishek Arora <hey@abhishek.id> 

ENV NGINX_VERSION 1.13.2
ENV PCRE_VERSION  8.40
ENV ZLIB_VERSION  1.2.11

# Update and install required packages
RUN     yum update -y \
        # Install "Development Tools" and Vim editor
        && yum groupinstall -y 'Development Tools' && yum install -y vim \
        # Install additional network tools
        && yum install -y wget man net-tools lsof telnet \
        # Install Extra Packages for Enterprise Linux (EPEL)
        && yum install -y epel-release \
        # Download and install optional NGINX dependencies
        && yum -y install gcc zlib-devel openssl-devel make pcre-devel libxml2-devel libxslt-devel \
        libgcrypt-devel gd-devel perl-ExtUtils-Embed GeoIP-devel

# Go to temporary directory to download installation files
WORKDIR /tmp

# Download the latest mainline version of NGINX source code and extract it
RUN     wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && tar zxvf nginx-${NGINX_VERSION}.tar.gz \
        # Download the NGINX dependencies' source code and extract them
        ## PCRE version ${PCRE_VERSION}
        && wget https://ftp.pcre.org/pub/pcre/pcre-${PCRE_VERSION}.tar.gz \
        && tar xzvf pcre-${PCRE_VERSION}.tar.gz \
        ## zlib version ${ZLIB_VERSION}
        && wget https://www.zlib.net/zlib-${ZLIB_VERSION}.tar.gz \
        && tar xzvf zlib-${ZLIB_VERSION}.tar.gz \
        ## OpenSSL version 1.1.0f
        && wget https://www.openssl.org/source/openssl-1.1.0f.tar.gz \
        && tar xzvf openssl-1.1.0f.tar.gz \
        # Copy NGINX manual page to /usr/share/man/man8
        && cp /tmp/nginx-${NGINX_VERSION}/man/nginx.8 /usr/share/man/man8 \
        && gzip /usr/share/man/man8/nginx.8

# Go to nginx source directory to configure nginx
WORKDIR /tmp/nginx-${NGINX_VERSION}

# Configure, compile, and install NGINX
RUN     ./configure --prefix=/etc/nginx \
                    --sbin-path=/usr/sbin/nginx \
                    --modules-path=/usr/lib64/nginx/modules \
                    --conf-path=/etc/nginx/nginx.conf \
                    --error-log-path=/var/log/nginx/error.log \
                    --pid-path=/var/run/nginx.pid \
                    --lock-path=/var/run/nginx.lock \
                    --user=nginx \
                    --group=nginx \
                    --build=CentOS \
                    --builddir=nginx-${NGINX_VERSION} \
                    --with-select_module \
                    --with-poll_module \
                    --with-threads \
                    --with-file-aio \
                    --with-http_ssl_module \
                    --with-http_v2_module \
                    --with-http_realip_module \
                    --with-http_addition_module \
                    --with-http_xslt_module=dynamic \
                    --with-http_image_filter_module=dynamic \
                    --with-http_geoip_module=dynamic \
                    --with-http_sub_module \
                    --with-http_dav_module \
                    --with-http_flv_module \
                    --with-http_mp4_module \
                    --with-http_gunzip_module \
                    --with-http_gzip_static_module \
                    --with-http_auth_request_module \
                    --with-http_random_index_module \
                    --with-http_secure_link_module \
                    --with-http_degradation_module \
                    --with-http_slice_module \
                    --with-http_stub_status_module \
                    --http-log-path=/var/log/nginx/access.log \
                    --http-client-body-temp-path=/var/cache/nginx/client_temp \
                    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
                    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
                    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
                    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
                    --with-mail=dynamic \
                    --with-mail_ssl_module \
                    --with-stream=dynamic \
                    --with-stream_ssl_module \
                    --with-stream_realip_module \
                    --with-stream_geoip_module=dynamic \
                    --with-stream_ssl_preread_module \
                    --with-compat \
                    --with-pcre=../pcre-${PCRE_VERSION} \
                    --with-pcre-jit \
                    --with-zlib=../zlib-${ZLIB_VERSION} \
                    --with-openssl=../openssl-1.1.0f \
                    --with-openssl-opt=no-nextprotoneg \
                    --with-debug \
        && make \
        && make install \
        # Symlink /usr/lib64/nginx/modules to /etc/nginx/modules directory, so that we can load
        # dynamic modules in nginx configuration like this load_module modules/ngx_foo_module.so;
        && ln -s /usr/lib64/nginx/modules /etc/nginx/modules \
        # Create NGINX cache folder
        && mkdir -p /var/cache/nginx \
        # Create the NGINX system user and group
        && useradd --system --home /var/cache/nginx --shell /sbin/nologin --comment "nginx user" --user-group nginx \
        # Remove archaic files from the /etc/nginx directory
        && rm /etc/nginx/koi-utf /etc/nginx/koi-win /etc/nginx/win-utf \
        # Place syntax highlighting of NGINX configuration for vim into ~/.vim/.
        # We will get nice syntax highlighting when editing NGINX configuration file
        && mkdir ~/.vim/ \
        && cp -r /tmp/nginx-${NGINX_VERSION}/contrib/vim/* ~/.vim/ \
        # Remove all .default backup files from /etc/nginx/
        && rm /etc/nginx/*.default \
        # forward request and error logs to docker log collector
        && ln -sf /dev/stdout /var/log/nginx/access.log \
        && ln -sf /dev/stderr /var/log/nginx/error.log \
        # create a docker-entrypoint.d directory
        && mkdir /docker-entrypoint.d

# Switch working directory to home folder
WORKDIR /root

# Expose range of ports to be opened
EXPOSE 80 443

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]
