FROM lucor/bats

ENV LIBS_BATS_MOCK_VERSION "1.0.1"
RUN mkdir -p /usr/local/lib/bats/bats-mock \
    && curl -sSL https://github.com/jasonkarns/bats-mock/archive/v$LIBS_BATS_MOCK_VERSION.tar.gz -o /tmp/bats-mock.tgz \
    && tar -zxf /tmp/bats-mock.tgz -C /usr/local/lib/bats/bats-mock --strip 1 \
    && printf 'source "%s"\n' "/usr/local/lib/bats/bats-mock/stub.bash" >> /usr/local/lib/bats/load.bash \
    && rm -rf /tmp/bats-mock.tgz

WORKDIR /app
ENTRYPOINT ["/usr/local/bin/bats"]
CMD ["tests/"]
