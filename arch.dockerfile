# ╔═════════════════════════════════════════════════════╗
# ║                       SETUP                         ║
# ╚═════════════════════════════════════════════════════╝
# GLOBAL
  ARG APP_UID=1000 \
      APP_GID=1000

# :: FOREIGN IMAGES
  FROM 11notes/distroless AS distroless
  FROM 11notes/distroless:ds AS distroless-ds


# ╔═════════════════════════════════════════════════════╗
# ║                       BUILD                         ║
# ╚═════════════════════════════════════════════════════╝
# :: PHP
  FROM alpine AS build
  USER root
  ARG APP_VERSION \
      CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
  ENV CFLAGS="${CFLAGS}" \
      CPPFLAGS="${CFLAGS}" \
      LDFLAGS="-Wl,-O1 -pie"
  COPY --from=distroless-ds / /

  RUN set -eux; \
    apk --update --no-cache add \
      build-base \
      autoconf \
      bison \
      re2c \
      pkgconf \
      linux-headers \
      curl \
      xz \
      ca-certificates \
      argon2-dev \
      curl-dev \
      freetype-dev \
      icu-dev \
      libjpeg-turbo-dev \
      libpng-dev \
      libsodium-dev \
      libxml2-dev \
      libzip-dev \
      oniguruma-dev \
      openssl-dev \
      sqlite-dev \
      zlib-dev \
      postgresql18-dev \
      imap-dev \
      krb5-dev;

  RUN set -eux; \
    curl -fsSLo php.tar.xz "https://www.php.net/distributions/php-${APP_VERSION}.tar.xz"; \
    tar -xf php.tar.xz --strip-components=1; \
    rm php.tar.xz;

  RUN set -eux; \
    ./configure \
      --prefix=/usr/local \
      --sysconfdir=/php/etc \
      --with-config-file-path=/php/etc \
      --with-config-file-scan-dir=/php/etc/conf.d \
      --enable-fpm \
      --with-fpm-user=docker \
      --with-fpm-group=docker \
      --disable-cgi \
      --disable-phpdbg \
      --enable-mbstring \
      --enable-intl \
      --enable-opcache \
      --enable-pcntl \
      --enable-sockets \
      --enable-gd \
      --enable-soap \
      --enable-sysvsem \
      --enable-sysvshm \
      --with-jpeg \
      --with-freetype \
      --with-curl \
      --with-openssl \
      --with-zlib \
      --with-zip \
      --with-sodium \
      --with-password-argon2 \
      --with-pdo-mysql=mysqlnd \
      --with-mysqli=mysqlnd \
      --with-pdo-pgsql \
      --with-imap \
      --with-kerberos \
      --with-imap-ssl; \
    make -j $(nproc) 2>&1 > /dev/null; \
    make install 2>&1 > /dev/null;

  RUN set -eux; \
    mkdir -p \
      /distroless/lib \
      /distroless/php/etc \
      /distroless/usr/local/bin; \
    cp /usr/local/bin/php /distroless/usr/local/bin/; \
    cp /usr/local/sbin/php-fpm /distroless/usr/local/bin/; \
    EXT_DIR="$(php-config --extension-dir)"; \
    mkdir -p "/distroless${EXT_DIR}"; \
    cp "${EXT_DIR}"/*.so "/distroless${EXT_DIR}/"; \
    { echo /usr/local/bin/php; echo /usr/local/sbin/php-fpm; ls "${EXT_DIR}"/*.so; } \
      | while read -r f; do ldd "$f" 2>/dev/null || true; done \
      | awk '/=>/ {print $3}' | sort -u > /tmp/libs; \
    while read -r LIB; do \
      mkdir -p "/distroless$(dirname "${LIB}")"; \
      cp -L "${LIB}" "/distroless${LIB}"; \
    done < /tmp/libs; \
    cp -L /lib/ld-musl-*.so.1 /distroless/lib/; \
    cp /php.ini-production /distroless/php/etc/php.ini;

  RUN set -eux; \
    ds /distroless/usr/local/bin/php; \
    ds /distroless/usr/local/bin/php-fpm; \
    ds --bye;

  RUN set -eux; \
    echo $(php --version) | grep -q "${APP_VERSION}"; 


# :: FILE SYSTEM
  FROM alpine AS file-system
  USER root
  ARG APP_ROOT

  RUN set -ex; \
    mkdir -p /distroless${APP_ROOT}/etc; \
    mkdir -p /distroless${APP_ROOT}/var; \
    mkdir -p /distroless${APP_ROOT}/run;


# ╔═════════════════════════════════════════════════════╗
# ║                       IMAGE                         ║
# ╚═════════════════════════════════════════════════════╝
# :: HEADER
  FROM scratch

  # :: default arguments
    ARG TARGETPLATFORM \
        TARGETOS \
        TARGETARCH \
        TARGETVARIANT \
        APP_IMAGE \
        APP_NAME \
        APP_VERSION \
        APP_ROOT \
        APP_UID \
        APP_GID \
        APP_NO_CACHE

  # :: default environment
    ENV APP_IMAGE=${APP_IMAGE} \
        APP_NAME=${APP_NAME} \
        APP_VERSION=${APP_VERSION} \
        APP_ROOT=${APP_ROOT}

  # :: multi-stage
    COPY --from=distroless / /
    COPY --from=build /distroless/ /

# :: PERSISTENT DATA
  VOLUME ["${APP_ROOT}/etc", "${APP_ROOT}/var"]

# :: EXECUTE
  USER ${APP_UID}:${APP_GID}
  ENTRYPOINT ["/usr/local/bin/php"]
  CMD ["--version"]