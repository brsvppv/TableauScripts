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
Get-TSLastVersion
