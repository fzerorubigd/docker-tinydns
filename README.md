# Docker tinydns with VegaDNS admin

First run a mysql/mariadb container like this :

```
docker run --name tinydns-mariadb -e MYSQL_ROOT_PASSWORD=password mariadb
```

then run tinydns container : 

```
docker run --name -p 53:53/udp -p 80:80 tinydns --link tinydns-mariadb:mysql -e DNS_SERVER_IP=your.server.ip.address fzerorubigd/tinydns
```

