FROM scratch
ADD vault vault
ADD config.hcl config.hcl
EXPOSE 80
ENTRYPOINT ["/vault", "server", "-config=config.hcl"]
