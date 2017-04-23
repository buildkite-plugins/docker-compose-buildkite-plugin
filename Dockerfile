FROM lucor/bats

WORKDIR /app
ENTRYPOINT ["/usr/local/bin/bats"]
CMD ["tests/lib", "tests/commands"]
