FROM golang:1.17.5 AS BACK
WORKDIR /go/src/casdoor
COPY . .
RUN ./build.sh && apt update && apt install wait-for-it && chmod +x /usr/bin/wait-for-it

FROM node:16.13.0 AS FRONT
WORKDIR /web
COPY ./web .
RUN yarn config set registry https://registry.npmmirror.com
RUN yarn install && yarn run build


FROM debian:latest AS ALLINONE
RUN apt update
RUN apt install -y ca-certificates && update-ca-certificates
RUN apt install -y mariadb-server mariadb-client && mkdir -p web/build && chmod 777 /tmp
LABEL MAINTAINER="https://github.com/99nil"
COPY --from=BACK /go/src/casdoor/ ./
COPY --from=BACK /usr/bin/wait-for-it ./
COPY --from=FRONT /web/build /web/build
CMD chmod 777 /tmp && service mariadb start&&\
if [ "${MYSQL_ROOT_PASSWORD}" = "" ] ;then MYSQL_ROOT_PASSWORD=123456 ; fi&&\
mysqladmin -u root password ${MYSQL_ROOT_PASSWORD} &&\
./wait-for-it localhost:3306 -- ./server --createDatabase=true

FROM alpine:3.6 as alpine
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g' /etc/apk/repositories && \
    apk update && \
    apk add -U --no-cache ca-certificates tzdata

FROM alpine:3.6
LABEL MAINTAINER="https://github.com/99nil"
ENV TZ="Asia/Shanghai"

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo $TZ > /etc/timezone

COPY --from=alpine /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=alpine /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=BACK /go/src/casdoor/ ./
COPY --from=BACK /usr/bin/wait-for-it ./
COPY --from=FRONT /web/build /web/build

CMD  ["./server"]
