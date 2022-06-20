function Invoke-RestoreTSBackup {
    [CmdletBinding()]
    param (
        [Parameter()][Alias('FileLocation')]
        [string]$FilePath,
        [Parameter()][Alias('File')]
        [string]$FileName
    )
    
    Set-Location $FilePath
    $FullPath = Join-Path -Path $FilePath -ChildPath $FileName
    
    Try {
        tsm maintenance restore -f $FullPath
    }
    Catch {
        Write-Warning "ERROR"
        Write-Host $_
    }
}
Invoke-RestoreTSBackup 