# 1. 🎁最终产出物：
源码：https://github.com/fullee/mysql4

容器：https://hub.docker.com/repository/docker/fullee/mysql

视频：B站

## 参考资料
mysql历史版本：https://dbstudy.info/mysqlarchives/

mysql4.0.27在centos6.7上的安装教程：http://www.terasol.co.jp/linux/386

## yum仓库配置
访问阿里云镜像站：https://developer.aliyun.com/mirror/
```
curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-6.repo
```

cat /etc/centos-release
由于centos的某些版本官方不再支持，若继续使用默认仓库地址会抛出404异常。对应版本的软件仓库应迁移到centos-vault仓库可以继续访问。
例如：
```txt
https://mirrors.aliyun.com/centos/$releasever
变更为👇
https://mirrors.aliyun.com/centos-vault/6.7
```

## dockerfile最佳实践
1. 基于一个容器运行，不会污染宿主机，同时能构建一个很棒测试环境
```sh
docker run -it alpine:3.1 '/bin/sh'

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN set -x;
```
2. 使用vscode插件Remote Development，可以直接在本地编辑服务器上的文件


# 2. 🚾试验试验脚本
### server-entry.sh
```shell
#!/bin/sh

set -xv
set -eo pipefail

if [ "${1:0:1}" = '-' ]; then
  set -- mysqld_safe "$@"
fi

HOSTNAME=$(hostname)

file_env() {
  var=$1
  file_var="${var}_FILE"
  var_value=$(printenv $var || true)
  file_var_value=$(printenv $file_var || true)
  default_value=$2

  if [ -n "$var_value" -a -n "$file_var_value" ]; then
    echo >&2 "error: both $var and $file_var are set (but are exclusive)"
    exit 1
  fi

  if [ -z "${var_value}" ]; then
    if [ -z "${file_var_value}" ]; then
      export "${var}"="${default_value}"
    else
      export "${var}"="${file_var_value}"
    fi
  fi

  unset "$file_var"
}

_get_config() {
  conf="$1"
# mysqld_safe --help > /dev/null
  cat /etc/my.cnf | grep -i 'datadir=' | cut -d '=' -f 2
}

DATA_DIR="$(_get_config 'datadir')"

if [ ! -d "${DATA_DIR}mysql" ]; then
  file_env 'MYSQL_ROOT_PASSWORD'
  if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
    echo >&2 'error: database is uninitialized and password option is not specified '
    echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
    exit 1
  fi

  echo $"$DATA_DIR"
  mkdir -p "$DATA_DIR"
  chown mysql: "$DATA_DIR"

  echo 'Initializing database'
  /usr/local/mysql-4.0.27/bin/mysql_install_db --user=mysql --datadir="$DATA_DIR" --rpm
  chown -R mysql: "$DATA_DIR"
  echo 'Database initialized'

  tfile=`mktemp`
  if [ ! -f "$tfile" ]; then
      return 1
  fi

  cat << EOF > $tfile
USE mysql;
FLUSH PRIVILEGES;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY "$MYSQL_ROOT_PASSWORD" WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
UPDATE user SET password=PASSWORD("") WHERE user='root' AND host='localhost';
EOF

  if [ "$MYSQL_DATABASE" != "" ]; then
    echo "[i] Creating database: $MYSQL_DATABASE"
    echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $tfile

    if [ "$MYSQL_USER" != "" ]; then
      echo "[i] Creating user: $MYSQL_USER with password $MYSQL_PASSWORD"
      echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* to '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" >> $tfile
    fi
  fi

  mysqld_safe --user=root --bootstrap --datadir="$DATA_DIR" < $tfile
fi

chown -R mysql: "$DATA_DIR"
exec "$@"

```


