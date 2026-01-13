FROM alpine:3.20

RUN apk add --no-cache curl jq bash ca-certificates

COPY cf-ddns.sh /usr/local/bin/cf-ddns.sh
RUN chmod +x /usr/local/bin/cf-ddns.sh

ENTRYPOINT ["/usr/local/bin/cf-ddns.sh"]
