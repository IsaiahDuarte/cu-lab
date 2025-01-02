# cu-lab

## Setup

### Install WSL
Please install [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) by doing:
```bash
wsl.exe --install ubuntu
wsl.exe --update
``` 
Note: This will prompt to set a username/password. You can open Ubuntu by searching in the start menu for "Ubuntu"

![wsl.exe install](images/{CD19FD20-9B45-478E-A0F1-F40B49793D90}.png)

### Install Docker CE and qemu-kvm
```bash
# Ensures not older packages are installed
sudo apt-get remove docker docker-engine docker.io containerd runc

# Ensure pre-requisites are installed
sudo apt-get update
sudo apt-get install \
ca-certificates \
curl \
gnupg \
lsb-release

# Adds docker apt key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Adds docker apt repository
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Refreshes apt repos
sudo apt-get update

# Installs Docker CE
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install qemu-kvm
sudo apt-get install qemu-kvm
```

Verify KVM support
```bash
sudo kvm-ok
```

You should see this
```bash
INFO: /dev/kvm exists
KVM acceleration can be used
```

### SSH - Optional
```bash
sudo apt install openssh-server

# View Ip
ip a | grep "eth0"

# SSH from host
ssh username@192.YourIp
```

### Clone the repository
While still in wsl ubuntu, clone the repo:
```bash
cd ~/
mkdir cu-lab -m 777
git clone https://github.com/IsaiahDuarte/cu-lab.git
cd ~/cu-lab
```

You can open this directory in file explorer through \\\\wsl.localhost\Ubuntu\home\oliver\cu-lab
Rename .env.exmaple to .env

### Prerequsites
Please follow the guide here - https://support.controlup.com/docs/create-your-controlup-organization

Once signed into DEX with the new org:
1. Start an EdgeDX trial
2. While waiting for provisioning, download and extract the [RT-DX Console](https://www.controlup.com/download-center/?type=console)
3. Copy the exe to the MonitorSetup folder. You can [open ubuntu's files through explorer](#clone-the-repository). ~/cu-lab/ControlUpConsole.exe
4. Reanme .env.example to .env if you haven't already
4. Once EdgeDX is done provisioning, go to the download section inside EdgeDX and copy the Tenant Name and Device Registration Code to the .env file
5. Download the linux (x64) agent and save to ~/cu-lab/edge/debian/install/avaceesipagent-linux

### Starting cu-lab
- Open Ubuntu and navigate to ~/cu-lab
- Run "sudo docker compose up -d"

At this point, you should see one device in EdgeDX and be able to access Windows Server and MacOS with these links:
Windows Server - http://localhost:8006
MacOS - http://localhost:8007

#### Windows Server 2022 
- Connect to Windows Server with http://localhost:8006 and wait till you get to the desktop (10-20 minutes)
- Once on the desktop, you can RDP into it using the ip returned from ubuntu: ip a | grep "eth0"
- Copy the monitorsetup folder from the repo and paste onto the desktop
- Open admin powershell and run this: Set-ExecutionPolicy Bypass
- Then run this: . "$ENV:USERPROFILE\Desktop\monitorsetup\deploy-ad.ps1" - you will be disconnected
- Wait a few minutes then reconnect the RDP session, then repeat the step above. You will be asked to set the DSRM password and reboot
- Run the script one more time to set the NTP settings

#### RT-DX Environment Setup
- Run the ControlUpConsole.exe inside of the monitorsetup folder and login to DEX with the new org
- Deploy the monitor through the monitor status

#### EdgeDX on Monitor
- You can deploy EdgeDX on the same windows server by following the steps in the download section in DEX

#### Scoutbees on Monitor
- Start a free trial in DEX
- Create a Custom Hive by downloading the installation and following the guide.

#### SecureDX on Monitor
- Start trial and follow stpes

#### MacOS - optional
Do this after Windows Server is setup to not take up too many resources.
Repo Guide [here](https://github.com/dockur/macos?tab=readme-ov-file#faq-)
- Connect to MacOS with http://localhost:8007
- Choose Disk Utility and then select the largest Apple Inc. VirtIO Block Media disk.
- Click the Erase button to format the disk to APFS, and give it any recognizable name you like.
- Close the current window and proceed the installation by clicking Reinstall macOS.
- When prompted where you want to install it, select the disk you just created previously.

Once its installed
- Follow the setup and avoid extra services (like signing into apple id)
- Launch Safari and go to app.controlup.com and sign in
- Download and install the EdgeDX Agent

## Repos Used
- https://github.com/dockur/macos
- https://github.com/dockur/windows

## License

[MIT](https://choosealicense.com/licenses/mit/)