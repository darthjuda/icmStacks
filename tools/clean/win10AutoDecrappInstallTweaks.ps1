#   ========================================================================
#   Windows 10 1803+ and Windows Server 2016+ cleaning and configuration script.
#
#   Version: 0.0.1
#   Website: https://icmjung.fr/win/scripts
#   By: darthjuda (https://icmjung.fr/about)
#
#   ========================================================================

Clear-Host;

$ProgressPreference = 'SilentlyContinue';

$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent();
$currentPrincipal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity);
$administratorRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator;

If (!$currentPrincipal.IsInRole($administratorRole)) {
    #   The script is currently executing with the standard user's permissions,
    #   and needs to be switched to run as Administrator.

    Write-Host 'Switching to run as Administrator.';

    $process = New-Object System.Diagnostics.ProcessStartInfo 'PowerShell.exe';
    $process.Arguments = $MyInvocation.MyCommand.Definition;
    $process.Verb = 'runas';

    [System.Diagnostics.Process]::Start($process) > $null;

    Exit;
}

#   ========================================================================
#   Unblock the script's file
#   ========================================================================

Unblock-File $PSCommandPath -Confirm:$false;

#   ========================================================================
#   Internal variables
#   ========================================================================

$is20H2OrNewer = [System.Environment]::OSVersion.Version.Build -ge 19042;
$is64bit = [System.Environment]::Is64BitOperatingSystem;
$osCommonVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId).ReleaseId -as [int];
$scheduledTaskPowerPlan = 'Cleaner10 - Power Plan';
$scheduledTaskContinueOnLogon = 'Cleaner10 - Continue on Logon';
$scheduledTaskPingNetworkDriveOnLogon = 'Cleaner10 - Ping Network Drive on Logon';
$scheduledTaskRebuildSearchIndex = "Cleaner10 - Rebuild Search Index";
$scheduledTaskRestart = 'Cleaner10 - Restart';

#   ========================================================================
#   External variables
#   ========================================================================

$computerName = 'windev10';
$decrapify = $true;# $true
$decrapifyClearStart = $true;# $true
$decrapifyKeepCortana = $false;# $true
$decrapifyKeepOneDrive = $false;# $true
$decrapifyKeepTablet = $false;# $true
$decrapifyKeepXbox = $false;# $true
$defaultExecutionPolicy = $true;# $true
$disableHibernation = $false;# $false
$disableLockScreen = $false;# $false
$disableUac = $false;# $false
$enableFirewallDomain = $true;# $true
$enableFirewallPrivate = $true;# $true
$enableFirewallPublic = $true;# $true
$enableMicrosoftUpdate = $true;# $false
$hosts = $null;# PATH|IP,...
$networkDrives = $null;# PATH|DRIVE_LETTER:,...
$networkDrivesPing = $false;# $false
$powerPlanGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c';
$removeOneDrive = $true;# $false
$removeUsers = $null;# User,...
$schedulePowerPlans = 'Monday,Tuesday,Wednesday,Thursday,Friday|09:00|8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c;Monday,Tuesday,Wednesday,Thursday,Friday|12:00|a1841308-3541-4fab-bc81-f71556f20b4a;Monday,Tuesday,Wednesday,Thursday,Friday|14:00|8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c;Monday,Tuesday,Wednesday,Thursday,Friday|18:00|a1841308-3541-4fab-bc81-f71556f20b4a;Sunday|00:00|00000000-0000-0000-0000-000000000000';# DAY_OF_WEEK[]|AT|POWER_PLAN_GUID;...
$scheduleRebuildSearchIndex = $null;# DAY_OF_WEEK|AT
$scheduleRestartAt = $null;# AT
$setEveryonePaths = $null;# DRIVE_LETTER:\,...
$sslTlsTemplate = 'default';
$timeZoneId = 'Romance Standard Time';

#   ========================================================================
#   Configurations
#   ========================================================================

Function Configure-ComputerName {
    If ($computerName -eq $null) {
        Return;
    }

    Write-Host "Configuring: Computer Name: $computerName";

    Rename-Computer -NewName $computerName > $null;
}

Function Configure-Hosts {
    If ($hosts -eq $null) {
        Return;
    }

    Write-Host 'Configuring: Hosts - Thank you Tom Chantler!';

    $addToHosts = "$PSScriptRoot\AddToHosts.ps1";

    Invoke-WebRequest 'https://raw.githubusercontent.com/TomChantler/EditHosts/master/AddToHosts.ps1' -OutFile $addToHosts;

    $hosts.Split(',') | ForEach {
        $pairs = $_.Split('|');
        $path = $pairs[0];
        $ip = $pairs[1];

        &"$addToHosts" -Hostname $path -DesiredIP $ip > $null;
    }
}

