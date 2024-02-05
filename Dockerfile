FROM node:18.19.0 AS FRONT
WORKDIR /web
COPY ./web .
RUN yarn install --frozen-lockfile --network-timeout 1000000 && yarn run build

FROM golang:1.21 AS BACK
WORKDIR /work
COPY . .
RUN ./build.sh
RUN go test -v -run TestGetVersionInfo ./util/system_test.go ./util/system.go > version_info.txt

FROM alpine:3.18 as alpine
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && \
    apk update && \
    apk add -U --no-cache ca-certificates tzdata

FROM alpine:3.18
LABEL MAINTAINER="https://github.com/99nil"
ENV TZ="Asia/Shanghai"

WORKDIR /work

COPY --from=alpine /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=alpine /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=BACK /work/server /usr/local/bin/server
COPY --from=BACK /work/conf/app.conf /work/conf/app.conf
COPY --from=BACK /work/swagger /work/swagger
COPY --from=BACK /work/version_info.txt /work/version_info.txt
COPY --from=FRONT /web/build /work/web/build

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

CMD  ["server"]
