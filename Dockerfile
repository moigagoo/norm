FROM nimlang/nim:2.2.0 AS norm_base

WORKDIR /usr/src/app

COPY . /usr/src/app

ENV PATH="/root/.nimble/bin:$PATH"

RUN nimble install -y
RUN git config --global --add safe.directory /usr/src/app


FROM norm_base AS norm_sqlite

RUN apt-get update && apt-get install -y sqlite3


FROM norm_base AS norm_postgres

RUN apt-get update && apt-get install -y postgresql-client

