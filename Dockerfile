FROM alpine:3
LABEL maintainer="hello@mrkaran.dev"
WORKDIR /k8s-pruner
COPY prune-cm.sh .
RUN chmod u+x prune-cm.sh
CMD ["./prune-cm", "-d"]