# syntax = docker/dockerfile:1

ARG NODE_VERSION=20.7.0
FROM node:${NODE_VERSION}-slim AS base

ARG DATABASE_URL

WORKDIR /app

ENV NODE_ENV="production" \
    DATABASE_URL=$DATABASE_URL \
    DATABASE_DIRECT_URL=$DATABASE_URL \
    NODE_OPTIONS=--max-old-space-size=16192

# ────────────────────────────────
# 🔧 BUILD STAGE
# ────────────────────────────────
FROM base AS build

# Dependências do sistema para build
RUN apt-get update -qq && \
    apt-get install -y build-essential openssl pkg-config python-is-python3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

# Copiando arquivos essenciais
COPY package.json yarn.lock .yarnrc.yml turbo.json ./
COPY .yarn .yarn
COPY ./apps/api ./apps/api
COPY ./packages ./packages
COPY ./apps/web ./apps/web

# ✅ Instala dependências com consistência
RUN yarn install --immutable

# 🔍 Prune reduzido e confiável
RUN npx turbo prune --scope=@calcom/api --docker

# ✅ Compila apenas API
RUN yarn turbo run build --filter=@calcom/api

# ────────────────────────────────
# 🧼 FINAL STAGE - CLEAN IMAGE
# ────────────────────────────────
FROM base
WORKDIR /app

# Instala apenas openssl se for realmente necessário
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y openssl && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

# Copia somente os arquivos do `api` pruned
COPY --from=build /app/out/ . # ← turbo prune gera tudo em /out por padrão

# Expondo a porta da API
EXPOSE 80

# Início do app
CMD ["yarn", "workspace", "@calcom/api", "docker-start-api"]
