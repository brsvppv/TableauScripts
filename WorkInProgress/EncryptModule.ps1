function New-AESKey() {
    Param(
        [Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $true)]
        [Int]$KeySize = 256
    )
    try {
        $AESProvider = New-Object "System.Security.Cryptography.AesManaged"
        $AESProvider.KeySize = $KeySize
        $AESProvider.GenerateKey()
        return [System.Convert]::ToBase64String($AESProvider.Key)
    }
    catch {
        Write-Error $_
    }
    $Key = New-AESKey 
    Return $Key    
}
function Get-StringHash {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $StringToHash
    )
        
    # Crete new string builder
    [System.Text.StringBuilder]$hashString = [System.Text.StringBuilder]::new()
        
    # Get bytes
    [byte[]]$hashText = [System.Text.Encoding]::UTF8.GetBytes($StringToHash)
        
    # Instantiate new object instance
    [System.Security.Cryptography.SHA256Managed]$textHasher = New-Object -TypeName System.Security.Cryptography.SHA256Managed
        
    [array]$hashByteArray = $textHasher.ComputeHash($hashText)
        
    foreach ($byte in $hashByteArray) {
        # Append value
        [void]($hashString.Append($byte.ToString()))
    }
        
    return $hashString.ToString()
}
function Get-StringCheckSum{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $StringToCheck
    )
    
    # Instantiate required objects
    $md5Object = [System.Security.Cryptography.SHA256]::Create()
    $encodingObject = [System.Text.UTF8Encoding]::UTF8
    
    return [System.BitConverter]::ToString($md5Object.ComputeHash($encodingObject.GetBytes($StringToCheck)))
}
function Invoke-ScriptDecryption{
	[OutputType([string])]
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]
		$EncryptedString,
		[ValidateNotNullOrEmpty()]
		[string]
		$EncryptKey = $env:Computername,
		[ValidateNotNullOrEmpty()]
		[string]
		$EncryptSalt = $env:Computername,
		[ValidateNotNullOrEmpty()]
		[string]
		$IntersectingVector = 'Q!L@2QTCYgsG'
	)
	
	# Instantiate empty return value
	[string]$DecryptedString = $null
	
	# Regex to check if string is in the correct format
	[regex]$base64RegEx = '^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{2}==)?$'
	
	# Instantiate COM Object for RijndaelManaged Cryptography 
	[System.Security.Cryptography.RijndaelManaged]$encryptionObject = New-Object System.Security.Cryptography.RijndaelManaged
	
	# If the value in the Encrypted is a string, convert it to Base64
	if ($EncryptedString -is [string])
	{
		# Check string is in correct format
		if ($EncryptedString -match $base64RegEx)
		{
			[byte[]]$encryptedStringByte = [Convert]::FromBase64String($EncryptedString)
		}
		else
		{
			Write-Warning -Message 'String is not base64 encoded!'
			
			return
		}
	}
	else
	{
		Write-Warning 'Input is not a string!'
		
		return
	}
	
	# Convert Salt and Passphrase to UTF8 Bytes array
	[System.Byte[]]$byteEncryptSalt = [Text.Encoding]::UTF8.GetBytes($EncryptSalt)
	[System.Byte[]]$bytePassPhrase = [Text.Encoding]::UTF8.GetBytes($EncryptKey)
	
	# Create the Encryption Key using the passphrase, salt and SHA1 algorithm at 256 bits
	$encryptionObject.Key = (New-Object Security.Cryptography.PasswordDeriveBytes $bytePassPhrase,
										$byteEncryptSalt,
										'SHA',
										5).GetBytes(32) # 256/8 - 32byts
	
	# Create the Intersecting Vector Cryptology Hash with the init 
	$encryptionObject.IV = (New-Object Security.Cryptography.SHA1Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($IntersectingVector))[0 .. 15]
	
	# Create new decryptor Key and IV
	[System.Security.Cryptography.RijndaelManagedTransform]$objectDecryptor = $encryptionObject.CreateDecryptor()
	
	# Create a New memory stream with the encrypted value
	[System.IO.MemoryStream]$memoryStream = New-Object IO.MemoryStream  @( ,$encryptedStringByte)
	
	# Read the new memory stream and read it in the cryptology stream
	[System.Security.Cryptography.CryptoStream]$cryptoStream = New-Object Security.Cryptography.CryptoStream $memoryStream, $objectDecryptor, 'Read'
	
	# Read the new decrypted stream 
	[System.IO.StreamReader]$streamReader = New-Object IO.StreamReader $cryptoStream
	
	try
	{
		# Return from the function the stream 
		[string]$DecryptedString = $streamReader.ReadToEnd()
		
		# Stop the stream     
		$streamReader.Close()
		
		# Stop the crypto stream 
		$cryptoStream.Close()
		
		# Stop the memory stream 
		$memoryStream.Close()
		
		# Clears all crypto objects 
		$encryptionObject.Clear()
		
		# Return decrypted string
		return $DecryptedString
	}
	
	catch
	{
		# Save exception
		[string]$reportedException = $Error[0].Exception.Message
		
		Write-Warning -Message "String $EncryptedString could not be decripted - Use the -Verbose paramter for more details"
		
		# Check we have an exception message
		if ([string]::IsNullOrEmpty($reportedException) -eq $false)
		{
			Write-Verbose -Message $reportedException
		}
		else
		{
			Write-Verbose -Message 'No inner exception reported by Disconnect-AzureAD cmdlet'
		}
		
		return [string]::Empty
	}	
}
function Invoke-ScriptEncryption{
	[OutputType([string])]
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[Alias('string')]
		[string]
		$StringToEncrypt,
		[ValidateNotNullOrEmpty()]
		[Alias('PassPhrase', 'EncryptionPassPhrase')]
		[String]
		$EncryptKey,
		[ValidateNotNullOrEmpty()]
		[Alias('Salt', 'SaltValue')]
		[string]
		$EncryptSalt,
		[ValidateNotNullOrEmpty()]
		[Alias('Vector')]
		[string]
		$IntersectingVector = 'Q!L@2QTCYgsG'
	)
	
	# Instantiate empty return value
	[string]$EncryptedString = $null
	
	# Instantiate COM Object for RijndaelManaged Cryptography
	[System.Security.Cryptography.RijndaelManaged]$encryptionObject = New-Object System.Security.Cryptography.RijndaelManaged
	
	# Check if we have a passphrase
	if ([string]::IsNullOrEmpty($EncryptKey) -eq $true)
	{
		# Use hostname
		$EncryptKey = $env:Computername
	}
	
	# Check if we have a salt value
	if ([string]::IsNullOrEmpty($EncryptSalt) -eq $true)
	{
		# Use hostname
		$EncryptSalt = $env:Computername
	}
	
	# Convert Salt and Passphrase to UTF8 Bytes array
	[System.Byte[]]$byteEncryptSalt = [Text.Encoding]::UTF8.GetBytes($EncryptSalt)
	[System.Byte[]]$bytePassPhrase = [Text.Encoding]::UTF8.GetBytes($EncryptKey)
	
	# Create the Encryption Key using the passphrase, salt and SHA1 algorithm at 256 bits 
	$encryptionObject.Key = (New-Object Security.Cryptography.PasswordDeriveBytes $bytePassPhrase,
										$byteEncryptSalt,
										'SHA1',
										5).GetBytes(32) # 256/8 - 32bytes
	
	# Create the Intersecting Vector (IV) Cryptology Hash with the init value
	$paramNewObject = @{
		TypeName = 'Security.Cryptography.SHA1Managed'
	}
	$encryptionObject.IV = (New-Object @paramNewObject).ComputeHash([Text.Encoding]::UTF8.GetBytes($IntersectingVector))[0 .. 15]
	
	# Starts the New Encryption using the Key and IV
	$encryptorObject = $encryptionObject.CreateEncryptor()
	
	# Creates a MemoryStream for encryption
	[System.IO.MemoryStream]$memoryStream = New-Object IO.MemoryStream
	
	# Creates the new Cryptology Stream --> Outputs to $MS or Memory Stream 
	[System.Security.Cryptography.CryptoStream]$cryptoStream = New-Object Security.Cryptography.CryptoStream $memoryStream, $encryptorObject, 'Write'
	
	# Starts the new Cryptology Stream
	$cryptoStreamWriter = New-Object IO.StreamWriter $cryptoStream
	
	# Writes the string in the Cryptology Stream 
	$cryptoStreamWriter.Write($StringToEncrypt)
	
	# Stops the stream writer 
	$cryptoStreamWriter.Close()
	
	# Stops the Cryptology Stream 
	$cryptoStream.Close()
	
	# Stops writing to Memory 
	$memoryStream.Close()
	
	# Clears the IV and HASH from memory to prevent memory read attacks 
	$encryptionObject.Clear()
	
	# Takes the MemoryStream and puts it to an array 
	[byte[]]$result = $memoryStream.ToArray()
	
	# Converts the array from Base 64 to a string and returns 
	$EncryptedString = $([Convert]::ToBase64String($result))
	
	# Return value
	return $EncryptedString
}
Function Invoke-FileDecrypt {
    Param(
        [CmdletBinding()]
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$FileToDecrypt,
        [Parameter(Mandatory)]
        [String]$Key
    )
 
    #Load 
    try {
        [System.Reflection.Assembly]::LoadWithPartialName('System.Security.Cryptography')
    }
    catch {
        Write-Error 'Assembly Not Loaded.'
        Return
    }

    #Configure AES
    try {
        $EncryptionKey = [System.Convert]::FromBase64String($Key)
        $KeySize = $EncryptionKey.Length * 8
        $AesCryptoService = New-Object 'System.Security.Cryptography.AesManaged'
        $AesCryptoService.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $AesCryptoService.BlockSize = 128
        $AesCryptoService.KeySize = $KeySize
        $AesCryptoService.Key = $EncryptionKey
    }
    catch {
        Write-Error 'Unable to configure AES, verify your key.'
        Return
    }

    Write-Verbose "DeEncryping $($FileToDecrypt.Count) File(s) with the $KeySize-bit key $Key"

    # successfully decrypted 
    $DecryptedFiles = @()
    $FailedToDecryptFiles = @()

    foreach ($File in $FileToDecrypt) {

        try {
            $StreamReader = New-Object System.IO.FileStream($File.FullName, [System.IO.FileMode]::Open)
        }
        catch {
            Write-Error "Unable to open $($File.FullName) for reading."
            Continue
        }
    
        #Create destination file
        $ProcessFile = "$($File.FullName).Decrypted"
        try {
            $StreamWriter = New-Object System.IO.FileStream($ProcessFile, [System.IO.FileMode]::Create)
        }
        catch {
            Write-Error "Unable to open $ProcessFile for writing."
            $StreamReader.Close()
            $StreamWriter.Close()
            Remove-Item $ProcessFile -Force
            Continue
        }

        #Get IV
        try {
            [Byte[]]$LenIV = New-Object Byte[] 4
            $StreamReader.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
            $StreamReader.Read($LenIV, 0, 3) | Out-Null
            [Int]$LIV = [System.BitConverter]::ToInt32($LenIV, 0)
            [Byte[]]$IV = New-Object Byte[] $LIV
            $StreamReader.Seek(4, [System.IO.SeekOrigin]::Begin) | Out-Null
            $StreamReader.Read($IV, 0, $LIV) | Out-Null
            $AesCryptoService.IV = $IV
        }
        catch {
            Write-Warning "Unable to read IV from $($File.FullName), verify this file was made using the included Encrypt-File function."
            $StreamReader.Close()
            $StreamWriter.Close()
            Remove-Item $ProcessFile -Force
            $FailedToDecryptFiles += $File
            Continue
        }

        Write-Verbose "Decrypting $($File.FullName) with an IV of $([System.Convert]::ToBase64String($AesCryptoService.IV))"

        #Decrypt
        try {
            $Transform = $AesCryptoService.CreateDecryptor()
            [Int]$Count = 0
            [Int]$BlockSizeBytes = $AesCryptoService.BlockSize / 8
            [Byte[]]$Data = New-Object Byte[] $BlockSizeBytes
            $CryptoStream = New-Object System.Security.Cryptography.CryptoStream($StreamWriter, $Transform, [System.Security.Cryptography.CryptoStreamMode]::Write)
            Do {
                $Count = $StreamReader.Read($Data, 0, $BlockSizeBytes)
                $CryptoStream.Write($Data, 0, $Count)
            }
            While ($Count -gt 0)

            $CryptoStream.FlushFinalBlock()
            $CryptoStream.Close()
            $StreamWriter.Close()
            $StreamReader.Close()

            #Delete encrypted file
            Remove-Item $File.FullName
            Write-Verbose "Successfully decrypted $($File.FullName)"
            $DecryptedFiles += $ProcessFile
        }
        catch {
            Write-Error "Failed to decrypt $($File.FullName)."
            $CryptoStream.Close()
            $StreamWriter.Close()
            $StreamReader.Close()
            Remove-Item $ProcessFile
            $FailedToDecryptFiles += $File
        }        
    }

    $Result = New-Object -TypeName PSObject
    $Result | Add-Member -MemberType NoteProperty -Name Computer -Value $env:COMPUTERNAME
    $Result | Add-Member -MemberType NoteProperty -Name AESKey -Value $Key
    $Result | Add-Member -MemberType NoteProperty -Name FilesDecryptedwAESKey -Value $DecryptedFiles
    $Result | Add-Member -MemberType NoteProperty -Name FilesFailedToDecrypt -Value $FailedToDecryptFiles
    return $Result
}
Function Invoke-FileEncrypt {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$ToEncrypt,
        [Parameter(Mandatory)]
        [String]$Key
        #[Parameter()]
        #[String]$Suffix
    )
    #Load dependencies
    Try {
        [System.Reflection.Assembly]::LoadWithPartialName('System.Security.Cryptography')
    }
    Catch {
        Write-Error 'Assembly Not Loaded.'
        Return
    }
    #Configure AES
    Try {

        $EncryptionKey = [System.Convert]::FromBase64String($Key)
        $KeySize = $EncryptionKey.Length * 8
        $AesCryptoService = New-Object 'System.Security.Cryptography.AESManaged'
        $AesCryptoService.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $AesCryptoService.BlockSize = 128
        $AesCryptoService.KeySize = $KeySize
        $AesCryptoService.Key = $EncryptionKey
    }
    Catch {

        Write-Warning "Could Not Configure AES, verify your key."
        Return

    }
    Write-Verbose "Processing $($ToEncrypt.Count) with the $KeySize-bit Key: $Key"
    #Successfully encrypted.
    $EncryptedFiles = @()

    Foreach ($File in $ToEncrypt) {
        #Open file
        Try {
            $StreamReader = New-Object System.IO.FileStream($File.FullName, [System.IO.FileMode]::Open)
        }
        Catch {
            Write-Error "Failed To Open $($File.FullName)."
            Continue
        }
        #Create File for Processing
        $ProcessFile = "$($File.FullName).Encrypted"
        Try {
            $StreamWriter = New-Object System.IO.FileStream($ProcessFile, [System.IO.FileMode]::Create)
        }
        Catch {
            Write-Error "Unable to open $ProcessFile for writing."
            $StreamReader.Close()
            Continue
        }
        #length & IV to encrypt
        $AesCryptoService.GenerateIV()
        $StreamWriter.Write([System.BitConverter]::GetBytes($AesCryptoService.IV.Length), 0, 4)
        $StreamWriter.Write($AesCryptoService.IV, 0, $AesCryptoService.IV.Length)

        Write-Verbose "Encrypting $($File.FullName) with an IV of $([System.Convert]::ToBase64String($AesCryptoService.IV))"

        #Encrypt file
        Try {
            $Transform = $AesCryptoService.CreateEncryptor()
            $CryptoStream = New-Object System.Security.Cryptography.CryptoStream($StreamWriter, $Transform, [System.Security.Cryptography.CryptoStreamMode]::Write)
            [Int]$Count = 0
            [Int]$BlockSizeBytes = $AesCryptoService.BlockSize / 8
            [Byte[]]$Data = New-Object Byte[] $BlockSizeBytes
            Do {
                $Count = $StreamReader.Read($Data, 0, $BlockSizeBytes)
                $CryptoStream.Write($Data, 0, $Count)
            }
            While ($Count -gt 0)
    
            #Close open files
            $CryptoStream.FlushFinalBlock()
            $CryptoStream.Close()
            $StreamReader.Close()
            $StreamWriter.Close()

            #Delete unencrypted file
            Remove-Item $File.FullName
            Write-Verbose "Encrypted $($File.FullName)"
            $EncryptedFiles += $ProcessFile
        }
        Catch {
            Write-Error "Encryption Failed: $($File.FullName)."
            $CryptoStream.Close()
            $StreamWriter.Close()
            $StreamReader.Close()
            Remove-Item $ProcessFile
        }
    }

    $Result = New-Object -TypeName PSObject
    $Result | Add-Member -MemberType NoteProperty -Name Computer -Value $env:COMPUTERNAME
    $Result | Add-Member -MemberType NoteProperty -Name AESKey -Value $Key
    $Result | Add-Member -MemberType NoteProperty -Name FilesEncryptedwAESKey -Value $EncryptedFiles
    return $Result

}
Function Rename-Decrpted{
    [CmdletBinding()]
    param (
        [Parameter()]
	[string]$DecryptedFile
    )
    Get-ChildItem $DecryptedFile | Rename-item -NewName { $_.Name.SubString(0,$_.Name.Length-19)} 
}