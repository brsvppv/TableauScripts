Function Invoke-TSBackupSPOUpload() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][Alias('Destination')]
        [string]$Location,

        $MSCDLL = 'C:\!DO_NOT_DELETE\SPODLL\Microsoft.SharePoint.Client.dll',
        $MSCRDLL = 'C:\!DO_NOT_DELETE\SPODLL\Microsoft.SharePoint.Client.Runtime.dll',
        $MailTo = 'b.popov@team-vision.bg',
        $MailCC = 'sysadmin@team-vision.bg',
        $MailSubject = $null,
        $MailBody = $null,
        $MailBodyHeader = $null,
        $OFS = "`r`n",
        $MailDate = (Get-Date -UForma "[%y-%M-%d]"),
        $ErrorActionPreference = "Stop"
        #### Set Format Date for naming files folders #DateFormatTimeStamp DirectroyName"         
    )
    Function Invoke-WriteToLog($EventInfo) {
        $OFS = "`r`n"
        If (!(Test-Path $LogFile)) { New-Item -Path $LogFile -Itemtype 'File' }
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
    Function Format-FileSize() {
        Param ([int]$size)
        If ($size -gt 1TB) { [string]::Format("{0:0.00} TB", $size / 1TB) }
        ElseIf ($size -gt 1GB) { [string]::Format("{0:0.00} GB", $size / 1GB) }
        ElseIf ($size -gt 1MB) { [string]::Format("{0:0.00} MB", $size / 1MB) }
        ElseIf ($size -gt 1KB) { [string]::Format("{0:0.00} kB", $size / 1KB) }
        ElseIf ($size -gt 0) { [string]::Format("{0:0.00} B", $size) }
        Else { "" }
    }
    function New-MailNotification {
        param (
            #Sender for the Report Mail
            [Parameter(Mandatory)][Alias("From")]
            #reportmail@teamvisionbulgaria.onmicrosoft.com
            $SenderMail,
            #Sender Account Password
            [Parameter(Mandatory)][Alias("Password")]
            $Key,
            #To who the mail is sended Tp(receiver)
            #If Multiple To 'one@samplemail.com, two@samplemail.com'
            [Parameter(Mandatory)][Alias("receiver")]
            $TO,
            #CC who the mail is sended To(receiver)
            [Parameter()][Alias("ccreceiver")]
            $CC,
            #Mail Subject
            [Parameter(Mandatory)][Alias("Subject")]
            $mailSubject,
            #MAIL HTML BODY HEADER 
            [Parameter(Mandatory)][Alias("Header")]
            $h2mailbody,
            #MAIL HTML BODY TEXT 
            [Parameter(Mandatory)][Alias("Content")]
            $Mailbody,
            # MAIL SMTP SERVER
            [Parameter()]
            $smtpServer = "smtp.office365.com",
            [Parameter()]
            $NotificationErrorLog = "$env:LOCALAPPDATA\MailNotification\ErrorLog.txt",
            [Parameter()]
            $Stoploop = $false,
            [Parameter()]
            [int]$Retrycount = 0,
            [Parameter()]
            $OFS = "`r`n",
            $TimeStamp = (Get-Date -UFormat "%y%m%d%-%T")
        )
        Do {
            Try {
                $msg = new-object Net.Mail.MailMessage 
                $smtp = new-object Net.Mail.SmtpClient($smtpServer) 
                $smtp.EnableSsl = $true 
                $msg.From = $sendermail  
                $msg.To.Add($TO) 
    
                if ($null -ne $CC) {
                    $msg.CC.Add("$CC")
                }
                #$msg.BodyEncoding = [system.Text.Encoding]::Unicode 
                #$msg.SubjectEncoding = [system.Text.Encoding]::Unicode 
                $msg.IsBodyHTML = $true  
                $msg.Subject = "$mailSubject"
                $msg.Body = "<h2> $h2mailbody </h2> </br> 
                $mailbody $OFS"
                #$msg.Attachments.Add($att)
                $SMTP.Credentials = New-Object System.Net.NetworkCredential("$sendermail", "$key"); 
                $smtp.Send($msg)
                $msg.Dispose()
                $Stoploop = $true
            }
            Catch {
                If (!(test-path $NotificationErrorLog)) {
                    new-Item $NotificationErrorLog -Type File -Force | Out-Null
                } 
                if ($Retrycount -gt 2) {
                    Start-Sleep -Seconds 1
                    $Stoploop = $true
                }
                else {
                    Start-Sleep -Seconds 1
                    $Retrycount = $Retrycount + 1
                    Add-Content -Path $NotificationErrorLog -Value "Sending Attempt $Retrycount $OFS Sending Time: $TimeStamp $OFS Error: $_ $OFS"
                }
            }
        }
        While ($Stoploop -eq $false)
    }
    Function New-TSBackup {
        ############ Default PARAMS ##############
        $Status = $null
        $TimeStamp = (Get-Date -Format 'O').Replace(':', '-').Replace('-', '.').Replace('.', '').Replace('+', "")
        $LogFile = $Location + 'tsbackup.log'
        # Temp Directory
        $DirectoryID = ([Guid]::NewGuid().ToString())
        $WorkingDirectory = [System.IO.Path]::Combine( $env:TEMP, $DirectoryID)
        # BackupName Name
        $backupName = "$TimeStamp" + "$env:COMPUTERNAME"
        # Write To Log Function #
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

        #Create Directories & log file
        If (!(Test-Path $Location)) { New-Item -Path $WorkingDirectory -Itemtype 'Directory' }
        If (!(Test-Path $LogFile)) { New-Item -Path $LogFile -Itemtype 'File' }
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
            Rename-Item -Path "$WorkingDirectory\logs.zip" -NewName "$backupName-logs.zip"   -ErrorAction Stop
            #create final Archive with all files
            Compress-Archive "$WorkingDirectory\*" -CompressionLevel Optimal -Update -DestinationPath $Location\$backupName -ErrorAction Stop

            ####Cleanup Files up to 7 days
            tsm maintenance cleanup -l --log-files-retention 7
        
            $Status = $true
            Invoke-WriteToLog("Tableau Backup Successful: " + $Status) 
            $MailBody += "TSM Tableau Backup Successful: " + $Status
        }
        Catch [System.SystemException] {
            $Status = $false
            Write-Host ($_.Exception)
            Invoke-WriteToLog("Tableau Backup Failed: " + $Status + $OFS + $_.Exception)
            $MailBody += "Tableau Backup Failed: " + $Status + $OFS + $_.Exception
        }
        finally {    
            Invoke-WriteToLog("Archive Backup Created Succesfully:" + $backupName ) 
            Remove-Item  "$WorkingDirectory\*" -Force
            Invoke-WriteToLog("Removing Temp Files:" + $backupName ) 
            $Global:UploadFile = "$Location\$backupName.zip"
            $MailBody += "Backup Name: " + $backupName + $OFS
            $MailSubject = $MailDate + "Tableau Backup Status: " + $Status
        }
    }
    Function Invoke-SPOSliceUpload ($ctx, $libraryName, $fileName, $fileChunkSizeInMB) {
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
    Function New-SPOUpload {
        Param(
            #Sharepoint Site
            [Parameter(Mandatory)]
            $SiteURL,
            #Sharepoint Library
            [Parameter(Mandatory)]
            $LibraryName,
            #SP ACC DETAILS
            [Parameter(Mandatory)]
            $SPOnlineUserName,
            [Parameter(Mandatory)]
            $SPOnlineUserKey,
            $UploadStatus = $null
        )   
        Try {
            Add-Type -Path $MSCDLL 
            Add-Type -Path $MSCRDLL
        }
        Catch [System.SystemException] {
            $Status = $false
            Write-Host ($_.Exception)
            Invoke-WriteToLog("Tableau Backup Successful: " + $Status + $OFS + $_.Exception)
        }
        $Context = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)
        $SecurePassword = ConvertTo-SecureString $SPOnlineUserKey -AsPlainText -Force
        $Context.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($SPOnlineUserName, $SecurePassword)
       
        write-host "Uploading $Global:UploadFile"
        Try {
            $UploadProcess = Invoke-SPOSliceUpload -ctx $Context -LibraryName $LibraryName -fileName $Global:UploadFile
            #$FileContent = $fileName.Parent + $OFS
            $Context.Dispose();
            Start-Sleep -Seconds 1
            $UploadStatus = $true
        }
        Catch [System.SystemException] {
            $UploadStatus = $false
            Write-Host ($_.Exception)
            Invoke-WriteToLog("Upload Failed: " + $UploadStatus + $OFS + $_.Exception)
        }
        Finally{
            $Size = Format-FileSize((Get-Item $Global:UploadFile).length)
            $URL = ($SiteURL, $LibraryName, $Global:UploadFile ) -Join ("/") 
            $MailBody += "Backup Upload Status: $UploadStatus"
            $MailBody += "File: $Global:UploadFile"
            $MailBody += "Size: $Size"
            $MailBody += "URL: $URL"

        }
    }   
    
    New-TSBackup
    
    New-SPOUpload `
        -SPOnlineUserName '' `
        -SPOnlineUserKey '' `
        -SiteURL 'https://example.sharepoint.com/sites/Test/' `
        -LibraryName 'Files'    
            
    New-MailNotification -From 'no-reply@example.onmicrosoft.com' `
        -Password 'UsrPass' `
        -TO $MailTo `
        -CC $MailCC `
        -Subject $MailSubject `
        -Header $MailBodyHeader `
        -Content $MailBody
}

Invoke-TSBackupSPOUpload -Location "C:\Temp\"