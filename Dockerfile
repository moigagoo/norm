FROM nimlang/nim

WORKDIR /usr/src/app

COPY . /usr/src/app

RUN nimble install -y
RUN apt install -y postgresql-client
