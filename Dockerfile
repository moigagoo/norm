FROM nimlang/nim

WORKDIR /usr/src/app

COPY . /usr/src/app

RUN nimble install -y
RUN apt update && apt install -y postgresql-client
