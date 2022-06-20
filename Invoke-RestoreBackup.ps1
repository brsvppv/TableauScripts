function Invoke-RestoreTSBackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][Alias('FileLocation')]
        [string]$FilePath,
        [Parameter(Mandatory)][Alias('File')]
        [string]$FileName
    )
    
    Set-Location $FilePath
    $FullPath = Join-Path -Path $FilePath -ChildPath $FileName
    $DefaultTSPath = tsm configuration get -k basefilepath.backuprestore
    Copy-Item -Path $FullPath -Destination $DefaultTSPath

    Try {
        tsm maintenance restore --file $FileName
    }
    Catch {
        Write-Warning "ERROR"
        Write-Host $_
    }
}
Invoke-RestoreTSBackup 