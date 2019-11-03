FROM alpine:3
LABEL maintainer="hello@mrkaran.dev"
WORKDIR /k8s-pruner
RUN apk add --no-cache bash
COPY prune-cm.sh .
RUN chmod u+x prune-cm.sh
CMD ["./prune-cm.sh", "-d"]