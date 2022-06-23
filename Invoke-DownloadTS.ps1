Function Invoke-DownloadTSInstall {
    Write-Host "Example" -ForegroundColor Cyan
    Write-Host "2020-3-1" -ForegroundColor Green

    $version = (Read-Host TBS Version)
    $LocalDstDir = "C:\Temp\Installer"
    $fileName = "TableauServer-64bit-$version.exe"


    $linkpart = $version -replace ("-", ".")
    $url = "https://downloads.tableau.com/esdalt/$linkpart/TableauServer-64bit-$version.exe"

    $output = "$LocalDstDir" + "\" + "$fileName"

    if (!(test-path $LocalDstDir)) {
        New-Item -ItemType Directory -Force -Path $LocalDstDir
    }

    $start_time = Get-Date

    Import-Module BitsTransfer

    Start-BitsTransfer -Source $url -Destination $output
}