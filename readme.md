# cu-lab

### Quick Setup

The following installs a Windows Server 2022 and Windows 11 agent with RTDX, EdgeDX, Scoutbees, and Active Directory:
1. Download the repo
2. Copy the ./AutomatedLab/ConfigExamples/MacroPlusCULab.json to ./AutomatedLab
3. Fill in DEXKey, DEVREGCODE, TENANT and replcae the DomainName on each VM with the desired domain name
4. If you don't have Hyper-V, run the following command in an elevated powershell `Enable-WindowsOptionalFeature -FeatureName 'Microsoft-Hyper-V' -Online -All` and reboot
5. Open admin powershell, cd to the repo, and run `. ./AutomatedLab/New-CULab.ps1 -ConfigPath ./MacroPlusCULab.json`
Note: This can take up to an hour depending on your device.