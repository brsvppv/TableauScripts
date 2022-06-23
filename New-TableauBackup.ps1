Function New-TSBackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Alias('Destination')]
        [string]$Location
    )
    #### Set Start Location
        Set-Location -Path "C:\"
    #### Set Format Date for naming files folders #DateFormatTimeStamp DirectroyName"
        $dateAndtime = (Get-Date  -UFormat "%y%m%d")
    ####Set Temporary Archive Location
        $TempLocation = $Location
    ####BackupName
    $backupName = "$dateAndtime" + "_" + "$env:COMPUTERNAME"
    ### Get Default Backup Location
        $backupfilepath =  tsm configuration get -k basefilepath.backuprestore
    ####Get Default Backup Location of ziplogs:
        $logarchivepath = tsm configuration get -k basefilepath.log_archive
    ####Get Default Export Location
        $jsonExportPath = tsm configuration get -k basefilepath.site_export.exports
    ####CreateTimestamp Directory
        New-Item -path "$TempLocation" -name $dateAndtime -Itemtype "directory"     
    ####Create Tableau Backup
        tsm maintenance backup -f "$backupName"      
    ####Set Location for Export & ExportServerTopology
        Set-Location -Path "$TempLocation\$dateAndtime"
        tsm settings export -f "$backupName.json"
    #### Zip Server Logs
        tsm maintenance ziplogs -all
    #####Moving the new backup ot the created directory above
        Set-Location -Path "$backupfilepath"
        Move-Item -Path "$backupfilepath\$backupName.tsbak" -Destination "$TempLocation\$dateAndtime\"
    ####move the logs to the prearchive directory
        Set-Location -Path "$logarchivepath"
        Move-Item -Path "$logarchivepath\logs.zip" -Destination "$TempLocation\$dateAndtime\"   
    ####Move-Item -Path "$jsonExportPath\$backupName.json" -Destination "$TempLocation\$dateAndtime\" 
        Set-Location "$TempLocation\$dateAndtime\"
    ####RenameTheZippedLogs
        Rename-Item -Path "$TempLocation\$dateAndtime\logs.zip" -NewName "$backupName-logs.zip"   
    ####Cleanup Files up to 7 days
        tsm maintenance cleanup -l --log-files-retention 7
}
New-TSBackup -Location "C:\Temp"