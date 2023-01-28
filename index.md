# Deploy Flexcube on OCI OKE with ORACLE VISUAL BUILDER STUDIO
___
### Introduction
___
Oracle FLEXCUBE Universal Banking requires several steps to be performed before having an environment up and running. Being a Java Enterprise Edition (JEE) application, it includes a minimal software base to be installed, such as database and application server. For this example, Oracle Weblogic and Oracle Database are used as part of the technical stack. To enable a full up and running system, a standard deployment would follow these steps:

![steps-flexcube-vm.png](./images/steps-flexcube-vm.png?raw=true)

An application installer does the initial steps. The process is repeatable but it’s also time consuming which means that, depending on the complexity of the environment to be created, it may take several days to stand up the system. One way of improving this process is to automate most of it and that is where containerization strategies can benefit these types of architectures.

The first 7 steps listed before could be completely automated using containers, such as docker images and a combination of tools to maintain and manage that. The data configured in the database becomes a replicable seed artifact and the application layer is transformed into an image already tuned and stored as a master
copy. Oracle Cloud Infrastructure then provides elements to replicate anytime a full environment based on that master copy of the system.

> **Note**: Could the database or potentially different data stores also be in independent containers? Potentially yes, but it was decided to keep it as a regular cloud database deployment with all data store into the same schema and preserve any existing common practice at the database level. The intention of this exercise is not transforming this architecture into a microservices based architecture because that would require other structural changes which are not part of the scope. More information on Oracle database on docker is available at the Oracle’s github (https://github.com/oracle/docker-images/tree/main/OracleDatabase).

___
### Objectives

This document will show how to:

* Deploy quickly a Flexcube Image manually
* Create a Container Flexcube Image
* Create a DevOps build and deploy Flexcube inside a Kubernetes Cluster

### Prerequisites

* An OKE Cluster created
  * A worker-node with at least
    * 8 OCPUs
    * 64GB RAM
* kubectl access to OKE Cluster for local operations
* A Flexcube Database backup in OCI Database (DBaaS)
* OKE VCN needs to access the DBaaS
* Permission and limit usage to create:
  * Load-Balancers
  * Block Volume Storage
* JDBC configuration for your Flexcube backup
  * username
  * password
  * Oracle Database Endpoint (IP/Port)
* A knowledge in:
  * Weblogic Administration and Tools usage
    * Use of setWLSEnv.sh
  * Kubernetes basic administration
  * Visual Builder or Jenkins Operation

## Task 1: Create a Weblogic Admin Server
___
Let's begin with a simple Weblogic Admin Server POD in your Kubernetes Cluster.

In the /files/weblogic folder you can find:

- README: Some links that helps you to create your OKE Cluster if you not created
- secret.sh: A bash script that helps you to create the secret to access the Oracle Image Repository to use the Weblogic image
- weblogic.yaml: The YAML file to create an instance of Weblogic and the Service ports to access the admin server

> **Note**: You need to assign the Oracle Image Repository and set your credentials (user/password) to obtain the Weblogic Image. You can follow this link to do this: https://oracle.github.io/weblogic-kubernetes-operator/2.6/userguide/managing-domains/domain-in-image/base-images/#obtaining-standard-images-from-the-oracle-container-registry



**weblogic.yaml**

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: weblogic-deployment
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: weblogic
      template:
        metadata:
          labels:
            app: weblogic
        spec:
          containers:
          - name: weblogic
            image: container-registry.oracle.com/middleware/weblogic:12.2.1.4
            env:
            - name: DOMAIN_NAME
              value: "myDomain"
            - name: ADMIN_NAME
              value:  "myadmin"
            - name: ADMIN_LISTEN_PORT
              value: "7001"
            - name: ADMIN_HOST
              value: "AdminContainer"
            - name: ADMINISTRATION_PORT_ENABLED
              value: "false"
            - name: ADMINISTRATION_PORT
              value: "9005"
            - name: MANAGED_SERVER_PORT
              value: "8001"
            - name: MANAGED_SERVER_NAME_BASE
              value: "MS"
            - name: CONFIGURED_MANAGED_SERVER_COUNT
              value: "2"
            - name: CLUSTER_NAME
              value: "cluster1"
            - name: CLUSTER_TYPE
              value: "DYNAMIC"
            - name: PRODUCTION_MODE
              value: "dev"
            - name: DOMAIN_HOST_VOLUME
              value: "/app/domains"
            - name: PROPERTIES_FILE_DIR
              value: "/u01/oracle/properties"
            - name: PROPERTIES_FILE
              value: "/u01/oracle/properties/domain.properties"
            command: [ "/bin/bash", "-c", "--" ]
            args: [ "mkdir /u01/oracle/properties; cd /u01/oracle/properties; echo 'username=weblogic' > domain.properties; echo 'password=weblogic123' >> domain.properties; cd /u01/oracle; ./createAndStartEmptyDomain.sh; while true; do sleep 30;
    done;" ]
            ports:
            - name: port9005
              containerPort: 9005
          imagePullSecrets:
          - name: oracledockersecret
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: weblogic-service
      labels:
        app: weblogic
    spec:
      selector:
        app: weblogic
      ports:
        - port: 7001
          targetPort: 7001
          name: adminserver
        - port: 8001
          targetPort: 8001
          name: managedserver
        - port: 9005
          targetPort: 9005
          name: adminport
      type: LoadBalancer
    ---

In your terminal, you can execute the weblogic.yaml to deploy the admin server.

    kubectl apply -f weblogic.yaml

You can see the services and load-balancers port to access your admin server. Execute this command:

    kubectl get svc

You can view something like this:

![weblogic-svc.png](./images/weblogic-svc.png?raw=true)

Note a **pending** value in your **weblogic-service**. It means that a load-balancer is not ready with a public IP.
Wait a minute and then you can repeat the kubectl command to view the public IP.

With a public IP address, you can call in your browser:

    http://<Public IP>:7001/console

![weblogic-admin.png](./images/weblogic-admin.png?raw=true)

You can see now the admin server. The user and password, as defined in your YAML file is:

    user: weblogic
    password: weblogic123

![weblogic-machine-1.png](./images/weblogic-machine-1.png?raw=true)


## Task 2: Obtain the database password in AES256 format

### Check the Flexcube Database Backup

Remember that you need the Oracle Database in the OCI DBaaS and restore your Flexcube backup.
After checking the restoration of a valid Flexcube database backup, you need this information to access the Flexcube database content:
- Endpoint (IP/Port)
- Username
- Password

You cannot use the password in text format, you need to convert your password into an AES256 format. The easiest way to convert your password into an AES256 format is using the Weblogic tool:

    setWLSEnv.sh 

You can find this tool bash script in the Weblogic path:

    ./oracle/wlserver/server/bin

To convert your password, you need to execute this commands like this:

    cd ./oracle/wlserver/server/bin
    .  ./setWLSEnv.sh
    java -Dweblogic.RootDirectory=../user_projects/domains/integrated  weblogic.security.Encrypt <Database Password>

After the execution of setWLSEnv.sh, you get a password in AES256 format like this example:

    {AES256}7kfaltdnEBjKNq.......RIU0IcLOynq1ee8Ib8=

With all the database information, you can go to the next step.

Let's use your newer Weblogic Admin Server POD to execute this command. In your terminal execute:

    kubectl exec -it $(kubectl get pod -l app=weblogic -o jsonpath="{.items[0].metadata.name}") -- /bin/bash

Wait until you can enter inside the container of your Weblogic. Execute this sequence of commands:

    cd /u01/oracle/wlserver/server/bin
    .  ./setWLSEnv.sh
    java -Dweblogic.RootDirectory=/u01/oracle/user_projects/domains/myDomain weblogic.security.Encrypt <Database Password>

    Replace <Database Password> with your text Password

You can see the {AES256} password. Save this information for the next steps.

Execute this command to exit from the Container:

    exit

Now you can delete your Weblogic Admin Server. You need to delete it because of Flexcube, it will use the port 7001 too.

    kubectl delete -f weblogic.yaml

## Task 3: Execute a manual deployment with kubectl
___
You can deploy the Flexcube (fcubs) in your OKE Cluster with the **kubectl** command.
It can be done in your local machine if you have configured the access to the OKE Cluster for kubectl command tool.

See this Tutorial to create an OKE Cluster in your OCI Tenant.

    https://docs.oracle.com/en/solutions/build-rest-java-application-with-oke/configure-your-kubernetes-cluster-oracle-cloud1.html#GUID-932C716F-0C1F-4178-A9EF-1A1B37B3D6DF

If you already have created the OKE Cluster, please see if you configured the Access to the Cluster on "Download the Kubeconfig File" topic.

### Let's understand the integrated145.yaml File

The yaml file contains a few important parameters to create the pod. Includes deployment name, recognize the internal IP/hostname, where to pick the image from Weblogic, the jdbc connection and the encrypted database access.
![yaml1.png](./images/yaml1.png?raw=true)

In the same yaml file, it is also defined the sizing expected by the pod, considering the number of resources required and up to the limit it can grow in case of increase of consumption.
![yaml2.png](./images/yaml2.png?raw=true)

The ports to be exposed are also defined in the yaml file, which enables personalized security. The application can be accessed by business user, weblogic console by administrator, web services by developers, and so on.
![yaml3.png](./images/yaml3.png?raw=true)

> **Note**: In this scenario, we have created all services in the same POD. To scale, we would need to scale it all. A good way to break a monolith, though, would be to instantiate different pods using different ports being exposed in different Weblogic servers. Consequently, the pods could be scaled independently. As an example: A web services POD heavily used in integrations could require and use 10 cores and scale whenever needed while the application (deployed in the other pod) would require only 2 cores and would have a more “constant” behavior.

This is the **integrated145.yaml** file:

    ---
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: flexcubeclaim
    spec:
      accessModes:
        - ReadWriteOnce
      storageClassName: oci-bv
      resources:
        requests:
          storage: 500Gi
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: integrated145-deployment
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: integrated145
      template:
        metadata:
          labels:
            app: integrated145
        spec:
          hostname: integrated145
          hostAliases:
          - ip: "127.0.0.1"
            hostnames:
            - "fcubs.oracle.com"
          containers:
          - name: integrated145
            image: gru.ocir.io/idvkxij5qkne/oraclefmw-infra:12.2.1.4.0_jdk8u281_pt34080315_apr22
            command: [ "/bin/sh", "-c"]
            args:
             [ "sleep 180; su - gsh ; cd /; yum -y install wget; wget https://objectstorage.us-ashburn-1.oraclecloud.com/p/dX80UuetlAvWOEbvQNMBv47H3ZPR-zZHJJmTsu_GQ66icfgFaPSSu_97j8q3Fyrp/n/idcci5ks1puo/b/flexcubeBucketNewVersion/o/initializeConfig.sh; yum -y install unzip; sh initializeConfig.sh jdbc:oracle:thin:@x.x.x.x:1521/prodpdb.sub0xxxxxxxxx0.arspvcn.oraclevcn.com {AES256}AgWyiXhc7aM112gNRUwBIWf5QpTpWMlI537LrIfPWjCcmwNCsynBxxg99; while true; do sleep 30; done;" ]
            ports:
            - name: port7001
              containerPort: 7001
            - name: port7002
              containerPort: 7002
            - name: port7003
              containerPort: 7003
            - name: port7004
              containerPort: 7004
            - name: port7005
              containerPort: 7005
            - name: port7006
              containerPort: 7006
            - name: port7007
              containerPort: 7007
            - name: port7008
              containerPort: 7008
            - name: port7009
              containerPort: 7009
            - name: port7010
              containerPort: 7010
            - name: port7011
              containerPort: 7011
            - name: port7012
              containerPort: 7012
            - name: port7013
              containerPort: 7013
            - name: port7014
              containerPort: 7014
            - name: port7015
              containerPort: 7015
            - name: port7016
              containerPort: 7016
            - name: port7017
              containerPort: 7017
            - name: port7018
              containerPort: 7018
            - name: port7019
              containerPort: 7019
            - name: port7020
              containerPort: 7020
            - name: port5556
              containerPort: 5556
    #        livenessProbe:
    #          httpGet:
    #            path: /console
    #            port: 7001
    #          initialDelaySeconds: 3000
    #          timeoutSeconds: 30
    #          periodSeconds: 300
    #          failureThreshold: 3
            volumeMounts:
              - name: data
                mountPath: /scratch/gsh/kernel145
                readOnly: false
            resources:
              requests:
                cpu: "5"
                memory: "36Gi"
                #ephemeral-storage: "500Gi"
              limits:
                cpu: "8"
                memory: "64Gi"
                #ephemeral-storage: "500Gi"
    #      restartPolicy: Always
          volumes:
            - name: data
              persistentVolumeClaim:
                claimName: flexcubeclaim
          imagePullSecrets:
          - name: ocirsecret
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: integrated145-service
      labels:
        app: integrated145
    #  annotations:
    #    service.beta.kubernetes.io/oci-load-balancer-internal: "true"
    #    service.beta.kubernetes.io/oci-load-balancer-shape: "100Mbps"
    #    service.beta.kubernetes.io/oci-load-balancer-subnet1: "ocid1.subnet.oc1.sa-saopaulo-1.aaaaaaaay4rjx6d5o6nwqehxusgwrig432xzek5dbojxie7lw25fhmzjyrza"
    spec:
      selector:
        app: integrated145
      ports:
        - port: 7004
          targetPort: 7004
      type: LoadBalancer
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: integrated145-service-weblogic
      labels:
        app: integrated145
    #  annotations:
    #    service.beta.kubernetes.io/oci-load-balancer-internal: "true"
    #    service.beta.kubernetes.io/oci-load-balancer-shape: "100Mbps"
    #    service.beta.kubernetes.io/oci-load-balancer-subnet1: "ocid1.subnet.oc1.sa-saopaulo-1.aaaaaaaay4rjx6d5o6nwqehxusgwrig432x25fhmzjyrza"
    spec:
      selector:
        app: integrated145
      ports:
        - port: 7001
          targetPort: 7001
      type: LoadBalancer
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name:  or Jenkins
      labels:
        app: integrated145
    #  annotations:
    #    service.beta.kubernetes.io/oci-load-balancer-internal: "true"
    #    service.beta.kubernetes.io/oci-load-balancer-shape: "100Mbps"
    #    service.beta.kubernetes.io/oci-load-balancer-subnet1: "ocid1.subnet.oc1.sa-saopaulo-1.aaaaaaaay4rjx6d5o6nwqehxusgwrig432e7lw25fhmzjyrza"
    spec:
      selector:
        app: integrated145
      ports:
        - port: 7005
          targetPort: 7005
      type: LoadBalancer
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: integrated145-webservices2
      labels:
        app: integrated145
    #  annotations:
    #    service.beta.kubernetes.io/oci-load-balancer-internal: "true"
    #    service.beta.kubernetes.io/oci-load-balancer-shape: "100Mbps"
    #    service.beta.kubernetes.io/oci-load-balancer-subnet1: "ocid1.subnet.oc1.sa-saopaulo-1.aaaaaaaay4rjx6d5o6nwqehxusgwrig4xie7lw25fhmzjyrza"
    spec:
      selector:
        app: integrated145
      ports:
        - port: 7009
          targetPort: 7009
      type: LoadBalancer

> **Resilience**: The Flexcube deployment is resilient, so if the Weblogic or Flexcube falls down, the Kubernetes Cluster will load and execute again. The responsible for this is the livenessprobe inside the integrated145.yaml file.
Uncomment this lines if you want to activate a check in your container:

    #        livenessProbe:
    #          httpGet:
    #            path: /console
    #            port: 7001
    #          initialDelaySeconds: 3000
    #          timeoutSeconds: 30
    #          periodSeconds: 300
    #          failureThreshold: 3

### Let's understand some script files

Some files are keys for:

- Deploy the Flexcube structure inside the Fusion Image
- Configure JDBCs datasources to access the Flexcube Database
- Configure another parameters necessary to make Flexcube up and running

Now, let's describe this files:

#### Flexcube-Package.zip

This Package is a zip file. It contains all the scripts necessary to configure and run the Flexcube instance. The content of this package is in /files/scripts/ folder. This package contains:

>**initializeConfig.sh**: The main file that runs all other scripts to configure and run Flexcube

>**domainsDetails.properties**: The base file that will be changed by initializeConfig.sh script

>**config.xml**: The base file that will be changed by initializeConfig.sh script

>**flexcube.sh**: Downloads the Flexcube v14.5 structure inside the POD

>**JDBCReplace.sh**: This script replaces all the JDBC datasources with the Flexcube database endpoint (IP/Port), flexcube database username and password (AES256 format)

>**JDBCList**: This file contains all XML files related with the application datasources. It will be used by **JDBCReplace.sh**

>**ExecuteWebLogic.sh**: Run Weblogic Domain Server, Node Manager and starts applications (with StartApps.sh and StartApps.py)

>**StartApps.sh**: Script to run the WLST script StartApps.py

>**StartApps.py**: Script that runs the Flexcube applications

>**Note**: The /files/extra-scripts contains some more scripts that will be usefull for additional tasks. It's not part of the core of this tutorial.

### Prepare the YAML File

In this step, you need to configure the YAML file integrated145.yaml.
This YAML file is responsible to deploy the application, the access to the application through a load-balancer and create a storage to persistence.

The configuration is basically to put the database information into the YAML file.

Find this line in **integrated145.yaml** file:
![integrated-yaml-line1](./images/integrated-yaml-line1.png?raw=true)

Go with your cursor forward until find this location:

    sh initializeConfig.sh jdbc:oracle:thin:@x.x.x.x:1521/prodpdb.sub0xxxxxxxxx0.arspvcn.oraclevcn.com

You need to change the **x.x.x.x:1521/prodpdb.sub0xxxxxxxxx0.arspvcn.oraclevcn.com** with your DBaaS endpoint.

Go with your cursor forward until find this location:

    {AES256}AgWyiXhc7aM112gNRUwBIWf5QpTpWMlI537LrIfPWjCcmwNCsynBxxg99

You need to change the {AES256} with your password generated in the previous step.

### Execute the integrated145.yaml File

After everything is configured, execute the YAML file:

    kubectl apply -f integrated145.yaml

The process of creating the Flexcube structure, configure and turn the server and application UP could takes approximately 15 minutes.
So wait this time and execute this command to view the services and load-balancers port:

    kubectl get svc

You can see the Load Balancers Public IPs in creation time. Wait until all the Public IPs are visible.

    NAME                                 TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                                                                                                                   AGE
    integrated145-service                LoadBalancer   10.96.109.81    210.0.30.217     7004:30868/TCP                                                                                                           200d
    integrated145-service-weblogic       LoadBalancer   10.96.255.72    210.0.30.188     7001:32071/TCP                                                                                                           200d
    integrated145-webservices            LoadBalancer   10.96.62.106    210.0.30.50      7005:30415/TCP                                                                                                           200d
    integrated145-webservices2           LoadBalancer   10.96.237.22    210.0.30.165     7009:30759/TCP                                                                                                           200d

>**Note**: In the integrated145.yaml file, you can see in the **Service** section, the **annotation** is commented. This annotation creates the load-balancer in private mode and your application will be more secure, but you need to create a bastion to access this applications.

    #  annotations:
    #    service.beta.kubernetes.io/oci-load-balancer-internal: "true"
    #    service.beta.kubernetes.io/oci-load-balancer-shape: "100Mbps"
    #    service.beta.kubernetes.io/oci-load-balancer-subnet1: "ocid1.subnet.oc1.sa-saopaulo-1.aaaaaaaay4rjx6d5o6nwqehxusgwrig432xzek5dbojxie7lw25fhmzjyrza"

    Replace the subnet1 with your Private Subnet OCID
    If you choose to use Flexcube in a Private Subnet, create a compute VM as a bastion.

    You can stablish a SSH tunnel to access your endpoints like this:
    ssh -i PrivateKey.pem -L 7001:<integrated145-service-weblogic Private IP>:7001 opc@<Bastion Public IP>
    ssh -i PrivateKey.pem -L 7004:<integrated145-service Private IP>:7004 opc@<Bastion Public IP>
    ssh -i PrivateKey.pem -L 7005:<integrated145-webservices Private IP>:7004 opc@<Bastion Public IP>

    And can access with your local browser:
    http://localhost:7001/console
    https://localhost:7004/FCJNeoWeb
    http://localhost:7005/FCUBSAccService/FCUBSAccService?WSDL

After the IPs are visible. You can test your application. Open your browser and type:

    For the Weblogic Admin Server
    http://<integrated145-service-weblogic IP>:7001/console

    For the REST Service
    https://<integrated145-service IP>:7004/FCJNeoWeb

    For the SOAP Service
    http://<integrated145-webservices>:7005/FCUBSAccService/FCUBSAccService?WSDL
    http://<integrated145-webservices>:7009

Flexcube Application on Port 7004
![flexcube-interface](./images/flexcube-interface.png?raw=true)

SOAP Service on Port 7005
![soap-service](./images/soap-service.png?raw=true)


## Task 4: Automatize the Deployment of Flexcube

Let's do this task with a **Visual Builder Studio**. This tool is part of the **OCI** and is similar with **Jenkins**. So, if you use **Jenkins**, you can configure CI/CD with minor adjusts.

### Create Variables in Pipeline

You need to create 2 variables:

     JDBCString: Contains the JDBC String 
     Example: jdbc:oracle:thin:@x.x.x.x:1521/prodpdb.sub0xxxxxxxxx0.arspvcn.oraclevcn.com

     JDBCPassword: Contains an AES256 password format
     Example: {AES256}AgWyiXhc7aM112gNRUwBIWf5QpTpWMlI537LrIfPWjCcmwNCsynBxxg99

In Visual Builder, you can create the variables like this:
![vbst-config-parameters.png](./images/vbst-config-parameters.png?raw=true)

### Create the Steps in Pipeline

Now you need to create the steps for this pipeline. There are 2 steps:

    OCI CLI Step: Needed to create the connection with the tenant of your OKE Cluster
    UNIX Shell Step: Needed to execute the process of deployment

On the **Job Configuration** in **Visual Builder Studio**, click on **Add New** and select **OCICli**.
You need to put the OCI parameters to authorize the **Visual Builder Studio** to operate with your tenancy and OKE Cluster.

    User OCID
    Finger Print: You need to configure access to OCI CLI and upload a public key
    Tenancy OCID
    Private Key: The private key pair of your uploaded public key in Fingerprint
    Region: The region of your OKE Cluster
    Passphrase: If you have a password in your private key

After this, you need to click again on **Add New** and select **UNIX Shell**.
Put this script in the box:

    #  Prepare for kubectl from OCI CLI
    mkdir -p $HOME/.kube
    oci ce cluster create-kubeconfig --cluster-id ocid1.cluster.oc1.iad.aaaaaaaaae3tmyldgbtgmyjrmyzdeytbhazdmmbrgfstmntdgc2wmzrxgbrt --file $HOME/.kube/config --region us-ashburn-1 --token-version 2.0.0
    export KUBECONFIG=$HOME/.kube/config
    # Set Variables
    export JDBCString=$JDBCString
    export JDBCPassword=$JDBCPassword
    # setup the JDBC variables in integrated145-devops.yaml
    sed -i "s~--JDBCString--~$JDBCString~g" integrated145-devops.yaml
    sed -i "s~--JDBCPassword--~$JDBCPassword~g" integrated145-devops.yaml
    # Deploy integrated145
    kubectl config view
    kubectl replace -f integrated145-devops.yaml --force

>**Note**: Obtain the OKE OCID in your tenant and put in the line "oci ce cluster...". The **integrated145-devops.yaml** file is similar to the **integrated145.yaml** file, but prepared for the CI/CD.

In the **Visual Builder Studio** you see something like this:


![vbst-steps-config.png](./images/vbst-steps-config.png?raw=true)

So start your pipeline and wait for the deployment.
Again, list the services available with:

    kubectl get svc

    NAME                                 TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                                                                                                                   AGE
    integrated145-service                LoadBalancer   10.96.109.81    210.0.30.217     7004:30868/TCP                                                                                                           200d
    integrated145-service-weblogic       LoadBalancer   10.96.255.72    210.0.30.188     7001:32071/TCP                                                                                                           200d
    integrated145-webservices            LoadBalancer   10.96.62.106    210.0.30.50      7005:30415/TCP                                                                                                           200d
    integrated145-webservices2           LoadBalancer   10.96.237.22    210.0.30.165     7009:30759/TCP                                                                                                           200d

## Task 5: Delete the Flexcube deployment

To delete the deployment, just execute this command on your terminal:

    kubectl delete -f integrated145.yaml

## Related Links
____
### Configure a  Kubernetes Cluster on Oracle Cloud
https://docs.oracle.com/pt-br/solutions/build-rest-java-application-with-oke/configure-your-kubernetes-cluster-oracle-cloud1.html#GUID-9C7B9B7F-AC65-424E-9ED7-34A0606475A0

### Building WebLogic Server Images on Docker
https://docs.oracle.com/middleware/1213/wls/DOCKR/configuration.htm#DOCKR121

### Obtaining standard images from the Oracle Container Registry
https://oracle.github.io/weblogic-kubernetes-operator/2.6/userguide/managing-domains/domain-in-image/base-images/#obtaining-standard-images-from-the-oracle-container-registry

## Acknowledgements
___
- **Authors** - Cristiano Hoshikawa (LAD A-Team Solution Engineer), Eduardo Farah (Master Principal Sales Consultant & Banking Architect)