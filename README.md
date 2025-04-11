# DotnetUpdater

A PowerShell script that downloads the latest ASP.NET Core Runtime hosting bundle, silently installs it, and logs detailed pre- and post-installation information. This script retrieves the .NET release metadata from an online JSON file, parses the data to determine the latest version, downloads the corresponding installer, and then checks the installed .NET runtimes before and after the installation.

## Features

- **Pre-Installation Check:**  
  Uses the `dotnet --list-runtimes` command to display all currently installed .NET runtimes.

- **Automated Metadata Download:**  
  Downloads the release metadata from [https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/9.0/releases.json](https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/9.0/releases.json) to identify the latest ASP.NET Core Runtime.

- **Installer Download and Silent Installation:**  
  Constructs the download URL in the format:  
  `https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/<version>/dotnet-hosting-<version>-win.exe`  
  Downloads the installer to `C:\DotnetUpdater\downloads` and installs it silently using the `/quiet` parameter.

- **Post-Installation Check:**  
  Checks and logs the installed .NET runtimes after the installation.

- **Verbose Logging:**  
  Logs detailed operations and errors to a timestamped log file stored in `C:\DotnetUpdater\logs`.
## Prerequisites

- **PowerShell:**  
  Version 5.1 or later (preferably run as Administrator).

- **Internet Connection:**  
  Required for downloading the release metadata and installer.


