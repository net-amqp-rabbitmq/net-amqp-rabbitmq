# Save the following in a file and
ARG IMG=sid

FROM debian:${IMG}

RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get dist-upgrade -y
RUN apt-get install -y \
        libterm-readline-gnu-perl \
        build-essential \
        perl \
        cpanminus \
        openssl \
        libssl-dev \
        zlib1g zlib1g-dev \
        pkg-config
RUN cpanm Carton

# Diag only
RUN echo "" && which pkg-config


# RUN cpanm -n Net::AMQP::RabbitMQ || ( cat /root/.cpanm/work/*/build.log && exit 1 )

RUN mkdir /test
WORKDIR /test
COPY ./ /test/
RUN rm -rf /test/local
RUN ls -la
RUN carton install || ( cat /root/.cpanm/work/*/build.log && exit 1 )
RUN perl Makefile.PL DEBUG
RUN make
RUN make test
