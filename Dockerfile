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
