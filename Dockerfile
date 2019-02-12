FROM scratch
ADD vault vault
EXPOSE 80
ENTRYPOINT ["/vault"]
