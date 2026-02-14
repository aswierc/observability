FROM composer:2 AS vendor

WORKDIR /app

COPY composer.json composer.lock ./
COPY . .
RUN mkdir -p \
    bootstrap/cache \
    storage/framework/views \
    storage/framework/cache/data \
    storage/framework/sessions \
    storage/logs \
  && chmod -R a+rwX bootstrap/cache storage
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --ignore-platform-req=ext-sockets
RUN composer dump-autoload --optimize

FROM php:8.4-cli

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends libpq-dev \
  && docker-php-ext-install pdo_pgsql \
  && docker-php-ext-install sockets \
  && rm -rf /var/lib/apt/lists/*

COPY --from=vendor /app /app

EXPOSE 8000

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
