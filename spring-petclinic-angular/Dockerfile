ARG DOCKER_HUB="docker.io"
ARG NGINX_VERSION="1.29-alpine"
ARG NODE_VERSION="24-alpine"

FROM $DOCKER_HUB/library/node:$NODE_VERSION AS build
WORKDIR /workspace
COPY package.json package-lock.json ./
ARG NPM_REGISTRY="https://registry.npmjs.org"
RUN npm ci --registry="$NPM_REGISTRY" --no-audit --no-fund
COPY . .
RUN npm run build -- --configuration production

FROM $DOCKER_HUB/library/nginx:$NGINX_VERSION AS runtime
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=build /workspace/dist/browser/ /usr/share/nginx/html/
RUN chown nginx:nginx /var/cache/nginx
USER nginx
EXPOSE 8080
HEALTHCHECK CMD wget -q --spider http://127.0.0.1:8080/ || exit 1
