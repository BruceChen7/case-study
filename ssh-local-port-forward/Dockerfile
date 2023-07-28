FROM alpine:3

# Install the dependencies:
RUN apk add --no-cache openssh-server curl python3
RUN mkdir /root/.ssh && chmod 0700 /root/.ssh && ssh-keygen -A
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x  /entrypoint.sh
# Run it:
CMD ["/entrypoint.sh"]
