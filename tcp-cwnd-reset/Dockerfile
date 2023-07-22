FROM alpine:3
RUN apk add --update --no-cache netcat-openbsd bash
EXPOSE 8089
CMD ["nc", "-l", "-k", "8089"]