### my.cnf -->/etc/my.cnf
```
# Example MySQL config file for medium systems.
#
# This is for a system with little memory (32M - 64M) where MySQL plays
# an important part, or systems up to 128M where MySQL is used together with
# other programs (such as a web server)
#
# You can copy this file to
# /etc/my.cnf to set global options,
# mysql-data-dir/my.cnf to set server-specific options (in this
# installation this directory is /usr/local/mysql-4.0.27/var) or
# ~/.my.cnf to set user-specific options.
#
# In this file, you can use all long options that a program supports.
# If you want to know which options a program supports, run the program
# with the "--help" option.

# The following options will be passed to all MySQL clients
[client]
#password       = your_password
port            = 3306
socket          = /tmp/mysql.sock
default-character-set=gbk

# Here follows entries for some specific programs

# The MySQL server
[mysqld]
datadir=/data
port            = 3306
socket          = /tmp/mysql.sock
skip-locking
key_buffer = 16M
max_allowed_packet = 1M
table_cache = 64
sort_buffer_size = 512K
net_buffer_length = 8K
myisam_sort_buffer_size = 8M
default-character-set=gbk
log-error=/var/log/mysql/myerror.log

# Don't listen on a TCP/IP port at all. This can be a security enhancement,
# if all processes that need to connect to mysqld run on the same host.
# All interaction with mysqld must be made via Unix sockets or named pipes.
# Note that using this option without enabling named pipes on Windows
# (via the "enable-named-pipe" option) will render mysqld useless!
#
#skip-networking

# Replication Master Server (default)
# binary logging is required for replication
log-bin

# required unique id between 1 and 2^32 - 1
# defaults to 1 if master-host is not set
# but will not function as a master if omitted
server-id       = 1

# Replication Slave (comment out master section to use this)
#
# To configure this host as a replication slave, you can choose between
# two methods :
#
# 1) Use the CHANGE MASTER TO command (fully described in our manual) -
#    the syntax is:
#
#    CHANGE MASTER TO MASTER_HOST=<host>, MASTER_PORT=<port>,
#    MASTER_USER=<user>, MASTER_PASSWORD=<password> ;
#
#    where you replace <host>, <user>, <password> by quoted strings and
#    <port> by the master's port number (3306 by default).
#
#    Example:
#
#    CHANGE MASTER TO MASTER_HOST='125.564.12.1', MASTER_PORT=3306,
#    MASTER_USER='joe', MASTER_PASSWORD='secret';
#
# OR
#
# 2) Set the variables below. However, in case you choose this method, then
#    start replication for the first time (even unsuccessfully, for example
#    if you mistyped the password in master-password and the slave fails to
#    connect), the slave will create a master.info file, and any later
#    change in this file to the variables' values below will be ignored and
#    overridden by the content of the master.info file, unless you shutdown
#    the slave server, delete master.info and restart the slaver server.
#    For that reason, you may want to leave the lines below untouched
#    (commented) and instead use CHANGE MASTER TO (see above)
#
# required unique id between 2 and 2^32 - 1
# (and different from the master)
# defaults to 2 if master-host is set
# but will not function as a slave if omitted
#server-id       = 2
#
# The replication master for this slave - required
#master-host     =   <hostname>
#
# The username the slave will use for authentication when connecting
# to the master - required
#master-user     =   <username>
#
# The password the slave will authenticate with when connecting to
# the master - required
#master-password =   <password>
#
# The port the master is listening on.
# optional - defaults to 3306
#master-port     =  <port>
#
# binary logging - not required for slaves, but recommended
#log-bin

# Point the following paths to different dedicated disks
#tmpdir         = /tmp/
#log-update     = /path-to-dedicated-directory/hostname

# Uncomment the following if you are using BDB tables
#bdb_cache_size = 4M
#bdb_max_lock = 10000

# Uncomment the following if you are using InnoDB tables
#innodb_data_home_dir = /usr/local/mysql-4.0.27/var/
#innodb_data_file_path = ibdata1:10M:autoextend
#innodb_log_group_home_dir = /usr/local/mysql-4.0.27/var/
#innodb_log_arch_dir = /usr/local/mysql-4.0.27/var/
# You can set .._buffer_pool_size up to 50 - 80 %
# of RAM but beware of setting memory usage too high
#innodb_buffer_pool_size = 16M
#innodb_additional_mem_pool_size = 2M
# Set .._log_file_size to 25 % of buffer pool size
#innodb_log_file_size = 5M
#innodb_log_buffer_size = 8M
#innodb_flush_log_at_trx_commit = 1
#innodb_lock_wait_timeout = 50

[mysqldump]
quick
max_allowed_packet = 16M
default-character-set=gbk

[mysql]
no-auto-rehash
default-character-set=gbk
# Remove the next comment character if you are not familiar with SQL
#safe-updates

[isamchk]
key_buffer = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M

[myisamchk]
key_buffer = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout
```



### Dockerfile
```dockerfile
FROM centos:centos6.7

WORKDIR /usr/local/src

ENV MYSQL_VER="4.0.27"

ADD mysql-${MYSQL_VER}.tar.gz ./

COPY my.cnf /etc/my.cnf

# 1.调整容器时区
RUN \cp -p /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-6.repo 
RUN sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo
RUN sed -i -e 's@mirrors.aliyun.com/centos/$releasever@mirrors.aliyun.com/centos-vault/6.7@g' /etc/yum.repos.d/CentOS-Base.repo
RUN yum makecache && yum install -y tar ncurses-devel compat-gcc-34 compat-gcc-34-c++

RUN groupadd mysql && useradd -g mysql mysql
RUN mkdir /usr/local/mysql-4.0.27 && mkdir /var/log/mysql

RUN cd mysql-${MYSQL_VER} \
&& sed -i -e "40d" -e "42d" mysys/my_thr_init.c \
&& CC=/usr/bin/gcc34 CXX=/usr/bin/g++34 ./configure --prefix=/usr/local/mysql-4.0.27 --with-charset=gbk --with-extra-charsets=all --with-mysqld-user=mysql --with-named-thread-libs="-lpthread" \
&& make \
&& make install \
&& ln -sfn /usr/local/mysql-4.0.27 /usr/local/mysql \
&& ln -s /usr/local/mysql-4.0.27/bin/mysqld_safe /usr/local/bin/mysqld_safe \
&& ln -s /usr/local/mysql-4.0.27/bin/mysqladmin /usr/local/bin/mysqladmin \
&& ln -s /usr/local/mysql-4.0.27/bin/mysql /usr/local/bin/mysql

# RUN /usr/local/mysql-4.0.27/bin/mysql_install_db --user=mysql

COPY server-entry.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod u+x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

RUN chown -R mysql /usr/local/mysql

VOLUME /data

EXPOSE 3306

CMD ["mysqld_safe"]
```


### docker-compose
```yaml
version: '3'
services:
  mysql:
    build:
      context: .
      dockerfile: Dockerfile
    image: mysql:4.0.27
    environment:
      - MYSQL_ROOT_PASSWORD=123456
#      - TZ=Asia/Shanghai
    volumes:
      - ./volume/conf/my.cnf:/etc/my.cnf
      - ./volume/data:/data
#    command: --lower-case-table-names=1 --initialize-insecure
    ports:
      - "3316:3306"
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "1m"

```