Function Configure-PowerPlan {
    If ($powerPlanGuid -eq $null) {
        Return;
    }

    $isEnabled = (POWERCFG /L | Where {
        $_.Contains('*')`
        -and $_.Contains($powerPlanGuid);
    }) -ne $null;

    If ($isEnabled) {
        Return;
    }

    $powerPlanGuid = Set-UltimatePerformancePowerPlan $powerPlanGuid;
    $powerPlanName = Get-PowerPlanName $powerPlanGuid;

    Write-Host "Configuring: Power Plan: $powerPlanName";

    POWERCFG /SETACTIVE $powerPlanGuid > $null;
}

Function Configure-SslTls {
    If ($sslTlsTemplate -eq $null) {
        Return;
    }

    $iiscryptocli = "${PSScriptRoot}\IISCryptoCli.exe";

    If (!(Test-Path -Path $iiscryptocli)) {
        $client = New-Object System.Net.WebClient;
        $client.DownloadFile('https://www.nartac.com/Downloads/IISCrypto/IISCryptoCli.exe', $iiscryptocli);

        Unblock-File $iiscryptocli -Confirm:$false;
    }

    Write-Host 'Configuring: SSL/TLS - Thank you Nartac Software!';

    Start-Process -FilePath $iiscryptocli -ArgumentList "/template $sslTlsTemplate" -PassThru | Wait-Process;

    Remove-Item -Path $iiscryptocli -Force -ErrorAction SilentlyContinue > $null;
}

Function Configure-TimeZone {
    If ($timeZoneId -eq $null) {
        Return;
    }

    $timeZoneName = Get-TimeZone -Id $timeZoneId | Select -ExpandProperty DisplayName;

    Write-Host "Configuring: Time Zone: $timeZoneName";

    Set-TimeZone -Id $timeZoneId;
}

Function Decrapify {
    If (!$decrapify) {
        Return;
    }

    $decrapifier = "${PSScriptRoot}\Decrapifier.ps1"

    If (!(Test-Path -Path $decrapifier)) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

        $response = Invoke-WebRequest -Uri "https://community.spiceworks.com/scripts/show/4378-windows-10-decrapifier-18xx-19xx" -UseBasicParsing;
        $responseContent = $response.Content;

        $scriptStart = $responseContent.IndexOf('<pre') + 5;
        $scriptEnd = $responseContent.IndexOf('</pre>');
        $scriptLength = $scriptEnd - $scriptStart;

        $responseContent.Substring($scriptStart, $scriptLength).Replace('&quot;', '`"').Replace('&lt;', '<').Replace('&gt;', '>').Replace('`', '').Replace('&#39;', '''') | Out-File $decrapifier -Force -ErrorAction SilentlyContinue;
    }

    Write-Host 'Decrapifying - Thank you CSAND!';

    &"$decrapifier" -NoLog -ClearStart:$decrapifyClearStart -Cortana:$decrapifyKeepCortana -OneDrive:$decrapifyKeepOneDrive -Tablet:$decrapifyKeepTablet -Xbox:$decrapifyKeepXbox > $null;
}

Function Disable-Firewall {
    If (!$enableFirewallDomain) {
        Write-Host 'Disabling: Domain Firewall';

        Set-NetFirewallProfile -Profile Domain -Enabled False;
    }

    If (!$enableFirewallPrivate) {
        Write-Host 'Disabling: Private Firewall';

        Set-NetFirewallProfile -Profile Private -Enabled False;
    }

    If (!$enableFirewallPublic) {
        Write-Host 'Disabling: Public Firewall';

        Set-NetFirewallProfile -Profile Public -Enabled False;
    }
}

Function Disable-Hibernation {
    If (!$disableHibernation) {
        Return;
    }

    $isDisabled = (Get-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -ErrorAction SilentlyContinue).GetValue('HibernateEnabled', $null) -ne $null;

    If ($isDisabled) {
        Return;
    }

    Write-Host 'Disabling: Hibernation';

    POWERCFG /H OFF > $null;
}

Function Disable-LockScreen {
    If (!$disableLockScreen) {
        Return;
    }

    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization';

    If (!(Test-Path $path)) {
        New-Item $path -Force;
        New-ItemProperty $path -Name 'NoLockScreen' -Value '1' -PropertyType DWORD -Force;
    }
}

Function Disable-Uac {
    If (!$disableUac) {
        Return;
    }

    $isDisabled = (Get-Item 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue | Get-ItemPropertyValue -Name 'EnableLUA' -ErrorAction SilentlyContinue) -eq 0;

    If ($isDisabled) {
        Return;
    }

    Write-Host 'Disabling: User Access Control (UAC) - Restart Required';

    New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableLUA' -PropertyType DWORD -Value 0 -Force > $null;

    Schedule-ContinueOnLogon;

    SHUTDOWN /R /T 0 /F > $null;

    Exit;
}

Function Enable-MicrosoftUpdate {
    If (!$enableMicrosoftUpdate) {
        Return;
    }

    $isEnabled = ((New-Object -ComObject Microsoft.Update.ServiceManager).Services | Where {
        $_.Name -eq 'Microsoft Update'
    } | Select -ExpandProperty 'IsDefaultAUService') -eq $true;

    If ($isEnabled) {
        Return;
    }

    Write-Host 'Enabling: Microsoft Update';

    (New-Object -ComObject Microsoft.Update.ServiceManager).AddService2('7971f918-a847-4430-9279-4a52d1efe18d', 7, '') > $null;
}

$install4kVideoDownloader = $false;# $false
$install7Zip = $true;# $false
$installAdobeCreativeCloud = $true;# $false - Manual completion
$installAdobeReader = $true;# $false
$installAppleItunes = $false;# $false
$installAwsToolsForWindows = $false;# $false
$installBlender = $false;# $false
$installBlizzardBattleNet = $false;# $false - Manual completion
$installDiscord = $true;# $false
$installDotNetCore31RuntimeAsp = $false;# $false
$installDotNetCore31RuntimeDesktop = $false;# $false
$installDotNetCore31Runtime = $false;# $false
$installDotNetCore31Sdk = $false;# $false
$installDotNetFramework48Runtime = $false;# $false
$installDotNetFramework48Sdk = $false;# $false
$installDotNet5RuntimeAsp = $false;# false
$installDotNet5RuntimeDesktop = $false;# false
$installDotNet5Runtime = $false;# false
$installDotNet5Sdk = $false;# false
$installEaOrigin = $false;# $false
$installEpicGames = $false;# $false
$installGitHubDesktop = $false;# $false - Completes installation after restart
$installGogGalaxy = $false;# $false
$installGoogleChrome = $true;# $false
$installHackFont = $false;# $false
$installImgBurn = $false;# $false - Will prompt with an error, just click Ignore.
$installMicrosoft365 = $false;# $false - Manual completion
$installMicrosoftEdge = $false;# $true
$installMicrosoftSilverlight = $false;# $false
$installMicrosoftSkype = $true;# $false
$installMozillaFirefox = $false;# $false
$installMpc = $false;# $false - No longer maintained
$installMyDefrag = $false;# $false - No longer available, I happen to have a copy of the last version released.
$installNtlite = $false;# $false
$installObs = $false;# $false
$installOracleVirtualBox = $false;# $false
$installPiriformCCleaner = $true;# $false
$installPiriformDefraggler = $true;# $false
$installPiriformRecuva = $true;# $false
$installPiriformSpeccy = $true;# $false
$installPrivateInternetAccess = $false;# false
$installRingCentralApp = $false;# $false
$installSqlServerManagementStudio = $false;# $false
$installTeamViewer11 = $false;# $false
$installTeamViewer12 = $false;# $false
$installTeamViewer13 = $false;# $false
$installTeamViewer14 = $false;# $false
$installTeamViewer15 = $true;# $false
$installTypora = $false;# $false
$installValveSteam = $false;# $false
$installVlc = $true;# $false
$installWinRAR = $false;# $false

Function Install-Software {
    $software = [System.Collections.ArrayList]@();

    If ($install4kVideoDownloader) {
        If ($is64bit) {
            $software.Add(@{
                Arguments = '/quiet /norestart';
                Exe = '4kvideodownloader_4.13.4_x64.msi';
                Name = '4K Video Downloader';
                Sleep = 30;
                Url = 'https://dl.4kdownload.com/app/4kvideodownloader_4.13.4_x64.msi';
            }) > $null;
        } Else {
            $software.Add(@{
                Arguments = '/quiet /norestart';
                Exe = '4kvideodownloader_4.13.4.msi';
                Name = '4K Video Downloader';
                Sleep = 30;
                Url = 'https://dl.4kdownload.com/app/4kvideodownloader_4.13.4.msi';
            }) > $null;
        }
    }

    If ($install7Zip) {
        If ($is64bit) {
            $software.Add(@{
                Arguments = '/S';
                Exe = '7z1900-x64.exe';
                Name = '7Zip';
                Sleep = 0;
                Url = 'https://www.7-zip.org/a/7z1900-x64.exe';
            }) > $null;
        } Else {
            $software.Add(@{
                Arguments = '/S';
                Exe = '7z1900.exe';
                Name = '7Zip';
                Sleep = 0;
                Url = 'https://www.7-zip.org/a/7z1900.exe';
            }) > $null;
        }
    }

    If ($installAdobeCreativeCloud) {
        $software.Add(@{
            Arguments = $null;
            Exe = 'Creative_Cloud_Set-Up.exe';
            Name = 'Adobe Creative Cloud';
            Sleep = 0;
            Url = 'https://prod-rel-ffc-ccm.oobesaas.adobe.com/adobe-ffc-external/core/v1/wam/download?sapCode=KCCC&productName=Creative%20Cloud&os=win&guid=2176d27c-06e9-4863-b839-58c0b78ede7d&wamFeature=nuj-live';
        }) > $null;
    }

    If ($installAdobeReader) {
        $software.Add(@{
            Arguments = '/S /norestart /sAll';
            Exe = 'readerdc_en_xa_crd_install.exe';
            Name = 'Adobe Reader DC';
            Sleep = 0;
            Url = 'https://admdownload.adobe.com/bin/live/readerdc_en_xa_crd_install.exe';
        }) > $null;
    }

    If ($installAwsToolsForWindows) {
        $software.Add(@{
            Arguments = '/quiet /norestart';
            Exe = 'AWSToolsAndSDKForNet.msi';
            Name = 'AWS Tools for Windows';
            Sleep = 0;
            Url = 'https://sdk-for-net.amazonwebservices.com/latest/AWSToolsAndSDKForNet.msi';
        }) > $null;
    }

    If ($installBlender) {
        $software.Add(@{
            Arguments = '/quiet /norestart';
            Exe = 'blender-2.90.1-windows64.msi';
            Name = 'Blender';
            Sleep = 0;
            Url = 'https://mirror.clarkson.edu/blender/release/Blender2.90/blender-2.90.1-windows64.msi';
        }) > $null;
    }

    If ($installBlizzardBattleNet) {
        $software.Add(@{
            Arguments = $null;
            Exe = 'Battle.net-Setup.exe';
            Name = 'Blizzard Battle.Net';
            Sleep = 0;
            Url = 'https://us.battle.net/download/getInstaller?os=win&installer=Battle.net-Setup.exe';
        }) > $null;
    }

    If ($installDiscord) {
        $software.Add(@{
            Arguments = '/S';
            Exe = 'DiscordSetup.exe';
            Name = 'Discord';
            Sleep = 0;
            Url = 'https://dl.discordapp.net/apps/win/0.0.308/DiscordSetup.exe';
        }) > $null;
    }

    If ($installDotNetCore31RuntimeAsp) {
        $software.Add(@{
            Arguments = '/q /norestart';
            Exe = 'dotnet-hosting-3.1.10-win.exe';
            Name = 'ASP.NET Core 3.1 Runtime';
            Sleep = 0;
            Url = 'https://download.visualstudio.microsoft.com/download/pr/7e35ac45-bb15-450a-946c-fe6ea287f854/a37cfb0987e21097c7969dda482cebd3/dotnet-hosting-3.1.10-win.exe';
        }) > $null;
    }

    If ($installDotNetCore31RuntimeDesktop) {
        $software.Add(@{
            Arguments = '/q /norestart';
            Exe = 'windowsdesktop-runtime-3.1.10-win-x86.exe';
            Name = '.NET Core 3.1 Desktop Runtime (32-bit)';
            Sleep = 0;
            Url = 'https://download.visualstudio.microsoft.com/download/pr/865d0be5-16e2-4b3d-a990-f4c45acd280c/ec867d0a4793c0b180bae85bc3a4f329/windowsdesktop-runtime-3.1.10-win-x86.exe';
        }) > $null;

        If ($is64bit) {
            $software.Add(@{
                Arguments = '/q /norestart';
                Exe = 'windowsdesktop-runtime-3.1.10-win-x64.exe';
                Name = '.NET Core 3.1 Desktop Runtime (64-bit)';
                Sleep = 0;
                Url = 'https://download.visualstudio.microsoft.com/download/pr/513acf37-8da2-497d-bdaa-84d6e33c1fee/eb7b010350df712c752f4ec4b615f89d/windowsdesktop-runtime-3.1.10-win-x64.exe';
            }) > $null;
        }
    }

    If ($installDotNetCore31Runtime) {
        $software.Add(@{
            Arguments = '/q /norestart';
            Exe = 'dotnet-runtime-3.1.10-win-x86.exe';
            Name = '.NET Core 3.1 Runtime (32-bit)';
            Sleep = 0;
            Url = 'https://download.visualstudio.microsoft.com/download/pr/abb3fb5d-4e82-4ca8-bc03-ac13e988e608/b34036773a72b30c5dc5520ee6a2768f/dotnet-runtime-3.1.10-win-x86.exe';
        }) > $null;

        If ($is64bit) {
            $software.Add(@{
                Arguments = '/q /norestart';
                Exe = 'dotnet-runtime-3.1.10-win-x64.exe';
                Name = '.NET Core 3.1 Runtime (64-bit)';
                Sleep = 0;
                Url = 'https://download.visualstudio.microsoft.com/download/pr/9845b4b0-fb52-48b6-83cf-4c431558c29b/41025de7a76639eeff102410e7015214/dotnet-runtime-3.1.10-win-x64.exe';
            }) > $null;
        }
    }

    If ($installDotNetCore31Sdk) {
        $software.Add(@{
            Arguments = '/q /norestart';
            Exe = 'dotnet-sdk-3.1.404-win-x86.exe';
            Name = '.NET Core 3.1 SDK (32-bit)';
            Sleep = 0;
            Url = 'https://download.visualstudio.microsoft.com/download/pr/349bc444-2bf8-4aa0-b546-4f1731f499c5/64f6c5eb26fcd64fbdaee852f038cdd7/dotnet-sdk-3.1.404-win-x86.exe';
        }) > $null;

        If ($is64bit) {
            $software.Add(@{
                Arguments = '/q /norestart';
                Exe = 'dotnet-sdk-3.1.404-win-x64.exe';
                Name = '.NET Core 3.1 SDK (64-bit)';
                Sleep = 0;
                Url = 'https://download.visualstudio.microsoft.com/download/pr/3366b2e6-ed46-48ae-bf7b-f5804f6ee4c9/186f681ff967b509c6c9ad31d3d343da/dotnet-sdk-3.1.404-win-x64.exe';
            }) > $null;
        }
    }

    If ($installDotNetFramework48Runtime) {
        $software.Add(@{
            Arguments = '/q /norestart';
            Exe = 'ndp48-x86-x64-allos-enu.exe';
            Name = '.NET Framework 4.8 Runtime';
            Sleep = 0;
            Url = 'https://download.visualstudio.microsoft.com/download/pr/014120d7-d689-4305-befd-3cb711108212/0fd66638cde16859462a6243a4629a50/ndp48-x86-x64-allos-enu.exe';
        }) > $null;
    }

    If ($installDotNetFramework48Sdk) {
        $software.Add(@{
            Arguments = '/q /norestart';
            Exe = 'ndp48-devpack-enu.exe';
            Name = '.NET Framework 4.8 SDK';
            Sleep = 0;
            Url = 'https://download.visualstudio.microsoft.com/download/pr/014120d7-d689-4305-befd-3cb711108212/0307177e14752e359fde5423ab583e43/ndp48-devpack-enu.exe';
        }) > $null;
    }

    If ($installDotNet5RuntimeAsp) {
        $software.Add(@{
            Arguments = '/q /norestart';
            Exe = 'dotnet-hosting-5.0.0-win.exe';
            Name = 'ASP.NET 5 Runtime';
            Sleep = 0;
            Url = 'https://download.visualstudio.microsoft.com/download/pr/08d642f7-8ade-4de3-9eae-b77fd05e5f01/503da91e7ea62d8be06488b014643c12/dotnet-hosting-5.0.0-win.exe';
        }) > $null;
    }

    If ($installDotNet5RuntimeDesktop) {
        $software.Add(@{
            Arguments = '/q /norestart';
            Exe = 'windowsdesktop-runtime-5.0.0-win-x86.exe';
            Name = '.NET 5 Desktop Runtime (32-bit)';
            Sleep = 0;
            Url = 'https://download.visualstudio.microsoft.com/download/pr/b2780d75-e54a-448a-95fc-da9721b2b4c2/62310a9e9f0ba7b18741944cbae9f592/windowsdesktop-runtime-5.0.0-win-x86.exe';
        }) > $null;

        If ($is64bit) {
            $software.Add(@{
                Arguments = '/q /norestart';
                Exe = 'windowsdesktop-runtime-5.0.0-win-x64.exe';
                Name = '.NET 5 Desktop Runtime (64-bit)';
                Sleep = 0;
                Url = 'https://download.visualstudio.microsoft.com/download/pr/1b3a8899-127a-4465-a3c2-7ce5e4feb07b/1e153ad470768baa40ed3f57e6e7a9d8/windowsdesktop-runtime-5.0.0-win-x64.exe';
            }) > $null;
        }
    }

    If ($installDotNet5Runtime) {
        $software.Add(@{
            Arguments = '/q /norestart';
            Exe = 'dotnet-runtime-5.0.0-win-x86.exe';
            Name = '.NET 5 Runtime (32-bit)';
            Sleep = 0;
            Url = 'https://download.visualstudio.microsoft.com/download/pr/a7e15da3-7a15-43c2-a481-cf50bf305214/c69b951e8b47101e90b1289c387bb01a/dotnet-runtime-5.0.0-win-x86.exe';
        }) > $null;

        If ($is64bit) {
            $software.Add(@{
                Arguments = '/q /norestart';
                Exe = 'dotnet-runtime-5.0.0-win-x64.exe';
                Name = '.NET 5 Runtime (64-bit)';
                Sleep = 0;
                Url = 'https://download.visualstudio.microsoft.com/download/pr/36a9dc4e-1745-4f17-8a9c-f547a12e3764/ae25e38f20a4854d5e015a88659a22f9/dotnet-runtime-5.0.0-win-x64.exe';
            }) > $null;
        }
    }

    If ($installDotNet5Sdk) {
        $software.Add(@{
            Arguments = '/q /norestart';
            Exe = 'dotnet-sdk-5.0.100-win-x86.exe';
            Name = '.NET 5 SDK (32-bit)';
            Sleep = 0;
            Url = 'https://download.visualstudio.microsoft.com/download/pr/caa07f2f-f736-4115-80a1-b9c86fe3e55e/bd8df5ab7aad36795ef2c017594fafad/dotnet-sdk-5.0.100-win-x86.exe';
        }) > $null;

        If ($is64bit) {
            $software.Add(@{
                Arguments = '/q /norestart';
                Exe = 'dotnet-sdk-5.0.100-win-x64.exe';
                Name = '.NET 5 SDK (64-bit)';
                Sleep = 0;
                Url = 'https://download.visualstudio.microsoft.com/download/pr/2892493e-df43-409e-af68-8b14aa75c029/53156c889fc08f01b7ed8d7135badede/dotnet-sdk-5.0.100-win-x64.exe';
            }) > $null;
        }
    }

    If ($installEpicGames) {
        $software.Add(@{
            Arguments = '/quiet /norestart';
            Exe = 'EpicInstaller-10.19.2.msi';
            Name = 'Epic Games';
            Sleep = 0;
            Url = 'https://epicgames-download1.akamaized.net/Builds/UnrealEngineLauncher/Installers/Win32/EpicInstaller-10.19.2.msi';
        }) > $null;
    }

    If ($installGitHubDesktop) {
        $software.Add(@{
            Arguments = $null;
            Exe = 'GitHubDesktopSetup.msi';
            Name = 'GitHub Desktop';
            Sleep = 0;
            Url = 'https://desktop.githubusercontent.com/releases/2.5.7-cfea2832/GitHubDesktopSetup.msi';
        }) > $null;
    }

    If ($installGogGalaxy) {
        #   https://www.computerbase.de/downloads/games/gog-galaxy/

        $software.Add(@{
            Arguments = '/SILENT /VERYSILENT /NORESTART';
            Exe = 'setup_galaxy_2.0.23.4.exe';
            Name = 'GOG Galaxy';
            Sleep = 0;
            Url = 'https://cdn.gog.com/open/galaxy/client/setup_galaxy_2.0.23.4.exe';
        }) > $null;
    }

    If ($installGoogleChrome) {
        If ($is64bit) {
            $software.Add(@{
                Arguments = '/quiet /norestart';
                Exe = 'googlechromestandaloneenterprise64.msi';
                Name = 'Google Chrome (64-bit)';
                Sleep = 0;
                Url = 'https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BAB25F655-49F0-3CB9-06EB-F685E2898217%7D%26lang%3Den%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dtrue%26ap%3Dx64-stable-statsdef_0%26brand%3DGCEA/dl/chrome/install/googlechromestandaloneenterprise64.msi';
            }) > $null;
        } Else {
            $software.Add(@{
                Arguments = '/quiet /norestart';
                Exe = 'googlechromestandaloneenterprise.msi';
                Name = 'Google Chrome (32-bit)';
                Sleep = 0;
                Url = 'https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BAB25F655-49F0-3CB9-06EB-F685E2898217%7D%26lang%3Den%26browser%3D4%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dtrue%26ap%3Dstable-arch_x86-statsdef_0%26brand%3DGCEA/dl/chrome/install/googlechromestandaloneenterprise.msi';
            }) > $null;
        }
    }

    If ($installHackFont) {
        $software.Add(@{
            Arguments = '/VERYSILENT /NORESTART';
            Exe = 'HackFontsWindowsInstaller.exe';
            Name = 'Hack Font';
            Sleep = 0;
            Url = 'https://github.com/source-foundry/Hack-windows-installer/releases/download/v1.6.0/HackFontsWindowsInstaller.exe';
        }) > $null;
    }

    If ($installImgBurn) {
        $software.Add(@{
            Arguments = '/S';
            Exe = 'SetupImgBurn_2.5.8.0.exe';
            Name = 'ImgBurn';
            Sleep = 0;
            Url = 'http://download.imgburn.com/SetupImgBurn_2.5.8.0.exe';
        }) > $null;
    }

    If ($installAppleItunes) {
        If ($is64bit) {
            $software.Add(@{
                Arguments = '/quiet /norestart';
                Exe = 'iTunes64Setup.exe';
                Name = 'iTunes (64-bit)';
                Sleep = 0;
                Url = 'https://secure-appldnld.apple.com/itunes12/001-50023-20201019-A1CA6082-1239-11EB-990E-FA5946985FC9/iTunes64Setup.exe';
            }) > $null;
        } Else {
            $software.Add(@{
                Arguments = '/quiet /norestart';
                Exe = 'iTunesSetup.exe';
                Name = 'iTunes (32-bit)';
                Sleep = 0;
                Url = 'https://secure-appldnld.apple.com/itunes12/001-50021-20201019-A1CAB6C2-1239-11EB-AE89-F95946985FC9/iTunesSetup.exe';
            }) > $null;
        }
    }

    If ($installMicrosoft365) {
        If ($is64bit) {
            $software.Add(@{
                Arguments = $null;
                Exe = 'setupo365homepremretail.x64.en-us_.exe';
                Name = 'Microsoft 365 (64-bit)';
                Sleep = 0;
                Url = 'https://c2rsetup.officeapps.live.com/c2r/download.aspx?productReleaseID=O365HomePremRetail&platform=X64&language=en-US&version=O16GA';
            }) > $null;
        } Else {
            $software.Add(@{
                Arguments = $null;
                Exe = 'OfficeSetup.exe';
                Name = 'Microsoft 365 (32-bit)';
                Sleep = 0;
                Url = 'https://c2rsetup.officeapps.live.com/c2r/download.aspx?productReleaseID=O365HomePremRetail&platform=X86&language=en-US&version=O16GA';
            }) > $null;
        }
    }

    If ($installMicrosoftEdge -and !$is20H2OrNewer) {
        If ($is64bit) {
            $software.Add(@{
                Arguments = '/quiet /norestart';
                Exe = 'MicrosoftEdgeEnterpriseX64.msi';
                Name = 'Microsoft Edge (64-bit, Chromium based)';
                Sleep = 0;
                Url = 'https://msedge.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/ab0c8679-a83c-450b-bdf1-2a955cf23ad4/MicrosoftEdgeEnterpriseX64.msi';
            }) > $null;
        } Else {
            $software.Add(@{
                Arguments = '/quiet /norestart';
                Exe = 'MicrosoftEdgeEnterpriseX86.msi';
                Name = 'Microsoft Edge (32-bit, Chromium based)';
                Sleep = 0;
                Url = 'https://msedge.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/3abf3642-ad63-4235-9379-8903396f82da/MicrosoftEdgeEnterpriseX86.msi';
            }) > $null;
        }
    }

    If ($installMozillaFirefox) {
        If ($is64bit) {
            $software.Add(@{
                Arguments = '/S';
                Exe = 'Firefox%20Setup%2082.0.3.exe';
                Name = 'Mozilla Firefox (64-bit)';
                Sleep = 0;
                Url = 'https://cdn.stubdownloader.services.mozilla.com/builds/firefox-latest-ssl/en-US/win64/1567c08da230d3a1db0d460da89792e877b276d1d414d94563eddf3e901b5599/Firefox%20Setup%2082.0.3.exe';
            }) > $null;
        } Else {
            $software.Add(@{
                Arguments = '/S';
                Exe = 'Firefox%20Setup%2082.0.3.exe';
                Name = 'Mozilla Firefox (32-bit)';
                Sleep = 0;
                Url = 'https://cdn.stubdownloader.services.mozilla.com/builds/firefox-latest-ssl/en-US/win/8766ab073715892d2102ee6424890db65a6d88e4a89f8bd6044550592eeb5d39/Firefox%20Setup%2082.0.3.exe';
            }) > $null;
        }
    }

    If ($installMpc) {
        If ($is64bit) {
            $software.Add(@{
                Arguments = '/silent';
                Exe = 'MPC-HC.1.7.13.x64.exe';
                Name = 'Media Player Classic - Home Cinema (64-bit)';
                Sleep = 0;
                Url = 'https://binaries.mpc-hc.org/MPC%20HomeCinema%20-%20x64/MPC-HC_v1.7.13_x64/MPC-HC.1.7.13.x64.exe';
            }) > $null;
        } Else {
            $software.Add(@{
                Arguments = '/silent';
                Exe = 'MPC-HC.1.7.13.x86.exe';
                Name = 'Media Player Classic - Home Cinema (32-bit)';
                Sleep = 0;
                Url = 'https://binaries.mpc-hc.org/MPC%20HomeCinema%20-%20Win32/MPC-HC_v1.7.13_x86/MPC-HC.1.7.13.x86.exe';
            }) > $null;
        }
    }

    If ($installMyDefrag) {
        $software.Add(@{
            Arguments = '/VERYSILENT /NORESTART';
            Exe = 'MyDefrag4.3.1.exe';
            Name = 'MyDefrag';
            Sleep = 0;
            Url = 'https://cleaner10.io/files/MyDefrag4.3.1.exe';
        }) > $null;
    }

    If ($installNtlite) {
        #   2.0.0.7722

        If ($is64bit) {
            $software.Add(@{
                Arguments = '/silent';
                Exe = 'NTLite_setup_x64.exe';
                Name = 'NTLite (64-bit)';
                Sleep = 0;
                Url = 'https://downloads.ntlite.com/files/NTLite_setup_x64.exe';
            }) > $null;
        } Else {
            $software.Add(@{
                Arguments = '/silent';
                Exe = 'NTLite_setup_x86.exe';
                Name = 'NTLite (32-bit)';
                Sleep = 0;
                Url = 'https://downloads.ntlite.com/files/NTLite_setup_x86.exe';
            }) > $null;
        }
    }

    If ($installObs) {
        If ($is64bit) {
            $software.Add(@{
                Arguments = '/S';
                Exe = 'OBS-Studio-26.0.2-Full-Installer-x64.exe';
                Name = 'OBS Studio (64-bit)';
                Sleep = 0;
                Url = 'https://cdn-fastly.obsproject.com/downloads/OBS-Studio-26.0.2-Full-Installer-x64.exe';
            }) > $null;
        } Else {
            $software.Add(@{
                Arguments = '/S';
                Exe = 'OBS-Studio-26.0.2-Full-Installer-x86.exe';
                Name = 'OBS Studio (32-bit)';
                Sleep = 0;
                Url = 'https://cdn-fastly.obsproject.com/downloads/OBS-Studio-26.0.2-Full-Installer-x86.exe';
            }) > $null;
        }
    }

    If ($installEaOrigin) {
        $software.Add(@{
            Arguments = '/silent';
            Exe = 'OriginThinSetup.exe';
            Name = 'EA Origin';
            Sleep = 0;
            Url = 'https://origin-a.akamaihd.net/Origin-Client-Download/origin/live/OriginThinSetup.exe';
        }) > $null;
    }

    If ($installPiriformCCleaner) {
        Disable-ChromeInstallation;

        $software.Add(@{
            Arguments = '/S';
            Exe = 'ccsetup574.exe';
            Name = 'Piriform CCleaner';
            Sleep = 0;
            Url = 'https://download.ccleaner.com/ccsetup574.exe';
        }) > $null;
    }

    If ($installPiriformDefraggler) {
        Disable-ChromeInstallation;

        $software.Add(@{
            Arguments = '/S';
            Exe = 'dfsetup222.exe';
            Name = 'Piriform Defraggler';
            Sleep = 0;
            Url = 'https://download.ccleaner.com/dfsetup222.exe';
        }) > $null;
    }

    If ($installPiriformRecuva) {
        Disable-ChromeInstallation;

        $software.Add(@{
            Arguments = '/S';
            Exe = 'rcsetup153.exe';
            Name = 'Piriform Recuva';
            Sleep = 0;
            Url = 'https://download.ccleaner.com/rcsetup153.exe';
        }) > $null;
    }

    If ($installPiriformSpeccy) {
        Disable-ChromeInstallation;

        $software.Add(@{
            Arguments = '/S';
            Exe = 'spsetup132.exe';
            Name = 'Piriform Speccy';
            Sleep = 0;
            Url = 'https://download.ccleaner.com/spsetup132.exe';
        }) > $null;
    }

    If ($installPrivateInternetAccess) {
        If ($is64bit) {
            $software.Add(@{
                Arguments = '/silent';
                Exe = 'pia-windows-x64-2.5.1-05676.exe';
                Name = 'Private Internet Access VPN (64-bit)';
                Sleep = 0;
                Url = 'https://installers.privateinternetaccess.com/download/pia-windows-x64-2.5.1-05676.exe';
            }) > $null;
        } Else {
            $software.Add(@{
                Arguments = '/silent';
                Exe = 'pia-windows-x86-2.5.1-05676.exe';
                Name = 'Private Internet Access VPN (32-bit)';
                Sleep = 0;
                Url = 'https://installers.privateinternetaccess.com/download/pia-windows-x86-2.5.1-05676.exe';
            }) > $null;
        }
    }

    If ($installRingCentralApp) {
        $software.Add(@{
            Arguments = '/quiet /norestart';
            Exe = 'RingCentral-x64.msi';
            Name = 'RingCentral App';
            Sleep = 0;
            Url = 'https://app.ringcentral.com/download/RingCentral-x64.msi';
        }) > $null;
    }

    If ($installMicrosoftSilverlight) {
        $software.Add(@{
            Arguments = '/q';
            Exe = 'Silverlight_x64.exe';
            Name = 'Microsoft Silverlight';
            Sleep = 0;
            Url = 'https://download.microsoft.com/download/D/D/F/DDF23DF4-0186-495D-AA35-C93569204409/50918.00/Silverlight_x64.exe';
        }) > $null;
    }

    If ($installMicrosoftSkype) {
        $software.Add(@{
            Arguments = '/silent';
            Exe = 'Skype-8.66.0.77.exe';
            Name = 'Skype';
            Sleep = 0;
            Url = 'https://download.skype.com/s4l/download/win/Skype-8.66.0.77.exe';
        }) > $null;
    }

    If ($installSqlServerManagementStudio) {
        $software.Add(@{
            Arguments = '/quiet /norestart';
            Exe = 'SSMS-Setup-ENU.exe';
            Name = 'SQL Server Management Studio';
            Sleep = 60;
            Url = 'https://download.microsoft.com/download/2/d/1/2d12f6a1-e28f-42d1-9617-ac036857c5be/SSMS-Setup-ENU.exe';
        }) > $null;
    }

    If ($installValveSteam) {
        $software.Add(@{
            Arguments = '/S';
            Exe = 'SteamSetup.exe';
            Name = 'Steam';
            Sleep = 0;
            Url = 'https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe';
        }) > $null;
    }

    If ($installTeamViewer11) {
        $software.Add(@{
            Arguments = '/S /norestart';
            Exe = 'TeamViewer_Setup.exe';
            Name = 'TeamViewer 11';
            Sleep = 0;
            Url = 'http://download.teamviewer.com/download/version_11x/TeamViewer_Setup.exe';
        }) > $null;
    }

    If ($installTeamViewer12) {
        $software.Add(@{
            Arguments = '/S /norestart';
            Exe = 'TeamViewer_Setup.exe';
            Name = 'TeamViewer 12';
            Sleep = 0;
            Url = 'http://download.teamviewer.com/download/version_12x/TeamViewer_Setup.exe';
        }) > $null;
    }

    If ($installTeamViewer13) {
        $software.Add(@{
            Arguments = '/S /norestart';
            Exe = 'TeamViewer_Setup.exe';
            Name = 'TeamViewer 13';
            Sleep = 0;
            Url = 'http://download.teamviewer.com/download/version_13x/TeamViewer_Setup.exe';
        }) > $null;
    }

    If ($installTeamViewer14) {
        $software.Add(@{
            Arguments = '/S /norestart';
            Exe = 'TeamViewer_Setup.exe';
            Name = 'TeamViewer 14';
            Sleep = 0;
            Url = 'http://download.teamviewer.com/download/version_14x/TeamViewer_Setup.exe';
        }) > $null;
    }

    If ($installTeamViewer15) {
        $software.Add(@{
            Arguments = '/S /norestart';
            Exe = 'TeamViewer_Setup.exe';
            Name = 'TeamViewer 15';
            Sleep = 0;
            Url = 'http://download.teamviewer.com/download/version_15x/TeamViewer_Setup.exe';
        }) > $null;
    }

    If ($installTypora) {
        If ($is64bit) {
            $software.Add(@{
                Arguments = '/silent /verysilent';
                Exe = 'typora-setup-x64.exe';
                Name = 'Typora (64-bit)';
                Sleep = 0;
                Url = 'https://typora.io/windows/typora-setup-x64.exe';
            }) > $null;
        } Else {
            $software.Add(@{
                Arguments = '/silent /verysilent';
                Exe = 'typora-setup-ia32.exe';
                Name = 'Typora (32-bit)';
                Sleep = 0;
                Url = 'https://typora.io/windows/typora-setup-ia32.exe';
            }) > $null;
        }
    }

    If ($installOracleVirtualBox) {
        $software.Add(@{
            Arguments = '--silent';
            Exe = 'VirtualBox-6.1.16-140961-Win.exe';
            Name = 'VirtualBox';
            Sleep = 30;
            Url = 'https://download.virtualbox.org/virtualbox/6.1.16/VirtualBox-6.1.16-140961-Win.exe';
        }) > $null;
    }

    If ($installVlc) {
        If ($is64bit) {
            $software.Add(@{
                Arguments = '/S';
                Exe = 'vlc-3.0.11-win64.exe';
                Name = 'VLC (64-bit)';
                Sleep = 0;
                Url = 'https://plug-mirror.rcac.purdue.edu/vlc/vlc/3.0.11/win64/vlc-3.0.11-win64.exe';
            }) > $null;
        } Else {
            $software.Add(@{
                Arguments = '/S';
                Exe = 'vlc-3.0.11-win32.exe';
                Name = 'VLC (32-bit)';
                Sleep = 0;
                Url = 'https://mirrors.syringanetworks.net/videolan/vlc/3.0.11/win32/vlc-3.0.11-win32.exe';
            }) > $null;
        }
    }

    If ($installWinRAR) {
        If ($is64bit) {
            $software.Add(@{
                Arguments = '/S';
                Exe = 'winrar-x64-591.exe';
                Name = 'WinRAR (64-bit)';
                Sleep = 0;
                Url = 'https://www.rarlab.com/rar/winrar-x64-591.exe';
            }) > $null;
        } Else {
            $software.Add(@{
                Arguments = '/S';
                Exe = 'wrar591.exe';
                Name = 'WinRAR (32-bit)';
                Sleep = 0;
                Url = 'https://www.rarlab.com/rar/wrar591.exe';
            }) > $null;
        }
    }

    $client = New-Object System.Net.WebClient;

    $software | ForEach {
        Write-Host "Downloading Software: $($_.Name)";

        $path = "$PSScriptRoot\$($_.Exe)";

        $client.DownloadFile($_.Url, $path);

        Unblock-File $path -Confirm:$false;

        Write-Host "Installing Software: $($_.Name)";

        If ($_.Arguments -eq $null) {
            Start-Process -FilePath $path -PassThru | Wait-Process;
        } Else {
            Start-Process -FilePath $path -ArgumentList $_.Arguments -PassThru | Wait-Process;
        }

        Start-Sleep -Seconds $_.Sleep;

        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue;
    }

    Enable-ChromeInstallation;
}

Function Map-NetworkDrives {
    If ($networkDrives.Length -eq 0) {
        Return;
    }

    $networkDrives.Split(',') | ForEach {
        $pairs = $_.Split('|');
        $path = $pairs[0];
        $drive = $pairs[1];

        NET USE $drive $path /PERSISTENT:YES > $null;

        If (!$networkDrivesPing) {
            Continue;
        }

        $driveLetter = $drive.Replace(":", $null);

        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-Command 'Test-Path -Path $path'";
        $principal = New-ScheduledTaskPrincipal $currentPrincipal.Identity.Name -RunLevel Highest;
        $settings = New-ScheduledTaskSettingsSet;
        $trigger = New-ScheduledTaskTrigger -AtLogOn;
        $task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings;

        Register-ScheduledTask -TaskName "$scheduledTaskPingNetworkDriveOnLogon ($driveLetter)" -InputObject $task > $null;
    }
}

Function Remove-OneDrive {
    If (!$removeOneDrive) {
        Return;
    }

    $isInstalled = Test-Path "${Env:LocalAppData}\Microsoft\OneDrive\OneDrive.exe";

    If (!$isInstalled) {
        Return;
    }

    Write-Host 'Removing: OneDrive';

    Stop-Process -Name 'OneDrive' -ErrorAction SilentlyContinue -Force;

    $argumentsList = @(
        '/UNINSTALL'
    );
    $filePath = "${Env:SystemRoot}\System32\OneDriveSetup.exe";

    If ($is64bit) {
        $filePath = "${Env:SystemRoot}\SysWOW64\OneDriveSetup.exe";
    }

    Start-Process -FilePath $filePath -ArgumentList $argumentsList | Wait-Process;
}

Function Remove-User {
    If ($removeUsers -eq $null) {
        Return;
    }

    $users = $removeUsers.Split(',') | ForEach {
        Write-Host "Removing: User: $_";

        Remove-LocalUser -Name "$_" -ErrorAction SilentlyContinue > $null;
        Remove-Item -Path "${Env:SystemDrive}\Users\$_" -Recurse -Force -ErrorAction SilentlyContinue > $null;
    }
}

Function Schedule-PowerPlans {
    If ($schedulePowerPlans -eq $null) {
        Return;
    }

    Write-Host 'Scheduling power plan task(s)';

    $powerPlans = $schedulePowerPlans.Split(';') | ForEach {
        $pairs = $_.Split('|');
        $daysOfWeek = $pairs[0].Split(',');
        $at = $pairs[1];
        $powerPlanGuid_ = $pairs[2];
        $powerPlanName = Get-PowerPlanName $powerPlanGuid_;
        $powerPlanGuid_ = Set-UltimatePerformancePowerPlan $powerPlanGuid_;

        $action = New-ScheduledTaskAction -Execute "POWERCFG" -Argument "/SETACTIVE $powerPlanGuid_";
        $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest;
        $settings = New-ScheduledTaskSettingsSet;
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $daysOfWeek -At $at;
        $task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings;

        Register-ScheduledTask -TaskName "$scheduledTaskPowerPlan ($powerPlanName)" -InputObject $task > $null;
    }
}

Function Schedule-RebuildSearchIndex {
    If ($scheduleRebuildSearchIndex -eq $null) {
        Return;
    }

    # https://www.tenforums.com/tutorials/58569-rebuild-search-index-windows-10-a.html

    $folder = "${Env:SystemDrive}\Cleaner10";
    $script = "$folder\RebuildIndex.ps1";

    If (!(Test-Path $folder)) {
        New-Item $folder -ItemType Directory > $null;
    }

    If (!(Test-Path $script)) {
        New-Item $script -ItemType File > $null;
        Set-Content $script -Value @'
Stop-Service -Name "wsearch" -Force;

Remove-Item "${Env:ProgramData}\Microsoft\Search\Data\Applications\Windows\Windows.edb" -Force;

$started = $false;

Do {
    Start-Service -Name "wsearch" -ErrorAction SilentlyContinue;

    $started = (Get-Service -Name "wsearch").Status -eq 'Running';
} While (!$started);
'@;
    }

    $pairs = $scheduleRebuildSearchIndex.Split('|');
    $daysOfWeek = $pairs[0];
    $at = $pairs[1];

    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File $script";
    $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest;
    $settings = New-ScheduledTaskSettingsSet;
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $daysOfWeek -At $at;
    $task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings;

    Register-ScheduledTask -TaskName $scheduledTaskRebuildSearchIndex -InputObject $task > $null;
}

Function Schedule-Restart {
    If ($scheduleRestartAt -eq $null) {
        Return;
    }

    Write-Host 'Scheduling restart task';

    $action = New-ScheduledTaskAction -Execute "SHUTDOWN" -Argument "/R /D P:0:0";
    $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest;
    $settings = New-ScheduledTaskSettingsSet;
    $trigger = New-ScheduledTaskTrigger -Daily -At $scheduleRestartAt;
    $task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings;

    Register-ScheduledTask -TaskName $scheduledTaskRestart -InputObject $task > $null;
}

Function Set-PathPermissionsToEveryoneOnly {
    If ($setEveryonePaths -eq $null) {
        Return;
    }

    Write-Host "Setting permissions for Everyone on paths: $setEveryonePaths";

    $setEveryonePaths.Split(',') | ForEach {
        $acl = Get-Acl $_;
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule('Everyone', 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow');

        $acl.SetAccessRule($accessRule);

        $acl.Access | Where {
            $_.IdentityReference -ne 'Everyone'
        } | ForEach {
            $acl.RemoveAccessRuleAll($_);
        }

        Set-Acl $_ $acl;
    }
}

#   ========================================================================
#   Utilities
#   ========================================================================

Function Disable-ChromeInstallation {
    If ($is64bit) {
        $path641 = 'HKLM:\SOFTWARE\Wow6432Node\Google\No Chrome Offer Until';
        $path642 = 'HKLM:\SOFTWARE\Wow6432Node\Google\No Toolbar Offer Until';

        If (!(Test-Path $path641)) {
            New-Item $path641 -Force;
            New-ItemProperty $path641 -Name 'Piriform Ltd' -Value '20991231' -PropertyType DWORD -Force > $null;
        }

        If (!(Test-Path $path642)) {
            New-Item $path642 -Force;
            New-ItemProperty $path642 -Name 'Piriform Ltd' -Value '20991231' -PropertyType DWORD -Force > $null;
        }
    } Else {
        $path321 = 'HKLM:\SOFTWARE\Google\No Chrome Offer Until';
        $path322 = 'HKLM:\SOFTWARE\Google\No Toolbar Offer Until';

        If (!(Test-Path $path321)) {
            New-Item $path321 -Force;
            New-ItemProperty $path321 -Name 'Piriform Ltd' -Value '20991231' -PropertyType DWORD -Force > $null;
        }

        If (!(Test-Path $path322)) {
            New-Item $path322 -Force;
            New-ItemProperty $path322 -Name 'Piriform Ltd' -Value '20991231' -PropertyType DWORD -Force > $null;
        }
    }
}

Function Enable-ChromeInstallation {
    If ($is64bit) {
        $path641 = 'HKLM:\SOFTWARE\Wow6432Node\Google\No Chrome Offer Until';
        $path642 = 'HKLM:\SOFTWARE\Wow6432Node\Google\No Toolbar Offer Until';

        If (Test-Path $path641) {
            Remove-Item $path641 -Force -ErrorAction SilentlyContinue > $null;
        }

        If (Test-Path $path642) {
            Remove-Item $path642 -Force -ErrorAction SilentlyContinue > $null;
        }
    } Else {
        $path321 = 'HKLM:\SOFTWARE\Google\No Chrome Offer Until';
        $path322 = 'HKLM:\SOFTWARE\Google\No Toolbar Offer Until';

        If (Test-Path $path321) {
            Remove-Item $path321 -Force -ErrorAction SilentlyContinue > $null;
        }

        If (Test-Path $path322) {
            Remove-Item $path322 -Force -ErrorAction SilentlyContinue > $null;
        }
    }
}

Function Get-PowerPlanName(
    $guid) {
    Switch ($guid) {
        '381b4222-f694-41f0-9685-ff5bb260df2e' {
            Return 'Balanced';
        }
        '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' {
            Return 'High Performance';
        }
        'a1841308-3541-4fab-bc81-f71556f20b4a' {
            Return 'Power Saver';
        }
        'e9a42b02-d5df-448d-aa00-03f14749eb61' {
            Return 'Ultimate Performance';
        }
    }
}

Function Schedule-ContinueOnLogon {
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File $PSCommandPath";
    $principal = New-ScheduledTaskPrincipal $currentPrincipal.Identity.Name -RunLevel Highest;
    $settings = New-ScheduledTaskSettingsSet;
    $trigger = New-ScheduledTaskTrigger -AtLogOn;
    $task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings;

    Register-ScheduledTask -TaskName $scheduledTaskContinueOnLogon -InputObject $task > $null;
}

Function Set-UltimatePerformancePowerPlan(
    $guid) {
    If ($guid -ne 'e9a42b02-d5df-448d-aa00-03f14749eb61') {
        Return $guid;
    }

    $hasUltimatePerformancePlan = (POWERCFG /L | Where {
        $_.Contains('Ultimate Performance')
    }) -ne $null;

    If (!$hasUltimatePerformancePlan`
        -and $osCommonVersion -ge 1803) {
        #   https://www.howtogeek.com/368781/how-to-enable-ultimate-performance-power-plan-in-windows-10/

        POWERCFG /DUPLICATESCHEME 'e9a42b02-d5df-448d-aa00-03f14749eb61' > $null;
    }

    Return (POWERCFG /L | Where {
        $_.Contains('Ultimate Performance')
    }).Replace('Power Scheme GUID: ', $null).Replace('  (Ultimate Performance)', $null).Replace(' *', $null);
}

#   ========================================================================
#   Run
#   ========================================================================

If ((Get-ScheduledTask -TaskName $scheduledTaskContinueOnLogon -ErrorAction SilentlyContinue) -ne $null) {
    Unregister-ScheduledTask -TaskName $scheduledTaskContinueOnLogon -Confirm:$false > $null;
}

Disable-Uac;
Disable-Firewall;
Disable-Hibernation;
Disable-LockScreen;
Configure-ComputerName;
Configure-Hosts;
Configure-PowerPlan;
Configure-SslTls;
Configure-TimeZone;
Enable-MicrosoftUpdate;
Decrapify;
Remove-OneDrive;
Remove-User;
Schedule-PowerPlans;
Schedule-RebuildSearchIndex;
Schedule-Restart;
Set-PathPermissionsToEveryoneOnly;
Map-NetworkDrives;
Install-Software;

IPCONFIG /RELEASE > $null;
IPCONFIG /FLUSHDNS > $null;
IPCONFIG /RENEW > $null;
IPCONFIG /REGISTERDNS > $null;

$ProgressPreference = 'Continue';

If ($defaultExecutionPolicy) {
    Set-ExecutionPolicy -ExecutionPolicy Default -Force -Confirm:$false;
}

SHUTDOWN /R /T 0 /F > $null;
