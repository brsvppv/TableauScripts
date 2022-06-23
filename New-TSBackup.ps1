Function New-TSBackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][Alias('Destination')]
        [string]$Location
        #### Set Format Date for naming files folders #DateFormatTimeStamp DirectroyName"
        

        
    )
    ############ Default PARAMS ##############
    $Status = $null
    $TimeStamp  = (Get-Date -Format 'O').Replace(':','-').Replace('-', '.').Replace('.','').Replace('+', "")
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
        Remove-Item  "$WorkingDirectory" -Force -Recurse

        $Status = $true
        Invoke-WriteToLog("Tableau Backup Successful: " + $Status) 
    }
    Catch [System.SystemException] {
        $Status = $false
        Write-Host ($_.Exception)
        Invoke-WriteToLog("Tableau Backup Successful: " + $Status + $OFS + $_.Exception)
    }
    finally {
            
    }
}

New-TSBackup -Location "C:\Temp\"