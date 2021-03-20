FROM nimlang/nim:1.4.4

WORKDIR /usr/src/app

COPY . /usr/src/app

RUN apt-get update && apt-get install -y sqlite3 postgresql-client
RUN nimble install -y
