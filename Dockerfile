FROM alpine:3.14

RUN apk add --no-cache curl

COPY LICENSE README.md /

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
