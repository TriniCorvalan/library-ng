FROM node:24-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:alpine
# Imagen ECR/EC2: solo SPA. Los proxies /books y /auth son para compose local (nginx.conf).
COPY nginx.prod.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/library-ng/browser /usr/share/nginx/html
EXPOSE 80
