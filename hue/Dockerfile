FROM gethue/hue:latest

USER root

RUN /usr/share/hue/build/env/bin/pip install --no-cache-dir PyMySQL psycopg2-binary

COPY docker-entrypoint.sh /usr/local/bin/hue-entrypoint.sh
RUN chmod +x /usr/local/bin/hue-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/hue-entrypoint.sh"]