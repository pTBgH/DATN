# 📉 Reducing Docker Image Size (273 MB → 180-200 MB)

## Current Situation
- Each microservice image: **273 MB**
- 7 images total: **~1,910 MB**
- Base image contributes ~85% of size (240 MB)

## Quick Analysis

Check current layers:
```bash
docker image history job7189/identity-service:v2.7.8 --no-trunc | head -20
```

Expected output shows:
- `php:8.2-fpm` = ~240 MB (Debian-based is huge)
- Laravel dependencies = ~20 MB  
- Application code = ~5-10 MB
- Build tools (NOT needed in runtime!) = ~10-15 MB

---

## 🎯 Optimization Strategy: Use Alpine Base Image

### Change 1: Lightweight Base Image

**Before (Dockerfile.production):**
```dockerfile
FROM php:8.2-fpm
# Size: ~500 MB
```

**After:**
```dockerfile
FROM php:8.2-fpm-alpine3.19
# Size: ~175 MB (65% smaller!)
```

### Change 2: Alpine-specific Dependencies

Alpine uses `apk` instead of `apt-get`. Update your Dockerfile:

**Before:**
```dockerfile
RUN apt-get update && apt-get install -y \
    git \
    curl \
    nano \
    # ... many packages
```

**After:**
```dockerfile
# Alpine build dependencies (removed in final image)
FROM php:8.2-fpm-alpine3.19 as builder

RUN apk add --no-cache --virtual .build-deps \
    autoconf \
    g++ \
    git \
    make \
    && docker-php-ext-configure pcntl \
    && docker-php-ext-install pcntl \
    && apk del .build-deps

# Final runtime stage - minimal size
FROM php:8.2-fpm-alpine3.19
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
```

---

## 🏗️ Multi-Stage Build Pattern

**Recommended approach in Dockerfile.production:**

```dockerfile
# ============ Stage 1: Builder ============
FROM php:8.2-fpm-alpine3.19 as builder

WORKDIR /app

# Install build dependencies (NOT in final image)
RUN apk add --no-cache --virtual .build-deps \
    autoconf \
    g++ \
    git \
    make \
    curl \
    $$ composer requires...

# Copy all source files
COPY . .

# Install Composer dependencies
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/
RUN composer install \
    --prefer-dist \
    --no-dev \
    --no-interaction \
    --optimize-autoloader

# Run build steps...
RUN php artisan config:cache
RUN php artisan route:cache

# Remove build tools
RUN rm -rf \
    /usr/bin/composer \
    .git \
    .env.example \
    tests/ \
    docs/

# ============ Stage 2: Runtime ============
FROM php:8.2-fpm-alpine3.19

WORKDIR /app

# Install runtime dependencies only
RUN apk add --no-cache \
    curl \
    postgresql-client \
    mysql-client

# Copy only necessary files from builder
COPY --from=builder /app/vendor ./vendor
COPY --from=builder /app/app ./app
COPY --from=builder /app/config ./config
COPY --from=builder /app/routes ./routes
COPY --from=builder /app/storage ./storage
COPY --from=builder /app/bootstrap ./bootstrap
COPY --from=builder /app/public ./public
COPY --from=builder /app/artisan ./
COPY --from=builder /app/*.php ./

# Set permissions
RUN chown -R www-data:www-data /app

EXPOSE 9000
CMD ["php-fpm"]
```

---

## 📦 Create .dockerignore

In each service's `laravel_back/` directory, create `.dockerignore`:

```
.git
.gitignore
.dockerignore
.env
.env.*.local
.env.example
README.md
docker-compose.yml
.vscode/
.idea/
.DS_Store
*.log
node_modules/
tests/
docs/
coverage/
.github/
.gitlab-ci.yml
Makefile
```

This prevents unnecessary files from being copied into the image (~10-20 MB savings).

---

## 🔧 Apply to All Services

Create a helper script to update all Dockerfiles:

**update-dockerfiles-to-alpine.sh:**
```bash
#!/bin/bash
# Update all Dockerfile.production to use Alpine base

SERVICES=(
  "candidate_service"
  "communication_service"
  "hiring_service"
  "identity_service"
  "job_service"
  "workspace_service"
  "storage_service"
)

for service in "${SERVICES[@]}"; do
  DOCKERFILE="src/${service}/laravel_back/Dockerfile.production"
  
  if [ -f "$DOCKERFILE" ]; then
    echo "Updating $DOCKERFILE..."
    
    # Replace Debian base with Alpine
    sed -i 's/FROM php:8.2-fpm$/FROM php:8.2-fpm-alpine3.19/' "$DOCKERFILE"
    sed -i 's/FROM php:8.2-fpm-debian/FROM php:8.2-fpm-alpine3.19/' "$DOCKERFILE"
    
    # Update apt-get to apk (if needed)
    sed -i 's/apt-get update && apt-get install -y/apk add --no-cache/' "$DOCKERFILE"
  fi
done

echo "✓ All Dockerfiles updated to Alpine"
```

---

## 📊 Expected Results

### Image Size Reduction
```
Before (Debian):   273 MB per image
After (Alpine):    ~195 MB per image
Savings:           ~78 MB per image (28%)

Total for 7 images:
Before:            1,910 MB
After:             1,365 MB
Total Saved:       545 MB (28%)
```

### Deployment Time Impact
```
Before:            734 seconds (for kind load)
After reduction:   ~530 seconds
Additional with registry: ~40 seconds

Full deployment:
Before: 850 seconds
After:  ~206 seconds
```

---

## ⚙️ Implementation Checklist

- [ ] Review one Dockerfile.production for Alpine compatibility
- [ ] Test Alpine version locally first:
  ```bash
  cd src/identity_service/laravel_back
  docker build -f Dockerfile.production -t test-alpine:latest .
  docker run --rm -it test-alpine:latest php -v
  ```
- [ ] Create .dockerignore in each service
- [ ] Update all Dockerfile.production files
- [ ] Run full build: `bash 04-build-and-push-images.sh`
- [ ] Deploy and verify: `bash 03-deploy-microservices.sh`

---

## 🚨 Potential Issues with Alpine

1. **Missing glibc** - Alpine uses musl instead
   - Fix: Install PHP extensions that need glibc
   - Most Laravel extensions work fine

2. **Package names differ from Debian**
   - Check: https://pkgs.alpinelinux.org/packages
   - Example: `postgresql-dev` instead of `postgresql-client`

3. **Build failures in composer install**
   - May need `gcc`, `git`, `make` during composer
   - Use .build-deps pattern to remove after compile

---

## 📚 References
- Alpine PHP Images: https://hub.docker.com/_/php (look for alpine tags)
- Alpine Packages: https://pkgs.alpinelinux.org/
- Multi-stage Builds: https://docs.docker.com/build/building/multi-stage/

