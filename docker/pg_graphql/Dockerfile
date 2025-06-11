# GraphQL service Dockerfile
FROM postgrest/postgrest:latest

# Install pg_graphql extension dependencies
USER root
RUN apt-get update && apt-get install -y \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Add health check
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s \
  CMD curl -f http://localhost:3000/health || exit 1

USER postgrest
EXPOSE 3000

CMD ["postgrest"]