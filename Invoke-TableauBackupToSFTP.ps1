Function Invoke-TableauBackupToSFTP {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][Alias('Destination')]
        [string]$Location,
        ### FTP DETAILS
        [Parameter(Mandatory)]$WinSCP,
        [Parameter(Mandatory)]$ServerAddress,
        [Parameter(Mandatory)]$ServerPort,
        [Parameter(Mandatory)]$FtpUser,
        [Parameter(Mandatory)]$FtpKey,
        [Parameter(Mandatory)]$SSHKey,
        [Parameter(Mandatory)]$FtpDirectory,
        $UploadStatus = $null,
        $FileTimeStamp = (Get-Date -Format 'O').Replace(':', '-').Replace('-', '.').Replace('.', '').Replace('+', ""),
        $backupName = "$FileTimeStamp" +'-' +"$env:COMPUTERNAME",
        $LogFile = $Location + 'tsbackup.log'
    )
    If (!(Test-Path $LogFile)) { New-Item -Path $LogFile -Itemtype 'File' }

    Function Invoke-WriteToLog($EventInfo) {
        $OFS = "`r`n"
        #(Get-Date -Format 'o' | ForEach-Object { $_ -replace ":", "." })
        $timestamp = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date) 
        #Set Access Varaibles
        $FileMode = [System.IO.FileMode]::Append
        $FileAccess = [System.IO.FileAccess]::Write
        $FileShare = [IO.FileShare]::Read
        #Assing File Stream Access
        $FileStream = New-Object IO.FileStream($LogFile, $FileMode, $FileAccess, $FileShare)
        #Open Writer
        $StreamWriter = New-Object System.IO.StreamWriter($FileStream)
        Write-Host $EventInfo
        $StreamWriter.WriteLine($timestamp + $OFS + $EventInfo)

        $StreamWriter.Dispose()
        $FileStream.Dispose()

        $FileStream.Close()
        $StreamWriter.Close()

    }
    Function New-TSBackup() {

        ############ Default PARAMS ##############
        $Status = $null

       
        # Temp Directory
        $DirectoryID = ([Guid]::NewGuid().ToString())
        $WorkingDirectory = [System.IO.Path]::Combine( $env:TEMP, $DirectoryID)
        # BackupName Name
        

        # Write To Log Function #


        #Create Directories & log file
        If (!(Test-Path $Location)) { New-Item -Path $Location -Itemtype 'Directory' }
       
        If (!(Test-Path $WorkingDirectory)) { 
            New-Item -Path $WorkingDirectory -Itemtype 'Directory' 
            Invoke-WriteToLog("Creating Temporary Directory $WorkingDirectory")
        }
        ### Get Default Backup Location
        $TSBAKPath = tsm configuration get -k basefilepath.backuprestore
        ####Get Default Backup Location of ziplogs:
        $LogArchivePath = tsm configuration get -k basefilepath.log_archive

        Try {
        
            ####Create Tableau Backup
            tsm maintenance backup -f "$backupName"
            Set-Location -Path "$TSBAKPath"
            #move backup to Temp Directory
            Move-Item -Path "$TSBAKPath\$backupName.tsbak" -Destination $WorkingDirectory -ErrorAction Stop
            #### Zip Server Logs
            tsm maintenance ziplogs -all
            Set-Location -Path "$LogArchivePath"
            Start-Sleep -Milliseconds 2
            #Move Logs to Temp Directory
            Move-Item -Path "$LogArchivePath\Logs.zip" -Destination $WorkingDirectory  -ErrorAction Stop
            ####Set Location for Export & ExportServerTopology #Set-Location -Path $WorkingDirectory
            Set-Location $WorkingDirectory
            tsm settings export -f "$backupName.json"
       
            Start-Sleep -Milliseconds 2
            #Rename Log file according to backupname
            Rename-Item -Path "$WorkingDirectory\logs.zip" -NewName "$backupName-logs.zip" -ErrorAction Stop
            #create final Archive with all files
            Invoke-WriteToLog("Tableau Files Backup  Successful: " + $Status)
            Compress-Archive "$WorkingDirectory\*" -CompressionLevel Optimal -Update -DestinationPath $Location\$backupName -ErrorAction Stop
            Invoke-WriteToLog("Archive Backup Created Succesfully:" + $backupName ) 
            ####Cleanup Files up to 7 days
            tsm maintenance cleanup -l --log-files-retention 7 -ErrorAction Stop
            Invoke-WriteToLog("Tableau Log Maintenance cleanup Succesfully:" + $backupName ) 
            Remove-Item  "$WorkingDirectory" -Force -Recurse

            $Status = $true
        }
        Catch [System.SystemException] {
            $Status = $false
            Write-Host ($_.Exception)
            Invoke-WriteToLog("Tableau Backup Successful: " + $Status + $OFS + $_.Exception)
        }
        finally {
        
       

        }
        $FullPath = Join-Path -Path $Location -ChildPath "$backupName.zip"
        return $FullPath
  
    }
    New-TSBackup
    Function Invoke-UploadSFTP() {

        $FilePath = Join-Path -Path $Location -ChildPath "$backupName.zip"

        if ([System.IO.File]::Exists($FilePath) -eq $true) {
            try {
                # Load WinSCP .NET assembly
                Add-Type -Path "$WinSCP\WinSCPnet.dll"

                # Set up session options
                $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
                    Protocol              = [WinSCP.Protocol]::Sftp
                    HostName              = "$ServerAddress"
                    PortNumber            = $ServerPort
                    UserName              = "$FtpUser"
                    Password              = "$FtpKey"
                    SshHostKeyFingerprint = $SSHKey
                    #GiveUpSecurityAndAcceptAnySSHHostKey = $true
    
                }
    
                $session = New-Object WinSCP.Session
                $session.ExecutablePath = "$WinSCP\WinSCP.exe"
                # Connect
                $session.Open($sessionOptions)
                # Transfer files
                $session.PutFiles("$FilePath", "$FtpDirectory").Check()
            }
            catch {             
                Invoke-WriteToLog = ($_.Exception.Message)
            }
            finally {
                $session.Dispose()
            }
        }
        else {
            Invoke-WriteToLog("File to Upload - Not Found - $FilePath")
        }
    }  
    Invoke-UploadSFTP

}
Invoke-TableauBackupToSFTP -Location "C:\Temp\" `
    -WinSCP 'C:\!DO_NOT_DELETE\WinSCP-5.17.8-Automation' `
    -ServerAddress '' `
    -ServerPort '' `
    -FtpUser '' `
    -FtpKey '' `
    -SSHKey '' `
    -FtpDirectory '/Private/*'