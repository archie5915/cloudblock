# Reference
End-to-end DNS encryption with DNS-based ad-blocking. Combines wireguard (DNS VPN), pihole (adblock), and cloudflared (DNS over HTTPS). Built in GCP with a low-cost instance using Terraform, Ansible, and Docker.

![Diagram](../diagram.png)

# Requirements
- A Google cloud account
- Follow Step-by-Step (compatible with Windows and Ubuntu)

# Step-by-Step 
Mac Users install (home)brew, then terraform, git, cloud cli.
```
#########
## Mac ##
#########
# Launch terminal

# Install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Ensure brew up-to-date
brew update

# Install terraform git
brew install terraform git

# Download gcp cli (64-bit) - see latest versions and alternative architectures @ https://cloud.google.com/sdk/docs/quickstart#mac
wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-341.0.0-darwin-x86_64.tar.gz 

# Extract
tar -xvf google-cloud-sdk-341.0.0-darwin-x86_64.tar.gz

# Install
./google-cloud-sdk/install.sh

# Add cli alias
echo "alias gcloud ~/google-cloud-sdk/bin/gcloud" >> ~/.bash_profile && source ~/.bash_profile

# Verify the three are installed
which terraform git gcloud

# Skip down to 'git clone' below
```

Windows Users install WSL (Windows Subsystem Linux)
```
#############################
## Windows Subsystem Linux ##
#############################
# Launch an ELEVATED Powershell prompt (right click -> Run as Administrator)

# Enable Windows Subsystem Linux
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

# Reboot your Windows PC
shutdown /r /t 5

# After reboot, launch a REGULAR Powershell prompt (left click).
# Do NOT proceed with an ELEVATED Powershell prompt.

# Download the Ubuntu 2204 package from Microsoft
curl.exe -L -o ubuntu-2204.AppxBundle https://aka.ms/wslubuntu2204
 
# Rename the package
Rename-Item ubuntu-2204.AppxBundle ubuntu-2204.zip
 
# Expand the zip
Expand-Archive ubuntu-2204.zip ubuntu-2204
 
# Change to the zip directory
cd ubuntu-2204
 
# Execute the ubuntu 1804 installer
.\ubuntu2204.exe
 
# Create a username and password when prompted
```

Install Terraform, Git, and create an SSH key pair
```
#############################
##  Terraform + Git + SSH  ##
#############################
# Add terraform's apt key (enter previously created password at prompt)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
 
# Add terraform's apt repository
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
 
# Install terraform and git
sudo apt update && sudo apt -y install terraform git
 
# Clone the cloudblock project
git clone https://github.com/chadgeary/cloudblock

# Create SSH key pair (RETURN for defaults)
ssh-keygen
```

Install the GCP CLI and authenticate. A [GCP account](https://console.cloud.google.com/) is required to continue.
```
#############################
##           GCP           ##
#############################
# Open powershell and start WSL
wsl

# Change to home directory
cd ~

# Add the google cloud sdk repository
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# Install prerequisite packages
sudo apt -y install apt-transport-https ca-certificates gnupg

# Add the google cloud package key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

# Install the google cloud sdk package
sudo apt update && sudo apt -y install google-cloud-sdk

# Authenticate - copy link to browser, auth, and paste response. If prompted for a project - use an existing (if any exists) or create a new with some random name.
gcloud init

# Enable application-default login
gcloud auth application-default login --no-launch-browser

# Note the billing ID for the vars file
gcloud beta billing accounts list | grep True

# Note the gcp user (account) for the vars file
gcloud auth list

# Two notes for July 2021
# A max of three billing-linked projects are available while under the free tier.
# Google has replaced f1-micro with e2-micro as the always-free VM. This has more CPU and RAM.
```

Customize the deployment - See variables section below
```
# Change to the project's aws directory in powershell
cd ~/cloudblock/gcp/

# Open File Explorer in a separate window
# Navigate to gcp project directory - change \chad\ to your WSL username
%HOMEPATH%\ubuntu-2204\rootfs\home\chad\cloudblock\gcp

# Edit the gcp.tfvars file using notepad and save
```

Deploy
```
# In powershell's WSL window, change to the project's gcp directory
cd ~/cloudblock/gcp/

# Initialize terraform and apply the terraform state
terraform init
terraform apply -var-file="gcp.tfvars"

# If permissions errors appear, fix with the below command and re-run the terraform apply.
sudo chown $USER gcp.tfvars && chmod 600 gcp.tfvars

# Note the outputs from terraform after the apply completes

# Wait for the virtual machine to become ready (Ansible will setup the services for us)
```

Want to watch Ansible setup the virtual machine? SSH to the cloud instance - see the terraform output.
```
# Connect to the virtual machine via ssh
ssh ubuntu@<some ip address terraform told us about>

# Tail the cloudblock log file
tail -F /var/log/cloudblock.log
```

# Variables
Edit the vars file (gcp.tfvars) to customize the deployment, especially:

```
# ph_password
# password to access the pihole webui

# ssh_key
# a public SSH key for SSH access to the instance via user `ubuntu`.
# cat ~/.ssh/id_rsa.pub

# mgmt_cidr
# an IP range granted webUI and SSH access (without VPN). Also permitted PiHole DNS if dns_novpn = 1. 
# deploying from home? This should be your public IP address with a /32 suffix. 

# gcp_billing_account
# The billing ID for the google cloud account

# gcp_user
# The GCP user
```

# Post-Deployment
- See terraform output for VPN Client configuration files link and the Pihole WebUI address.

# Updates
- See the notes from `terraform output` for gcp-specific update instructions.
- Important note, if you are familiar with a traditional pihole deployment keep in mind cloudblock uses the docker container which does not follow the same
update path. Cloudblock follows the official pihole (and wireguard) container update instructions:
  - [Pihole](https://github.com/pi-hole/docker-pi-hole#upgrading-persistence-and-customizations)
  - [Wireguard](https://github.com/linuxserver/docker-wireguard)

# FAQs
- Want to reach the PiHole webUI while away?
  - Connect to the Wireguard VPN and browse to Pihole VPN IP in the terraform output ( by default, its https://172.18.0.5/admin/ - for older installations its http://172.18.0.3/admin/ ).

- Using an ISP with a dynamic IP (DHCP) and the IP address changed? Pihole webUI and SSH access will be blocked until the mgmt_cidr is updated.
  - Follow the steps below to quickly update the cloud firewall using terraform.

```
# Open Powershell and start WSL
wsl

# Change to the project directory
cd ~/cloudblock/gcp/

# Update the mgmt_cidr variable - be sure to replace change_me with your public IP address
sed -i -e "s#^mgmt_cidr = .*#mgmt_cidr = \"change_me/32\"#" gcp.tfvars

# Rerun terraform apply, terraform will update the cloud firewall rules
terraform apply -var-file="gcp.tfvars"
```
