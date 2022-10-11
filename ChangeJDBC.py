from java.io import FileInputStream
 
propInputStream = FileInputStream("/domainsDetails.properties")
configProps = Properties()
configProps.load(propInputStream)
 
for i in 1,1:
    newJDBCString = configProps.get("ds.jdbc.new."+ str(i))
    newDSPassword = configProps.get("ds.password.new."+ str(i))
    i = i + 1
 
    print("*** Trying to Connect.... *****")
    connect('weblogic','weblogic123','t3://localhost:7001')
    print("*** Connected *****")
    cd('/Servers/AdminServer')
    edit()
    startEdit()
    cd('JDBCSystemResources')
    pwd()
    ls()
    allDS=cmo.getJDBCSystemResources()
    for tmpDS in allDS:
               dsName=tmpDS.getName();
               print ('DataSource Name: ', dsName)
               print (' ')
               print (' ')
               print ('Changing Password & URL for DataSource ', dsName)
               cd('/JDBCSystemResources/'+dsName+'/JDBCResource/'+dsName+'/JDBCDriverParams/'+dsName)
               print('/JDBCSystemResources/'+dsName+'/JDBCResource/'+dsName+'/JDBCDriverParams/'+dsName)
               set('PasswordEncrypted', newDSPassword)
               cd('/JDBCSystemResources/'+dsName+'/JDBCResource/'+dsName+'/JDBCDriverParams/'+dsName)
               set('Url',newJDBCString)
               print("*** CONGRATES !!! Username & Password has been Changed for DataSource: ", dsName)
               print ('')
               print ('')
 
save()
activate()
