FROM alpine:latest

RUN apk add --no-cache restic rclone bash tzdata

ENV TZ=Asia/Shanghai

COPY entry.sh /root/entry.sh

ENTRYPOINT ["sh", "/root/entry.sh"]