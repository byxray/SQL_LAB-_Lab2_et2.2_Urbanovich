$Login = "Sa"
$Creds = Get-Credential -UserName $Login -Message "Enter user password"

$Login = "Administrator"
$Creds2 = Get-Credential -UserName $Login -Message "Enter user password"


###############################################################################

$Logfile = "C:\$(gc env:computername).log"

Function LogWrite
{
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
   Write-Host $logstring -ForegroundColor White -BackgroundColor DarkGreen
}


###############################################################################

################# log
$date = Get-Date
LogWrite -logstring "Start time script $($date)" 
#####################

Invoke-Command -ArgumentList $arrPath -ScriptBlock {

    Get-PhysicalDisk | select -Property FriendlyName,BusType,HealthStatus,@{Label="Total Size";Expression={$_.Size / 1gb -as [int] }},MediaType |`
    ConvertTo-Csv -NoTypeInformation| Set-Content -path C:\PhysicalDisk.csv -Force

} -ComputerName 192.168.1.1 -Credential $Creds2


try {

Invoke-Sqlcmd -ServerInstance 192.168.1.1 -Credential $Creds -Query @'

CREATE DATABASE PCDRIVE
ON PRIMARY
  ( NAME='PCDRIVE',
    FILENAME=
       'F:\Data\PCDRIVE.mdf',
    SIZE=50MB,
    FILEGROWTH=5MB)
LOG ON
  ( NAME='PCDRIVE_log',
    FILENAME =
       'F:\Logs\PCDRIVE_log.ldf',
    SIZE=5MB,
    FILEGROWTH=1MB);

'@
 
LogWrite -logstring "Created DB - 'PCDRIVE'" 

} catch {

Write-Host "caught a system exception (CREATE DATABASE PCDRIVE)" -ForegroundColor White -BackgroundColor Red | Out-File C:\log.txt -Append

}


Invoke-Command -ArgumentList $arrPath -ScriptBlock {

    $l = Get-Item F:\Data\PCDRIVE.mdf
    Write-Host "Size of file 'PCDRIVE.mdf' before" $l.Length

} -ComputerName 192.168.1.1 -Credential $Creds2


try {

Invoke-Sqlcmd -ServerInstance 192.168.1.1 -Credential $Creds -Query @'

CREATE TABLE PCDRIVE.dbo.PhysicalDisk_Info   
(  
    FriendlyName varchar(50) NOT NULL,   
    BusType varchar(50) NOT NULL,
	HealthStatus varchar(50) NOT NULL, 	
    Size varchar(50) NOT NULL,
	MediaType varchar(50) NOT NULL, 	
);

'@

LogWrite -logstring "Created Table - 'PCDRIVE'" 

} catch {

Write-Host "caught a system exception (CREATE TABLE PCDRIVE)" -ForegroundColor White -BackgroundColor Red | Out-File C:\log.txt -Append

}


Invoke-Sqlcmd -ServerInstance 192.168.1.1 -Credential $Creds -Query @'

USE PCDRIVE;  
GO  
SELECT SUM(unallocated_extent_page_count) AS [free_pages],   
(SUM(unallocated_extent_page_count)*1.0/128) AS [free_space_in_MB]  
FROM sys.dm_db_file_space_usage;

'@ | ForEach-Object {

Write-Host "--------------------------------------------"
Write-Host "free pages before:" $_.free_pages
Write-Host "free space before:" $_.free_space_in_MB "MB"
Write-Host "--------------------------------------------"

}

try {

Invoke-Sqlcmd -ServerInstance 192.168.1.1 -Credential $Creds -Query @'

BULK
INSERT PCDRIVE.dbo.PhysicalDisk_Info
FROM 'C:\PhysicalDisk.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
)
GO
--Check the content of the table.
SELECT REPLACE(FriendlyName,'"','') FriendlyName,
REPLACE([BusType],'"','') [BusType],
REPLACE([HealthStatus],'"','') [HealthStatus],
REPLACE([Size],'"','') [Size],
REPLACE([MediaType],'"','') [MediaType]
 
FROM PCDRIVE.dbo.PhysicalDisk_Info
GO

'@

LogWrite -logstring "Filling the table - 'PCDRIVE'"

} catch {

Write-Host "caught a system exception (INSERT PCDRIVE)" -ForegroundColor White -BackgroundColor Red | Out-File C:\log.txt -Append

}

Invoke-Command -ArgumentList $arrPath -ScriptBlock {

    $l = Get-Item F:\Data\PCDRIVE.mdf
    write-host "Size of file 'PCDRIVE.mdf' after" $l.Length

} -ComputerName 192.168.1.1 -Credential $Creds2


Invoke-Sqlcmd -ServerInstance 192.168.1.1 -Credential $Creds -Query @'

USE PCDRIVE;  
GO  
SELECT SUM(unallocated_extent_page_count) AS [free_pages],   
(SUM(unallocated_extent_page_count)*1.0/128) AS [free_space_in_MB]  
FROM sys.dm_db_file_space_usage;

'@ | ForEach-Object {

Write-Host "--------------------------------------------"
Write-Host "free pages after:" $_.free_pages
Write-Host "free space after:" $_.free_space_in_MB "MB"
Write-Host "--------------------------------------------"

}

################# log
$date = Get-Date
LogWrite -logstring "Finish time script $($date)" 
#####################











