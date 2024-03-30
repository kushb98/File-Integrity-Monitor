Function Calculate-File-Hash($filepath) {
    $filehash = Get-FileHash -Path $filepath -Algorithm SHA512
    return $filehash
}
Function Erase-Baseline-If-Already-Exists() {
    $baselineExists = Test-Path -Path .\FIM\baseline.txt

    if ($baselineExists) {
        # Delete it
        Remove-Item -Path .\FIM\baseline.txt
    }
}

Function Erase-logFile-If-Already-Exists() {
    $logFileExists = Test-Path -Path .\FIM\logfile.txt

    if ($logFileExists) {
        # Delete it
        Remove-Item -Path .\FIM\logfile.txt
    }
}


Write-Host ""
Write-Host "What would you like to do?"
Write-Host ""
Write-Host "    A) Collect new Baseline?"
Write-Host "    B) Begin monitoring files with saved Baseline?"
Write-Host ""
$response = Read-Host -Prompt "Please enter 'A' or 'B'"
Write-Host ""

if ($response -eq "A".ToUpper()) {
    # Delete baseline.txt if it already exists
    Erase-Baseline-If-Already-Exists
    Erase-logFile-If-Already-Exists

    #Empty Log file will be created to record any changes to files
    $logFile = ".\FIM\logfile.txt"
    if (-not (Test-Path -Path $logFile)) {
        New-Item -ItemType File -Path $logFile | Out-Null
    }


    # Calculate Hash from the target files and store in baseline.txt
    # Collect all files in the target folder
    $files = Get-ChildItem -Path .\FIM\Files

    # For each file, calculate the hash, and write to baseline.txt
    foreach ($f in $files) {
        $hash = Calculate-File-Hash $f.FullName
        "$($hash.Path)|$($hash.Hash)" | Out-File -FilePath .\FIM\baseline.txt -Append
        #for baseline verification
        $baselineHash = Get-FileHash -Path .\FIM\baseline.txt -Algorithm SHA512 | Select-Object -ExpandProperty Hash
    }

    Write-Host "Baseline file has been created!" -ForegroundColor Green
    Write-Host "Log file has been created!" -ForegroundColor Green

}

elseif ($response -eq "B".ToUpper()) {

$computedHash = Get-FileHash -Path .\FIM\baseline.txt -Algorithm SHA512 | Select-Object -ExpandProperty Hash

if ($baselineHash -eq $computedHash) {
                
    
    $fileHashDictionary = @{}

    # Load file|hash from baseline.txt and store them in a dictionary
    $filePathsAndHashes = Get-Content -Path .\FIM\baseline.txt
    
    foreach ($f in $filePathsAndHashes) {
         $fileHashDictionary.add($f.Split("|")[0],$f.Split("|")[1])
    }

    # Begin (continuously) monitoring files with saved Baseline
    while ($true) {
        Start-Sleep -Seconds 10
        
        $files = Get-ChildItem -Path .\FIM\Files

        # For each file, calculate the hash, and write to baseline.txt
        foreach ($f in $files) {
            $hash = Calculate-File-Hash $f.FullName
            #"$($hash.Path)|$($hash.Hash)" | Out-File -FilePath .\baseline.txt -Append

            # Notify if a new file has been created
            if ($fileHashDictionary[$hash.Path] -eq $null) {
                # A new file has been created!
                Write-Host "$($hash.Path) has been created!" -ForegroundColor Green
                # Record this event in Log File as well
                Add-Content -Path $logFile -Value "A new file $($hash.Path) is created on $((Get-ChildItem $hash.Path).LastWriteTime)"
                
            }
            else {

                # Notify if a new file has been changed
                if ($fileHashDictionary[$hash.Path] -eq $hash.Hash) {
                    # The file has not changed
                }
                else {
                    # File file has been compromised!, notify the user
                    Write-Host "$($hash.Path) has changed!!!" -ForegroundColor Yellow
                    # Record this event in Log File as well
                    Add-Content -Path $logFile -Value "The file $($hash.Path) has been modified on $((Get-ChildItem $hash.Path).LastWriteTime)"
                }
            }
        }

        foreach ($key in $fileHashDictionary.Keys) {
            $baselineFileStillExists = Test-Path -Path $key
            if (-Not $baselineFileStillExists) {
                # One of the baseline files must have been deleted, notify the user
                Write-Host "$($key) has been deleted!" -ForegroundColor DarkRed -BackgroundColor Gray
                # Record this event in Log File as well
                Add-Content -Path $logFile -Value "The file $($hash.Path) has been deleted on $((Get-ChildItem $hash.Path).LastWriteTime)"
            }
        }
    }
}

else { 
    Write-Host "Baseline file Verification Failed! It has been Compromised!" -ForegroundColor Red -BackgroundColor White
}
}
