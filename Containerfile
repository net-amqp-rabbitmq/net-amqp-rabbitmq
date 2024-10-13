# Save the following in a file and
ARG IMG=sid

FROM debian:${IMG}

ENV MQADMINCACERT =""
ENV MQADMINUSERNAME =""
ENV MQADMINPASSWORD=""
ENV MQADMINPORT =""
ENV MQSSL =""
ENV MQSSLCACERT =""
ENV MQSSLHOST =""
ENV MQSSLUSERNAME =""
ENV MQSSLPASSWORD=""
ENV MQSSLVHOST =""
ENV MQHOST =""
ENV MQUSERNAME=""
ENV MQPASSWORD =""
ENV MQVHOST =""

RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get dist-upgrade -y
RUN apt-get install -y libterm-readline-gnu-perl
RUN apt-get install -y --no-install-recommends build-essential
RUN apt-get install -y perl
RUN apt-get install -y cpanminus
RUN apt-get install -y openssl
RUN apt-get install -y libssl-dev
RUN apt-get install -y zlib1g zlib1g-dev iputils-ping
RUN cpanm Carton

# RUN cpanm -n Net::AMQP::RabbitMQ || ( cat /root/.cpanm/work/*/build.log && exit 1 )

RUN mkdir /test
WORKDIR /test
COPY ./ /test/
RUN rm -rf /test/local
RUN ls -la
RUN carton install --test || ( cat /root/.cpanm/work/*/build.log && exit 1 )
RUN perl Makefile.PL DEBUG
RUN make
CMD ["make", "test"]
