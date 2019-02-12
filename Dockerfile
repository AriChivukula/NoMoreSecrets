FROM scratch
ADD vault vault
ADD vault.hcl vault.hcl
EXPOSE 80
ENTRYPOINT ["/vault", "server", "-config=vault.hcl"]
