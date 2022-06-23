function New-TSBackupLocation {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$BackupFilePath,
        [Parameter()]
        [string]$LogBackupPath,
        [Parameter()]
        [string]$SitesExportPath,
        [Parameter()]
        [string]$ConfigBackuFile
    )

#Change the current file location
tsm configuration set -k basefilepath.backuprestore -v $BackupFilePath 
#"C:\TableauData\backups"

#To change the ziplogs directory:
tsm configuration set -k basefilepath.log_archive -v $LogBackupPath
#"C:\TableauData\LogArchives"

#To change the sites export directory:
tsm configuration set -k basefilepath.site_export.exports -v $SitesExportPath
#"C:\TableauData\SiteExports"

#To change the sites import directory:
tsm configuration set -k basefilepath.site_import.exports -v $ConfigBackuFile 
#"C:\TableauData\SiteImports"
}