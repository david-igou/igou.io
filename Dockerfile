FROM quay.io/hummingbird/nginx:1.30.6@sha256:3e332f55e250629b2cb6fe9df45ada87b169b0a366b2f8af246764c62fa869b2
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY public/ /usr/share/nginx/html/
