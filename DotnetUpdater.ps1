<#
.SYNOPSIS
    Downloads the .NET 9.0 release metadata, determines the latest ASP.NET Core Runtime version,
    downloads the corresponding hosting bundle installer, silently installs it, and logs
    detailed verbose output including pre- and post-installation .NET runtime versions.
.DESCRIPTION
    This script:
      - Checks installed .NET runtimes before installation.
      - Creates directories (if needed) for logs and downloads.
      - Starts a transcript log file in C:\DotnetUpdater\logs with a timestamp.
      - Downloads the JSON metadata from:
        https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/9.0/releases.json
      - Parses the JSON via ConvertFrom-Json and determines the latest ASP.NET Core Runtime version.
      - Constructs the download URL using that version:
        https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/<version>/dotnet-hosting-<version>-win.exe
      - Downloads the installer to C:\DotnetUpdater\downloads.
      - Silently installs the downloaded file.
      - Checks installed .NET runtimes after installation.
      - Logs all operations verbosely.
.NOTES
    Run this script with the -Verbose flag to see detailed console output.
    Example: .\DotnetUpdater.ps1 -Verbose
#>

# Set error action to stop on errors.
$ErrorActionPreference = "Stop"

# Define directories.
$logDir = "C:\DotnetUpdater\logs"
$downloadDir = "C:\DotnetUpdater\downloads"

# Ensure the log directory exists.
if (!(Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory | Out-Null
    Write-Verbose "Created log directory: $logDir"
} else {
    Write-Verbose "Log directory exists: $logDir"
}

# Ensure the download directory exists.
if (!(Test-Path $downloadDir)) {
    New-Item -Path $downloadDir -ItemType Directory | Out-Null
    Write-Verbose "Created download directory: $downloadDir"
} else {
    Write-Verbose "Download directory exists: $downloadDir"
}

# Create a timestamped log file and start transcript logging.
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $logDir ("Log_$timestamp.txt")
Write-Verbose "Starting transcript logging to $logFile"
Start-Transcript -Path $logFile -Append

# Function: Check installed .NET runtimes using dotnet CLI.
function Get-DotNetRuntimes {
    Write-Verbose "Retrieving installed .NET runtimes..."
    try {
        $runtimes = & dotnet --list-runtimes 2>&1
        return $runtimes
    }
    catch {
        Write-Warning "Failed to get .NET runtimes. The 'dotnet' command may not be available."
        return $null
    }
}

try {
    Write-Verbose "=== Pre-Installation .NET Runtime Check ==="
    $dotnetRuntimesBefore = Get-DotNetRuntimes
    if ($dotnetRuntimesBefore) {
        Write-Output "Installed .NET runtimes BEFORE installation:"
        Write-Output $dotnetRuntimesBefore
    }
    else {
        Write-Output "No .NET runtimes found using the dotnet CLI BEFORE installation."
    }

    # URL to the JSON file containing release metadata.
    $metadataUrl = "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/9.0/releases.json"
    Write-Verbose "Downloading release metadata from $metadataUrl"
    $response = Invoke-WebRequest -Uri $metadataUrl -UseBasicParsing
    Write-Verbose "Download successful. Parsing JSON content."

    # Parse JSON content.
    $data = $response.Content | ConvertFrom-Json

    # Initialize variables for tracking the latest ASP.NET Core Runtime version.
    [Version]$latestAspNetCoreRuntimeVersion = $null
    $latestRelease = $null

    # Iterate over releases.
    foreach ($release in $data.releases) {
        if ($release.'aspnetcore-runtime' -and $release.'aspnetcore-runtime'.version) {
            Write-Verbose "Found ASP.NET Core Runtime version $($release.'aspnetcore-runtime'.version) for release $($release.'release-version')"
            try {
                $currentVersion = [Version]$release.'aspnetcore-runtime'.version
            }
            catch {
                Write-Warning "Skipping release because version '$($release.'aspnetcore-runtime'.version)' could not be parsed."
                continue
            }
            if (-not $latestAspNetCoreRuntimeVersion -or $currentVersion -gt $latestAspNetCoreRuntimeVersion) {
                $latestAspNetCoreRuntimeVersion = $currentVersion
                $latestRelease = $release
                Write-Verbose "Updated latest ASP.NET Core Runtime version to $latestAspNetCoreRuntimeVersion"
            }
        }
        else {
            Write-Verbose "Release $($release.'release-version') does not include ASP.NET Core Runtime version."
        }
    }

    # Proceed if a valid version was found.
    if ($latestAspNetCoreRuntimeVersion) {
        Write-Output "Latest ASP.NET Core Runtime version: $latestAspNetCoreRuntimeVersion"
        Write-Verbose "Associated release version: $($latestRelease.'release-version')"

        # Construct the download URL.
        $versionStr = $latestAspNetCoreRuntimeVersion.ToString()
        $downloadBase = "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime"
        $downloadUrl = "$downloadBase/$versionStr/dotnet-hosting-$versionStr-win.exe"
        Write-Verbose "Constructed download URL: $downloadUrl"

        # Define destination file path.
        $destinationPath = Join-Path $downloadDir "dotnet-hosting-$versionStr-win.exe"
        Write-Verbose "Downloading the installer to $destinationPath"

        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $destinationPath -UseBasicParsing
            Write-Output "Download complete. File saved as $destinationPath"
        }
        catch {
            Write-Error "Failed to download installer from $downloadUrl. Error details: $_"
            throw $_
        }

        # Silently install the downloaded file.
        # (Assuming the installer supports silent install via the /quiet parameter)
        Write-Verbose "Starting silent installation of the downloaded file..."
        try {
            # Run the installer silently and wait for it to complete.
            Start-Process -FilePath $destinationPath -ArgumentList "/quiet" -Wait -NoNewWindow
            Write-Output "Silent installation completed successfully."
        }
        catch {
            Write-Error "Silent installation failed. Error details: $_"
            throw $_
        }
    }
    else {
        Write-Warning "No valid ASP.NET Core Runtime version found in the JSON metadata."
    }

    # Post-installation .NET runtime check.
    Write-Verbose "=== Post-Installation .NET Runtime Check ==="
    $dotnetRuntimesAfter = Get-DotNetRuntimes
    if ($dotnetRuntimesAfter) {
        Write-Output "Installed .NET runtimes AFTER installation:"
        Write-Output $dotnetRuntimesAfter
    }
    else {
        Write-Output "No .NET runtimes found using the dotnet CLI AFTER installation."
    }
}
catch {
    Write-Error "An error occurred during execution. Error details: $_"
}
finally {
    Write-Verbose "Stopping transcript logging."
    Stop-Transcript
}
