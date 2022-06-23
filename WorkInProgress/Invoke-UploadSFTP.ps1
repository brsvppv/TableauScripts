Function Invoke-UploadSFTP {
    [CmdletBinding()]
    param (
        ### FTP DETAILS
        [Parameter(Mandatory)]$WinSCP,
        [Parameter(Mandatory)]$ServerAddress,
        [Parameter(Mandatory)]$ServerPort,
        [Parameter(Mandatory)]$FtpUser,
        [Parameter(Mandatory)]$FtpKey,
        [Parameter(Mandatory)]$SSHKey,
        [Parameter(Mandatory)]$File,
        [Parameter(Mandatory)]$ftpDir,
        [Parameter()]$UploadStatus = $null
    )   
    # Load WinSCP .NET assembly
    Add-Type -Path "$pathWinSCP\WinSCPnet.dll"
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
    $session.ExecutablePath = "$pathWinSCP\WinSCP.exe"

    Try {
        # Connect
        $session.Open($sessionOptions)

        # Transfer files
        $session.PutFiles("$fileToUpload", "$ftpDir").Check() | Wait-Process -Verbose

        $UploadStatus = $true
        $StatusMSG = "Upload has been Succesfull"
    }
    catch{
        $StatusMSG = "Upload Failed: $_.Exception.Message"
        $UploadStatus = $false
    }
    finally {
        $session.Dispose()
        Write-Host $UploadStatus
        write-host $StatusMSG
    }
}
Invoke-UploadSFTP