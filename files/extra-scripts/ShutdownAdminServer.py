from java.io import FileInputStream

print("*** Trying to Connect.... *****")
connect('weblogic','weblogic123','t3://localhost:7001')
print("*** Connected *****")

shutdown('AdminServer')

