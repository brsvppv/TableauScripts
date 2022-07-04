Function Start-TableauBackupToSP {
    [CmdletBinding()]
    param (
        [Parameter()]
        $WorkDirectory = "C:\XFiles\",
        [Parameter()]
        $NewFiles = "C:\XFiles\New",
        [Parameter()]
        $InProgress = "C:\XFiles\InProgress",
        [Parameter()]
        $Completed = "C:\XFiles\Completed",
        [Parameter()]
        $SiteURL = "https://teamvisionbulgaria.sharepoint.com/sites/GM",
        [Parameter()]
        $libraryName = "BACKUP",
        [Parameter()]
        $SPOnlineUserName = "ReportMail@TeamVISIONBulgaria.onmicrosoft.com",
        [Parameter()]
        $azpswd = "\\tvbg\root\nf\Shared\!DO_NOT_DELETE!\ADM\azrmpswd.txt",
        [Parameter()]
        $fpath = "C:\!DO_NOT_DELETE",
        [Parameter()]
        $link = "https://teamvisionbulgaria.sharepoint.com/sites/GM/BACKUP/"

    )

    If (-NOT(Test-Path $WorkDirectory)) {

        New-Item -Path "$WorkDirectory" -Itemtype Directory
        New-Item -Path "$NewFiles" -Itemtype "Directory"
        New-Item -Path "$InProgress" -Itemtype "Directory"
        New-Item -Path "$Completed" -Itemtype "Directory"
        
    }

    #DateFormat TimeStamp 
    $dateAndtime = Get-Date  -UFormat "%y%m%d"
    $MailBodyDate = Get-Date -UForma "%y-%M-%d"
    $MailBodyTime = Get-Date -UForma "%H:%M"
    #Set-Lication
    Set-Location -Path "C:\"

    #Tsbak loction
    $TsBakDir = tsm configuration get -k basefilepath.backuprestore
    #Write-host "Default Backup Location: $TsBakDir" -ForegroundColor Yellow
    #ziplogs file location
    $LogZipDir = tsm configuration get -k basefilepath.log_archive
    #Write-host "Default Log Archive Location: $LogZipDir" -ForegroundColor Yellow
    #configuration file location
    $JsonExpConfigDir = tsm configuration get -k basefilepath.site_export.exports
    #Write-host "Default JSON Export Location: $JsonExpConfigDir" -ForegroundColor Yellow
    #config import location
    $JsonImpConfigDir = tsm configuration get -k basefilepath.site_import.exports
    #Write-host "Default JSON Import Location: $JsonImpConfigDir" -ForegroundColor Yellow

    #CreateTimestap Directory
    if (!(Test-Path "$NewFiles\$dateAndtime")) {New-Item -Path "$NewFiles" -Name $dateAndtime -Itemtype "Directory"}
    #BackupName
    $backupName = "$dateAndtime" + "YMD_" + "$env:COMPUTERNAME"
    Start-Sleep -Milliseconds 10

    #zip Server Logs
    tsm maintenance ziplogs -all
    Start-Sleep -Milliseconds 10
    #Cleanup Files up to 7 days
    tsm maintenance cleanup -l --log-files-retention 7
    Start-Sleep -Milliseconds 10
    #CreateTableauBackup
    tsm maintenance backup -f "$backupName" 
    Start-Sleep -Milliseconds 10
    #set Location for Export
    Set-Location -Path "$NewFiles\$dateAndtime"
    Start-Sleep -Milliseconds 10
    #ExportServerTopology
    tsm settings export -f "$backupName.json"
    Start-Sleep -Milliseconds 10

    #write-host "$TsBakDir\$backupName.tsbak"
    $exist = [System.IO.File]::Exists("$TsBakDir\$backupName." + ".tsbak")
    if ($exist -eq $false) {
        #moving the new backup ot the created directory above
        Move-Item -Path "$TsBakDir\$backupName.tsbak" -Destination "$NewFiles\$dateAndtime\" 
    }
    else {
        tsm maintenance backup -f "$backupName" 
    }
    #move the logs to the prearchive directory
    Move-Item -Path "$LogZipDir\logs.zip" -Destination "$NewFiles\$dateAndtime\" 
    Start-Sleep -Milliseconds 10
    #RenameTheZippedLogs
    Rename-Item -Path "$NewFiles\$dateAndtime\logs.zip" -NewName "$dateAndtime-logs.zip"
    Start-Sleep -Milliseconds 10
    #get file size function
    Function Format-FileSize() {
        Param ([int]$size)
        If ($size -gt 1TB) { [string]::Format("{0:0.00} TB", $size / 1TB) }
        ElseIf ($size -gt 1GB) { [string]::Format("{0:0.00} GB", $size / 1GB) }
        ElseIf ($size -gt 1MB) { [string]::Format("{0:0.00} MB", $size / 1MB) }
        ElseIf ($size -gt 1KB) { [string]::Format("{0:0.00} kB", $size / 1KB) }
        ElseIf ($size -gt 0) { [string]::Format("{0:0.00} B", $size) }
        Else { "" }
    }
    #ARCHIVE SOURCE
    $ZipSource = "$NewFiles\$dateAndtime"
    #ARCHIVE DESTINATION
    $BackupArchiveFile = "$InProgress\$backupName.zip"
    #GetFile
    $SPOnlinePassword = (Get-Content -Path $azpswd)
    Start-Sleep -Milliseconds 10
    Function UploadFileInSlice ($ctx, $libraryName, $fileName, $fileChunkSizeInMB) {
        $fileChunkSizeInMB = 9
        # Each sliced upload requires a unique ID.
        $UploadId = [GUID]::NewGuid()
        # Get the name of the file.
        $UniqueFileName = [System.IO.Path]::GetFileName($fileName)
        # Get the folder to upload into.
        $Docs = $ctx.Web.Lists.GetByTitle($libraryName)
        $ctx.Load($Docs)
        $ctx.Load($Docs.RootFolder)
        $ctx.ExecuteQuery()
        # Get the information about the folder that will hold the file.
        $ServerRelativeUrlOfRootFolder = $Docs.RootFolder.ServerRelativeUrl
        # File object.
        [Microsoft.SharePoint.Client.File] $upload
        # Calculate block size in bytes.
        $BlockSize = $fileChunkSizeInMB * 1024 * 1024
        # Get the size of the file.
        $FileSize = (Get-Item $fileName).length
        if ($FileSize -le $BlockSize) {
            # Use regular approach.
            $FileStream = New-Object IO.FileStream($fileName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
            $FileCreationInfo = New-Object Microsoft.SharePoint.Client.FileCreationInformation
            $FileCreationInfo.Overwrite = $true
            $FileCreationInfo.ContentStream = $FileStream
            $FileCreationInfo.URL = $UniqueFileName
            $Upload = $Docs.RootFolder.Files.Add($FileCreationInfo)
            $ctx.Load($Upload)
            $ctx.ExecuteQuery()
            return $Upload
        }
        else {
            # Use large file upload approach.
            $BytesUploaded = $null
            $Fs = $null
            Try {
                $Fs = [System.IO.File]::Open($fileName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
                $br = New-Object System.IO.BinaryReader($Fs)
                $buffer = New-Object System.Byte[]($BlockSize)
                $lastBuffer = $null
                $fileoffset = 0
                $totalBytesRead = 0
                $bytesRead
                $first = $true
                $last = $false
                # Read data from file system in blocks.
                while (($bytesRead = $br.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $totalBytesRead = $totalBytesRead + $bytesRead
                    # You've reached the end of the file.
                    if ($totalBytesRead -eq $FileSize) {
                        $last = $true
                        # Copy to a new buffer that has the correct size.
                        $lastBuffer = New-Object System.Byte[]($bytesRead)
                        [array]::Copy($buffer, 0, $lastBuffer, 0, $bytesRead)
                    }
                    If ($first) {
                        $ContentStream = New-Object System.IO.MemoryStream
                        # Add an empty file.
                        $fileInfo = New-Object Microsoft.SharePoint.Client.FileCreationInformation
                        $fileInfo.ContentStream = $ContentStream
                        $fileInfo.Url = $UniqueFileName
                        $fileInfo.Overwrite = $true
                        $Upload = $Docs.RootFolder.Files.Add($fileInfo)
                        $ctx.Load($Upload)
                        # Start upload by uploading the first slice.
                        $s = [System.IO.MemoryStream]::new($buffer)
                        # Call the start upload method on the first slice.
                        $BytesUploaded = $Upload.StartUpload($UploadId, $s)
                        $ctx.ExecuteQuery()
                        # fileoffset is the pointer where the next slice will be added.
                        $fileoffset = $BytesUploaded.Value
                        # You can only start the upload once.
                        $first = $false
                    }
                    Else {
                        # Get a reference to your file.
                        $Upload = $ctx.Web.GetFileByServerRelativeUrl($Docs.RootFolder.ServerRelativeUrl + [System.IO.Path]::AltDirectorySeparatorChar + $UniqueFileName);
                        If ($last) {
                            # Is this the last slice of data?
                            $s = [System.IO.MemoryStream]::new($lastBuffer)
                            # End sliced upload by calling FinishUpload.
                            $Upload = $Upload.FinishUpload($UploadId, $fileoffset, $s)
                            $ctx.ExecuteQuery()
                            Write-Host "File upload complete"
                            # Return the file object for the uploaded file.
                            return $Upload
                        }
                        else {
                            $s = [System.IO.MemoryStream]::new($buffer)
                            # Continue sliced upload.
                            $BytesUploaded = $Upload.ContinueUpload($UploadId, $fileoffset, $s)
                            $ctx.ExecuteQuery()
                            # Update fileoffset for the next slice.
                            $fileoffset = $BytesUploaded.Value
                        }
                    }
                } #// while ((bytesRead = br.Read(buffer, 0, buffer.Length)) > 0)
            }
            Catch {
                Write-Host "Error occurred"
            }
            Finally {
                if ($null -ne $Fs ) {
                    $Fs.Dispose()
                }
            }
        }
        return $null
    }
    function New-MailNotificationLocal {

        param (
            #Sender for the Report Mail
            [Parameter()]
            #reportmail@teamvisionbulgaria.onmicrosoft.com
            $sendermail = 'TableauBackup@team-vision.bg',
            #To who the mail is sended Tp(receiver)
            [Parameter()]
            $receiver = 'b.popov@team-vision.bg,p.bentchev@team-vision.bg',
            #CC who the mail is sended To(receiver)
            [Parameter()]
            $ccreceiver = 'TechSupport@TeamVISIONBulgaria.onmicrosoft.com',
            # MAIL SMTP SERVER
            [Parameter()]
            $smtpServer = "192.168.4.27",
            #Mail Subject
            [Parameter(Mandatory)]
            $MailSubjectStatus,
            #MAIL HTML BODY HEADER 
    
            [Parameter(Mandatory)]
            #MAIL HTML BODY TEXT 
            $MailBodyResult,
            [Parameter()]
            $OFS = "`r`n"
        )
        $msg = new-object Net.Mail.MailMessage 
        $smtp = new-object Net.Mail.SmtpClient($smtpServer) 
        $smtp.EnableSsl = $false 
        $msg.From = $sendermail  
        $msg.To.Add($receiver) 
        $msg.CC.Add("$ccreceiver")
        #$msg.BodyEncoding = [system.Text.Encoding]::Unicode 
        #$msg.SubjectEncoding = [system.Text.Encoding]::Unicode 
        $msg.IsBodyHTML = $true  
        $msg.Subject = "$MailSubjectStatus"
        $msg.Body = $MailBodyResult
        #$msg.Attachments.Add($att)
        $SMTP.Credentials = New-Object System.Net.NetworkCredential("$sendermail", "$pass"); 
        $smtp.Send($msg)
        $msg.Dispose()
    }
    try {
        #Create Archive
        Compress-Archive "$ZipSource\*" -CompressionLevel Optimal -Update -DestinationPath $BackupArchiveFile -ErrorAction Stop
        Start-Sleep -Milliseconds 10
        #Import Module for Encryption
        Import-Module 'C:\!DO_NOT_DELETE\TableauBackup\AESPWSModule.psm1'
        Start-Sleep -Milliseconds 10
         
        #Get File Size
        $size = Format-FileSize((Get-Item $BackupArchiveFile).length)

        #Generate Encryption Key
        $Key = New-AESKey
        Start-Sleep -Milliseconds 10

        #Start File Encryption with the generated Key
        Invoke-FileEncrypt -ToEncrypt $BackupArchiveFile -Key $Key

        Start-Sleep -Milliseconds 10
        
        #Encrypted File Name
        $EncryptedArchive = $BackupArchiveFile.Encrypted

       

        #load DLL Files
        Add-Type -Path 'C:\!DO_NOT_DELETE\Microsoft.SharePoint.Client.dll'
        Add-Type -Path 'C:\!DO_NOT_DELETE\Microsoft.SharePoint.Client.Runtime.dll'
        
        #Sharepoint Authentication
        $Context = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)
        $securePassword = ConvertTo-SecureString $SPOnlinePassword -AsPlainText -Force
        $Context.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($SPOnlineUserName, $securePassword)
        
        #Upload all files in $InProgress Directory
        foreach ($fileName in Get-ChildItem $InProgress) {
            try {
                $UpFile = UploadFileInSlice -ctx $Context -libraryName $libraryName -fileName $fileName.FullName 
                $Context.Dispose();
    
                $MailSubjectStatus = "Successful"
                $MailBodyResult = "Backup Archive of the Tableau Server has been created and uploaded.<br> The Archive contains:
                    <br> 1. Topology Configuration File (JSON) <br> 2. Tableau Logs, <br> 3. Tableau Database Backup (TSBAK), <br> 
                    The Backup is located at $link\$EncryptedArchive <br><br>
                    Backup Name: $EncryptedArchive <br> Archive Key: $Key <br>  Archive Size: $size <br> Date Created: $MailBodyDate <br>  Date Created: $MailBodyTime <br>"
                
                Remove-Item  "$InProgress\*" -Force -Recurse
            }
            catch {
                $BackupError = "Error during upload: $_"
                $MailSubjectStatus = "Failed 1"
                $MailBodyResult = "$BackupError"
                Write-Error 
            }
        }
    }
    catch {
        Write-host "Error occured: $_"
        $BackupError = "An Error has occured: $_"
        $MailSubjectStatus = "Failed 2"
        $MailBodyResult = "$BackupError"
        Write-Error 
        
    }
    Finally {
        #SetLocation Defult OS Drive
        Start-Sleep -Seconds 1
        Remove-Item  "$ZipSource\*" -Force -Recurse
        New-MailNotificationLocal -MailSubjectStatus $MailSubjectStatus -MailBodyResult $MailBodyResult
    }
    Exit
}

Start-TableauBackupToSP