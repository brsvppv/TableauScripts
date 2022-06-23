Function Invoke-TableauBackupToSFTP {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]$TempLocation= "C:\Temp" ,
        [Parameter()]
        [String]$ParameterName,
        [Parameter()]
        [String]$ParameterName,
        [Parameter()]
        [String]$Identifer = [Guid]::NewGuid().ToString(),
        [Parameter()]
        [String]$TimeStamp = (Get-Date  -UFormat "%y%m%d"),
        ### FTP DETAILS
        $WinSCP = "C:\!DO_NOT_DELETE\WinSCP-5.17.8-Automation",
        $ServerAddress = "",
        $ServerPort = 7104,
        $FtpUser = "",
        $UserPassword = "",
        $SshKey = "",
        $FileToUpload = "$dst\$backupName.7z",
        $FtpDirectory = "/Private/*",
        ####### Mail Params ########
        $MailTo = "admin@team-vision.bg",
        $MailFrom = "tablaubackup@team-vision.bg",
        $SMTP = "192.168.4.27"
        
    )
    #new row
    $OFS = "`r`n"
    #backup status bool
    $stateBackup = $true
    
    ####BackupName File Name
    $backupName = "$dateAndtime" + "_" + "$env:COMPUTERNAME"

    #######Mail Details
    $MailBodyDate = Get-Date -UForma "%y-%m-%d"
    $MailBodyTime = Get-Date -UForma "%H:%M"

    # Set Start Location
    Set-Location -Path "C:\"

    ###get backup file location
    $backupfilepath =  tsm configuration get -k basefilepath.backuprestore

    ####get ziplogs location:
    $logarchivepath = tsm configuration get -k basefilepath.log_archive
    
    ####get export location.
    $jsonExportPath = tsm configuration get -k basefilepath.site_export.exports

    ####CreateTimestamp Directory
    New-Item -path "$TempLocation" -name $dateAndtime -Itemtype "directory" 

    ####createTableauBackup
    tsm maintenance backup -f "$backupName" 

    ####set Location for Export & ExportServerTopology
    Set-Location -Path "$TempLocation\$dateAndtime"
    tsm settings export -f "$backupName.json"

    ####zip Server Logs
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

    #new row"
    $OFS = "`r`n"
    #ARCHIVE SOURCE

    # Load WinSCP .NET assembly
    Add-Type -Path "$WinSCP\WinSCPnet.dll"

    # Set up session options
    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol = [WinSCP.Protocol]::Sftp
        HostName = "$ServerAddress"
        PortNumber = $ServerPort
        UserName = "$FtpUser"
        Password = "$UserPassword"
        SshHostKeyFingerprint = $SshKey
        #GiveUpSecurityAndAcceptAnySSHHostKey = $true

    }

    $session = New-Object WinSCP.Session
    $session.ExecutablePath = "$WinSCP\WinSCP.exe"

    try
    {
        # Connect
        $session.Open($sessionOptions)

        # Transfer files
        $session.PutFiles("$FileToUpload", "$FtpDirectory").Check()
    }
    finally
    {
        $session.Dispose()
    }
    }
    catch
    {
        $ErrorMsg = $_.Exception.Message
        $stateBackup = $false
    }

    if($stateBackup -eq $false ){
                $subjectMessage = "Tableau Backup  Failed"
                $BodyMessage = "An Error occured during the Backup "
    }
    else  {
                $subjectMessage = "Tableau Backup Successfull"
                $BodyMessage = "Backup has been successfull"
    }

      foreach ($user in $MailTo) { 
                $SMTPServer = "$SMTP" #set the SMTP server
                $SMTP = New-Object Net.Mail.SMTPClient($SMTPServer) 
                $msg = New-Object Net.Mail.MailMessage 
                $msg.To.Add($user) 
                $msg.From = "$MailFrom" # set the user name from which email should send
                $msg.Subject = "$subjectMessage"
                $msg.IsBodyHTML = $true 
                $msg.Body = "
                    Status: $BodyMessage <br>
                    HostName: $env:COMPUTERNAME <br>
                    Backup Name: $backupName <br>
                    ArchivePswd: $archivePassword <br>
                    Date Created: $MailBodyDate <br>
                    Date Created: $MailBodyTime <br>
                    Additonal Info: $ErrorMsg <br>"
                $msg.Attachments.Add("$bkpDetailsFile")
                $SMTP.Send($msg)
            }
    #Remove-Item  "$src" -Force -Recurse
}
Invoke-TableauBackupToSFTP