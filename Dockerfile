FROM nimlang/nim:0.20.0

WORKDIR /usr/src/app

COPY . /usr/src/app

RUN apt-get update && apt-get install -y postgresql-client
RUN nimble install -y
