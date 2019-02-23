#!/bin/bash
#自动编译部署lnmp环境，搭建博客wordpress
#需要把三个包提前准备好
#nginx
cd /root/
#wget http://nginx.org/download/nginx-1.14.2.tar.gz
tar xf nginx-1.14.0.tar.gz
cd /root/nginx-1.14.0/
yum install gcc gcc-c++ pcre-devel openssl-devel -y
useradd -M -s /sbin/nologin nginx
./configure --prefix=/usr/local/nginx \
 --user=nginx \
--group=nginx \
--with-http_stub_status_module \
 --with-http_ssl_module  \
 --sbin-path=/usr/sbin/
make && make install
cp /usr/local/nginx/conf/nginx.conf /usr/local/nginx/conf/nginx.conf.bak
#修改配置文件
grep -Ev "^$|#" /usr/local/nginx/conf/nginx.conf.default >/usr/local/nginx/conf/nginx.conf
#sed -i 's/index  index.html index.htm/index  index.html index.htm index.php/g' \
# /usr/local/nginx/conf/nginx.conf
 cat >/usr/local/nginx/conf/nginx.conf <<EOF
worker_processes  1;
events {
    worker_connections  1024;
}
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    server {
        listen       80;
        server_name  localhost;
        location / {
            root   html;
            index  index.html index.htm index.php;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
        location ~ \.php$ {
            root           html;
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
            include        fastcgi_params;
        }
    }
}
EOF

nginx

#mysql
cd /root/
tar xf mysql-5.6.22.tar.gz
cd mysql-5.6.22/
useradd -M -s /sbin/nologin mysql
mkdir /mysql/data -p
chown mysql.mysql /mysql/ -R
yum install ncurses-devel cmake gcc gcc-c++ perl-Data-Dumper-Names.noarch -y
cmake . -DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
-DMYSQL_DATADIR=/mysql/data \
-DDEFAULT_CHARSET=utf8 \
-DEXTRA_CHARSETS=all \
-DDEFAULT_COLLATION=utf8_general_ci  \
-DWITH_SSL=system \
-DWITH_EMBEDDED_SERVER=1 \
-DENABLED_LOCAL_INFILE=1 \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_SSL=bundled
make -j2 && make install
/usr/local/mysql/scripts/mysql_install_db --user=mysql \
 --datadir=/mysql/data/ --basedir=/usr/local/mysql #初始化数据库
echo "[mysql]" > /etc/my.cnf  #修改配置文件
echo 'export PATH=/usr/local/mysql/bin:$PATH' > /etc/profile.d/mysql.sh #设置成系统命令
source /etc/profile.d/mysql.sh
cp  /usr/local/mysql/support-files/mysql.server   /etc/init.d/mysqld
chkconfig --add mysqld   #开机自启动
/usr/local/mysql/bin/mysqld_safe --user=mysql & #后台运行数据库
mysql -e "create database wordpress;"  #创建库
#授权可以使用数据库的用户
mysql -e "grant all on wordpress.* to qh@localhost identified by '123';" 
mysql -e "flush privileges;"
source /etc/profile.d/mysql.sh

#php
cd /root/
tar xf php-5.6.30.tar.gz
cd php-5.6.30
yum install libxml2-devel libpng-devel gcc gcc-c++ -y
./configure --prefix=/usr/local/php5 \
--with-gd --with-zlib \
--with-config-file-path=/usr/local/php5 \
--enable-mbstring \
--enable-fpm \
--with-mysql=mysqlnd \
--with-mysqli=mysqlnd
make -j2 && make install
#修改配置文件
grep -Ev "^;|^ *$" /usr/local/php5/etc/php-fpm.conf.default >/usr/local/php5/etc/php-fpm.conf
#sed -i.bak 's/listen.*/listen = 192.168.127.7:9000/' /usr/local/php5/etc/php-fpm.conf
sed -i '/pm.max_children/c pm.max_children = 50' /usr/local/php5/etc/php-fpm.conf
sed -i 's/pm.start_servers.*/pm.start_servers = 10/' /usr/local/php5/etc/php-fpm.conf
sed -i 's/pm.min_spare_servers.*/pm.min_spare_servers = 10/' /usr/local/php5/etc/php-fpm.conf
sed -i 's/pm.max_spare_servers.*/pm.max_spare_servers = 30/' /usr/local/php5/etc/php-fpm.conf
/usr/local/php5/sbin/php-fpm  #启动php
echo "/usr/local/php5/sbin/php-fpm" >> /etc/rc.d/rc.local #设置开机自启动
chmod +x /etc/rc.d/rc.local
#bushu wordpress
cd /root
tar xf wordpress-4.5.3-zh_CN.tar.gz
rm -rf /usr/local/nginx/html/*
mv wordpress/* /usr/local/nginx/html/

