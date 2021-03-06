FROM alpine:latest
LABEL maintainer "DI GREGORIO Nicolas <nicolas.digregorio@gmail.com>"

### Environment variables
ENV LANG='en_US.UTF-8' \
    LANGUAGE='en_US.UTF-8' \
    TERM='xterm' \
    PYCURL_SSL_LIBRARY='openssl'

### Install Application
RUN apk --no-cache upgrade && \
    apk add --no-cache --virtual=build-deps \
      make \
      gcc \
      g++ \
      python-dev \
      py2-pip \
      libressl-dev \
      curl-dev \
      musl-dev \
      libffi-dev \
      jpeg-dev \
      git \
      zlib-dev \
      py-pip  && \
    pip --no-cache-dir install --upgrade setuptools && \
    pip --no-cache-dir install --upgrade \
      spidermonkey \
      pyopenssl \
      tesseract \
      pycrypto \
      Pillow \
      feedparser \
      BeautifulSoup \
      thrift \
      beaker \
      jinja2 \
      pycurl && \
    git clone --depth 1 https://github.com/pyload/pyload.git -b stable /opt/pyload && \
    apk del --no-cache --purge \
      build-deps  && \
    apk add --no-cache --virtual=run-deps \
      python \
      ssmtp \
      mailx \
      libffi \
      libcurl \
      jpeg \
      unrar \
      zlib \
      su-exec && \
    rm -rf /tmp/* \
           /opt/pyload/.git \
           /var/cache/apk/*  \
           /var/tmp/*


### Volume
VOLUME ["/downloads","/config"]

### Expose ports
EXPOSE 8000 7227 9666

### Running User: not used, managed by docker-entrypoint.sh
#USER pyload

### Start pyload
COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["pyload"]

