# [1단계: 빌드 스테이지]
FROM node:24-alpine AS builder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# 프로덕션 빌드 후 index.html이 생성된 실제 출력 디렉터리를 찾아 /app/out으로 복사
RUN npm run build -- --configuration production && \
    mkdir -p /app/out && \
    cp -a "$(dirname "$(find /app/dist -name index.html | head -n 1)")"/. /app/out/

# [2단계: 실행 스테이지]
FROM nginx:1.27-alpine

RUN rm -rf /usr/share/nginx/html/*
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/out /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]