#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
EC2_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
echo "<h1>Instance created with host name: $(hostname -f) from region: $EC2_REGION </h1>" > /var/www/html/index.html