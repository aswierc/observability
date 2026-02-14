FROM composer:2 AS vendor

WORKDIR /app

COPY composer.json composer.lock symfony.lock ./
COPY . .

RUN mkdir -p var/cache var/log && chmod -R a+rwX var
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-scripts --ignore-platform-req=ext-sockets

FROM php:8.4-cli

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends libcurl4-openssl-dev \
  && docker-php-ext-install curl \
  && docker-php-ext-install sockets \
  && rm -rf /var/lib/apt/lists/*

COPY --from=vendor /app /app

EXPOSE 8000

CMD ["php", "-S", "0.0.0.0:8000", "-t", "public", "public/index.php"]
