FROM node:16.13.0 AS FRONT
WORKDIR /web
COPY ./web .
RUN yarn config set registry https://registry.npmmirror.com
RUN yarn install --frozen-lockfile --network-timeout 1000000 && yarn run build

FROM golang:1.17.5 AS BACK
WORKDIR /work
COPY . .
RUN ./build.sh

FROM alpine:3.6 as alpine
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && \
    apk update && \
    apk add -U --no-cache ca-certificates tzdata

FROM alpine:3.6
LABEL MAINTAINER="https://github.com/99nil"
ENV TZ="Asia/Shanghai"

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo $TZ > /etc/timezone

WORKDIR /work

COPY --from=alpine /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=alpine /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=BACK /work/server /usr/local/bin/server
COPY --from=BACK /work/conf/app.conf ./conf/app.conf
COPY --from=BACK /work/swagger ./swagger
COPY --from=FRONT /web/build ./web/build

CMD  ["server"]
