Function Get-TSLastVersion() {
    #Define Web Request LInk
    $WebResponse = Invoke-WebRequest 'https://www.tableau.com/support/releases/server'
    #Get Link in the HTML for realsed version
    $ReleasedVersions = $WebResponse.Links 
    #Define Array Container for realsed version for filter
    $WebVersionString = New-Object System.Collections.Generic.List[System.Object]
    #Get each relesed version in array 
    ForEach ($version in $ReleasedVersions | Where-Object { $_.InnerText -match "Released" }  ) {

        $innerString = $version.innerText.ToString() 
        $WebVersionString.Add($innerString)
        $InfoArray = $innerString.Split(" ")

    }
    #Select the 1-st relaesed version in the array - considered as the last uploaded version
    $FirstObject = ($WebVersionString | Select-Object -First 1)
    $InfoArray = $FirstObject.Split(" ")
    $ObjectVersion = $InfoArray[1]
    $ObjectLink = $ObjectVersion.Replace("." , "-")

    #Build the version URL Download Link
    $RootURL = 'https://downloads.tableau.com/esdalt'
    $VerURL = $ObjectVersion
    $ObjectFile = "TableauServer-64bit-" + "$ObjectLink" + ".exe"
    $FileURL = ($RootURL, $VerURL, $ObjectFile ) -Join ("/")
    #If(!Test-Path $Destination)
    #Notify the user for the created Variables /version/file/Link
    write-host "Version Directory Link: $ObjectVersion" -ForegroundColor Green
    write-host "File Link: $ObjectFile" -ForegroundColor Cyan
    Write-Warning "URL BUilder Link: $FileURL"
    $UserDownloads = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
    Try{
        Start-BitsTransfer -Source $FileURL -Destination $UserDownloads -TransferType Download -Priority Foreground 
    }
    Catch{
        Write-Output $_
    }
    
}
function TimeProgress {
    $CurrentTime = $stopwatch.Elapsed
    write-host $([string]::Format("`rTime: {0:d2}:{1:d2}:{2:d2}",
            $CurrentTime.hours,
            $CurrentTime.minutes,
            $CurrentTime.seconds)) -ForegroundColor Magenta
    ## Wait a specific interval
    Start-Sleep -Seconds 1
    
}
#Bits Download Tableau Server installation exe file
Function Invoke-FileDownload {
    param(
        [Parameter()]
        [string]$global:RootURL = $global:RootURL,
        [Parameter()]
        [string]$SubUrl = $global:VerURL,
        [Parameter()]
        [string]$ObjectUrl = $global:ObjectFile,
        [Parameter()]
        [string]$DownloadDirectory = $global:FileDirectory
    )
   
    #$Key = ConvertTo-SecureString -String $Key -AsPlainText -Force
    $StartSleep = Start-Sleep -Milliseconds 100 
    if (!(Test-Path "$DownloadDirectory")) {
        Write-Host "Creating Download Directory"-ForegroundColor Green 
        New-Item -Path "$DownloadDirectory" -ItemType Directory -Force 
    }
    else {
        Write-Host "Download Directory Exist"  -ForegroundColor Green
    }
    write-host $DownloadDirectory, $global:RootURL
    $PAUSE
    $StartSleep
    $URL = ($global:RootURL, $SubUrl, $ObjectUrl ) -Join ("/")
    Write-Host "Downloading InProgress"
    $stopwatch = [system.diagnostics.stopwatch]::StartNew()
    $DownloadFile = Start-BitsTransfer -Source "$URL"`
        -Destination "$DownloadDirectory\$ObjectUrl" `
        -TransferType Download `
        -Priority Foreground `
        -Asynchronous `

    while ( Get-BitsTransfer | Where-Object { $_.JobState -eq "Transferring" -or $_.JobState -eq "Connecting" }) {
        TimeProgress  
        write-host "Job Status: " $DownloadFile.JobState ", File: $global:ObjectFile, Directory: $DownloadDirectory"
    }
    $StartSleep
    Switch ($DownloadFile.JobState) {
        "Transferred" {
            Write-Host "Downloading Finished." -ForegroundColor Green
            $DownloadFile | Complete-BitsTransfer
        }
        "Error" {  
            Write-Warning "Error Ocurred During Download"
            Write-Host "Retry" -ForegroundColor Yellow     
        }
        "Paused" {
            write-host "Paused"
        }
        "Suspended" {
        
            write-host "Suspended"
        }
        "Cancelled" {
        
            write-host "Cancelled"
        }
        Default {
            write-host $DownloadFile.JobState
        }
    }   
    $stopwatch.Stop()
}

Get-TSLastVersion
Invoke-FileDownload