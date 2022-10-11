#!/bin/bash
rm -f /flexcube.sh
su - gsh

touch /domainsDetails.properties
echo "ds.jdbc.new.1=$1" > domainsDetails.properties
echo "ds.password.new.1=$2" >> domainsDetails.properties

# download Flexcube-Package
wget https://objectstorage.us-ashburn-1.oraclecloud.com/p/ip03D9zHPtZHynEx5839DW8sQUNb4bkU4prp1rYYZKe6R-Xo1JCqh_7QCaXoKqir/n/id3kyspkytmr/b/bucket_banco_conceito/o/Flexcube-Package.zip
mv Flexcube-Package.zip /
cd /
unzip /Flexcube-Package.zip
sh /flexcube.sh
chown gsh:gsh /config.xml
mv /config.xml /scratch/gsh/kernel144/user_projects/domains/integrated/config/config.xml

sh /JDBCReplace.sh /JDBCList $1 $2
sh /ExecuteWebLogic.sh
sleep 180
sh /StartApps.sh

