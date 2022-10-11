#!/bin/bash
rm -f /flexcube.sh
su - gsh

touch /domainsDetails.properties
echo "ds.jdbc.new.1=$1" > domainsDetails.properties
echo "ds.password.new.1=$2" >> domainsDetails.properties

# download Flexcube-Package
wget https://objectstorage.us-ashburn-1.oraclecloud.com/p/71aen4051joUYb_zGgBM8uC_E5oTHxlsu_9sRyUKN2npD5ZKDeVXXxNEJZXdBPhI/n/idcci5ks1puo/b/flexcubeBucketNewVersion/o/Flexcube-Package.zip
mv Flexcube-Package.zip /
cd /
unzip /Flexcube-Package.zip
sh /flexcube.sh
#chown gsh:gsh /config.xml
mv /config.xml /scratch/gsh/kernel145/user_projects/domains/integrated/config/config.xml

sh /JDBCReplace.sh /JDBCList $1 $2
sh /ExecuteWebLogic.sh
sleep 180
sh /StartApps.sh

