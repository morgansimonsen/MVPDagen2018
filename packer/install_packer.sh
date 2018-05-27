cd ~
curl https://releases.hashicorp.com/packer/1.2.3/packer_1.2.3_linux_amd64.zip -O -J -L
unzip ./packer_1.2.3_linux_amd64.zip -d /usr/local/packer
export PATH=$PATH:/usr/local/packer