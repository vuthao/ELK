#! /bin/bash

source ./setup.conf.sh

if systemctl is-active --quiet filebeat; then
    echo "filebeat Đã được cài đặt, Không đạt yêu cầu..."
    exit
fi

echo "Tiến hành cài đặt filebeat"
echo "Thêm repo để tiến hành cài đặt"
echo '[elasticsearch-7.x]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
' > /etc/yum.repos.d/elasticsearch.repo

echo "Update và cài đặt java"
yum update -y
yum install java-1.8.0-openjdk-devel -y
echo "Cài đặt filebeat"
yum install filebeat -y
echo "Cấu hình filebeat"

echo "chỉnh sửa gửi dữ liệu đến logstash thay vì elasticsearch"
echo "Tắt gửi trực tiêp đến elasticsearch"
sed -i 's/output.elasticsearch:/#output.elasticsearch:/g' /etc/filebeat/filebeat.yml
sed -i 's/hosts: \[\"localhost:9200\"\]/#hosts: \[\"localhost:9200\"\]/g' /etc/filebeat/filebeat.yml

echo "Chỉnh sửa gửi dữ liệu đến logstash thay vì elasticsearch"
sed -i 's/#output.logstash:/output.logstash:/g' /etc/filebeat/filebeat.yml
sed -i "s/#hosts: \[\"localhost:5044\"\]/hosts: \[\"$ip_ELK:5044\"\]/g" /etc/filebeat/filebeat.yml


echo "Thêm đường dẫn để lấy được đầy đủ log"
sed -i 's/ enabled: false/ enabled: true/g' /etc/filebeat/filebeat.yml
sed -i 's/paths:/&\n    - \/var\/log\/*\/*\.log/' /etc/filebeat/filebeat.yml


echo "Mở kiabana để setup dashboards"
sed -i "s/#host: \"localhost:5601\"/host: \"$ip_ELK:5601\"/g" /etc/filebeat/filebeat.yml

echo "Khởi động các modules"
filebeat modules enable system
filebeat modules enable nginx
filebeat modules enable mysql
echo "Khởi động filebeat"

systemctl enable filebeat
systemctl start filebeat

echo "setup dashboards"
filebeat setup --dashboards


echo "Thiết lập mysql slow log"
echo "Kiểm tra mariadb đã được cài đặt chưa"
if systemctl is-active --quiet mariadb; then
    echo "Mariadb Đã được cài đặt"
else
    echo "Máy chưa cài đặt mariadb vậy nên sẽ chưa thể thiết lập slow log được cho DB vui lòng cài đặt mariadb"
    exit
fi
if systemctl is-active --quiet mysql; then
    echo "Mysql Đã được cài đặt"
else
    echo"Máy chưa cài đặt mariadb vậy nên sẽ chưa thể thiết lập slow log được cho DB vui lòng cài đặt mariadb"
    exit
fi

echo "Máy chủ đạt yêu cầu để thiết lập slow log cho mariadb"
echo "Tạo file lưu trữ slow log và phân quyền"

touch /var/log/mariadb-slow.log
chown mysql:mysql /var/log/mariadb-slow.log




echo "Config mariadb"
echo '
[mariadb]
slow_query_log
slow_query_log_file=mariadb-slow.log
slow_query_log_file=/var/log/mariadb-slow.log
log_output=FILE
long_query_time=1.0
log_queries_not_using_indexes=ON
' > /etc/my.cnf

systemctl restart mariadb
systemctl restart mysql
systemctl restart mysqld



exit 0
