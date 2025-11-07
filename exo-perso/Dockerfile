FROM ubuntu 
RUN apt update && apt upgrade -y
RUN apt-get install -y apache2
ENTRYPOINT usr/sbin/apache2ctl -D FOREGROUND
RUN mv /var/www/html/index.html /var/www/html/index.html.old
COPY index.html /var/www/html/index.html