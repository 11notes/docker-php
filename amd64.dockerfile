# :: Header
    FROM php:7.4.2-apache-buster

# :: Run
    USER root

    ADD ./source/index.php /var/www/html/index.php

    # :: docker -u 1000:1000 (no root initiative)
        RUN sed -i 's/:80/:8080/g' /etc/apache2/sites-available/000-default.conf \
            && sed -i 's/:443/:8443/g' /etc/apache2/sites-available/default-ssl.conf \
            && sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/ports.conf \
            && sed -i 's/Listen 443/Listen 8443/g' /etc/apache2/ports.conf
    
        RUN usermod -u 1000 www-data \
            && groupmod -g 1000 www-data \
            && chown 1000:1000 /var/www/html /var/www/html/index.php

    USER www-data