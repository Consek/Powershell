# Creating new connection and defining connection string
$SQLConnection = New-Object  System.Data.SqlClient.SqlConnection
$SQLConnection.ConnectionString = "Server=$Server;Integrated Security=True"

# Opening connection to db
$ErrorActionPreference = "STOP"
try{
    $SQLConnection.Open()
}catch{
    $err = $_.ExceptionMessage | Format-List -Force | Out-String
    Write-Host "Error connecting to database."
    Write-Host $err
}

$SQLCmd = New-Object System.Data.SqlClient.SqlCommand
$SQLCmd.Connection = $SQLConnection

# Executing sql command
try{
    $SQLCmd.CommandText =  "IF db_id('$DatabaseName') is null CREATE DATABASE [$DatabaseName]"
    $SQLCmd.ExecuteNonQuery() | Out-Null
}catch{
    $err = $_.ExceptionMessage | Format-List -Force | Out-String
    Write-Host "Error executing command."
    Write-Host $err
}

# Changing database and getting * from Dokumenty table
try{
    $SQLConnection.ChangeDatabase($DatabaseName)
    $SQLCmd.CommandText = "SELECT * FROM dbo.Dokumenty"
    $result = $SQLCmd.ExecuteReader()
    $result
}catch{
    $err = $_.ExceptionMessage | Format-List -Force | Out-String
    Write-Host "Error executing query."
    Write-Host $err
}
