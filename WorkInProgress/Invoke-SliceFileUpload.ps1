
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
Function Invoke-SPOUpload {
    Param(
        [Parameter(Mandatory)]
        $FilesLocation,
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
        $MSCDLL = 'C:\DO_NOT_DELETE\Microsoft.SharePoint.Client.dll',
        $MSCRDLL = 'C:\DO_NOT_DELETE\Microsoft.SharePoint.Client.Runtime.dll'
    )

    Try{
        Add-Type -Path $MSCDLL 
        Add-Type -Path $MSCRDLL
    }
    Catch{
        Write-Host $_
    } 
    $Context = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)
    $SecurePassword = ConvertTo-SecureString $SPOnlineUserKey -AsPlainText -Force
    $Context.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($SPOnlineUserName, $SecurePassword)
    
    foreach ($fileName in Get-ChildItem $FilesLocation -Recurse) {
        #$Directory = [System.IO.Path]::GetDirectoryName("$fileName")
        write-host "Uploading $fileName From $fileNam.Parent"
        $UpFile = Invoke-SPOSliceUpload -ctx $Context -LibraryName $LibraryName -fileName $fileName.FullName
        #$FileContent = $fileName.Parent + $OFS
        $Context.Dispose();
        Start-Sleep -Seconds 1
    }
}      

Invoke-SPOUpload `
-FilesLocation 'C:\TEMP\' `
-SPOnlineUserName '' `
-SPOnlineUserKey '' `
-SiteURL 'https://example.sharepoint.com/sites/test/' `
-LibraryName 'Documents' 