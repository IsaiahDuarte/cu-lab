# cu-lab

### Quick Setup

The following installs a Windows Server 2022 and Windows 11 agent with RTDX, EdgeDX, Scoutbees, and Active Directory:
1. Download the repo
2. Copy the ./AutomatedLab/ConfigExamples/MacroPlusCULab.json to ./AutomatedLab
3. Fill in DEXKey, DEVREGCODE, TENANT and replcae the DomainName on each VM with the desired domain name
4. If you don't have Hyper-V, run the following command in an elevated powershell `Enable-WindowsOptionalFeature -FeatureName 'Microsoft-Hyper-V' -Online -All` and reboot
5. Download Windows Server 2022 from [Microsoft](https://www.microsoft.com/evalcenter/download-windows-server-2022)
6. Download Windows 11 from [Microsoft](https://www.microsoft.com/en-us/software-download/windows11)
7. Download ControlUpConsole.exe from [ControlUp](https://www.controlup.com/download-center/)
8. Download EdgeDX Agent Manager MSI from your [tenant](https://support.controlup.com/docs/edge-dx-agent-installation#download-and-install-the-edge-dx-agent)
9. Download the Scoutbees Custom Hive from your [dashboard](https://support.controlup.com/docs/installing-custom-hives#install-a-custom-hive)
10. Open admin powershell, cd to the repo, and run `. ./AutomatedLab/New-CULab.ps1 -ConfigPath ./MacroPlusCULab.json`
Note: This can take up to an hour depending on your device. It will be faster for new labs since the OS Images are built.

AutomatedLab documentation can be found [here](https://automatedlab.org/)
