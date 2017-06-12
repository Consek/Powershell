#Resolve DNS name
Resolve-DnsName $name -Type Any -Server $Server

#Flush DNS Cache
Clear-DnsClientCache