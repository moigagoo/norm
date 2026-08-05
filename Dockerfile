FROM nim:latest AS norm_base
COPY . .
RUN nimble setup -ly

FROM norm_base AS norm_sqlite
RUN apt-get update && apt-get install -y sqlite3

FROM norm_base AS norm_postgres
RUN apt-get update && apt-get install -y postgresql-client

FROM norm_base AS norm_book
RUN nimble setupBook
