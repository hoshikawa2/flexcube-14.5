yum install unzip -y
yum install wget -y
su - gsh
cd /
#wget "https://objectstorage.ap-mumbai-1.oraclecloud.com/p/x_jm7V8SukeVvV0Jeh-Pf3u_B_bWtcyn1nZ1CDcwaGLngSi4o-eUtdNtV4joKFK2/n/ids3optpuczi/b/14.5Deployment/o/kernel145_17Nov21.zip"
wget https://objectstorage.ap-mumbai-1.oraclecloud.com/p/XTl-V6bdphhbdUnf3hk0ut6xG247GcLrjqKxK8tN9TqL9w3QeYCanz2aKO1dz2Wu/n/ids3optpuczi/b/IB14.5/o/Integrated145/Product_Processor/kernel145_17Nov21.zip
unzip -o kernel145_17Nov21.zip -d /
cd /scratch/gsh/kernel145/user_projects/domains/integrated/bin

