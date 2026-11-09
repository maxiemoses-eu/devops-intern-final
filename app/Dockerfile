FROM nginx:1.30.6-alpine-slim

ARG BUILD_SHA=unknown
ARG ASSESSMENT_DATE=unknown

LABEL maintainer="Maxie Moses Adams"
LABEL build.sha="${BUILD_SHA}"

# Replace placeholders in index.html
RUN mkdir -p /usr/share/nginx/html

COPY index.html /tmp/index.html
COPY nginx.conf /etc/nginx/nginx.conf

RUN sed "s|__BUILD_SHA__|${BUILD_SHA}|g; s|__ASSESSMENT_DATE__|${ASSESSMENT_DATE}|g" \
    /tmp/index.html > /usr/share/nginx/html/index.html && \
    rm /tmp/index.html

# Adjust permissions for non-root nginx
RUN touch /tmp/nginx.pid && \
    chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/log/nginx /tmp/nginx.pid && \
    chmod -R 755 /usr/share/nginx/html

USER nginx

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
