function Invoke-RestoreTSBackup {
    [CmdletBinding()]
    param (
        [Parameter()][Alias('FileLocation')]
        [string]$FilePath,
        [Parameter()][Alias('File')]
        [string]$FileName
    )
    
    Set-Location $FilePath
    
    Try {
        tsm maintenance restore $FileName --no-config 
    }
    Catch {
        Write-Warning "ERROR"
        Write-Host $_
    }
}
Invoke-RestoreTSBackup -FilePath 'C:Temp' -FileName 'Test.tsbak'