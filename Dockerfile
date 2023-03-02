FROM nimlang/nim:1.6.10

WORKDIR /usr/src/app

COPY . /usr/src/app

ENV PATH="/root/.nimble/bin:$PATH"

RUN apt-get update && apt-get install -y sqlite3 postgresql-client
RUN nimble install -y nimble
RUN nimble install -y
RUN git config --global --add safe.directory /usr/src/app

