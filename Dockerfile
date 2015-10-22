FROM ubuntu:trusty
MAINTAINER fzerorubigd <fzero@rubi.gd> @fzerorubigd

RUN apt-get update && apt-get install -y --no-install-recommends \
		daemontools daemontools-run ucspi-tcp djbdns wget php5 make php5-mysql mysql-client \
	&& rm -rf /var/lib/apt/lists/*
RUN /usr/sbin/useradd -s /sbin/nologin -d /dev/null Gtinydns
RUN /usr/sbin/useradd -s /sbin/nologin -d /dev/null Gdnscache
RUN /usr/sbin/useradd -s /sbin/nologin -d /dev/null Gdnslog

RUN cd /var/www/ && rm -rf ./html && wget --quiet --no-check-certificate -O - https://github.com/shupp/VegaDNS/archive/0.13.0.tar.gz | tar zxvf - && mv VegaDNS-0.13.0 html

RUN  mkdir -p /var/www/html/vegadns_private/{templates_c,configs,cache,sessions} && chown -R www-data:www-data /var/www/html && chmod -R 770 /var/www/html && rm /var/www/html/src/config.php

ADD docker-initscript.sh /sbin/docker-initscript.sh

RUN chmod 755 /sbin/docker-initscript.sh
EXPOSE 80/tcp
EXPOSE 53/udp
ENTRYPOINT ["/sbin/docker-initscript.sh"]
CMD ["vegadns"]
