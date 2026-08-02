FROM nim:latest AS norm_base
COPY . .
RUN nimble setup -ly
RUN nimble setupBook

FROM norm_base AS norm_sqlite
RUN apt-get update && apt-get install -y sqlite3

FROM norm_base AS norm_postgres
RUN apt-get update && apt-get install -y postgresql-client
