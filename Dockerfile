ARG PHP_VERSION=8.5

FROM php:${PHP_VERSION}-fpm-bookworm

ARG UID=1000
ARG GID=1000

# Dipendenze di sistema ed estensioni PHP usate comunemente da Laravel
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        unzip \
        libpng-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libicu-dev \
        libzip-dev \
        libonig-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        gd \
        pdo_mysql \
        intl \
        bcmath \
        zip \
        exif \
        mbstring \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# La build si ferma se manca una delle estensioni richieste
RUN php -r 'foreach (["pdo", "pdo_mysql", "gd", "intl", "bcmath", "sodium", "zip", "exif", "mbstring"] as $extension) { if (!extension_loaded($extension)) { fwrite(STDERR, "Estensione PHP mancante: {$extension}\n"); exit(1); } }'

# Configurazione PHP
RUN printf '%s\n' \
        'memory_limit = 512M' \
        'upload_max_filesize = 64M' \
        'post_max_size = 64M' \
        > /usr/local/etc/php/conf.d/laravel.ini

# Node.js 24 e npm
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Composer dall'immagine ufficiale
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Utente con UID/GID coerenti con WSL
RUN groupadd --gid "${GID}" www \
    && useradd \
        --uid "${UID}" \
        --gid "${GID}" \
        --create-home \
        --shell /bin/bash \
        www

WORKDIR /var/www/html

USER www

EXPOSE 9000

CMD ["php-fpm"]
