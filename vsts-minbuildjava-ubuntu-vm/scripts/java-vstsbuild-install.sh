#!/bin/sh

# Install Build Tools
sudo /bin/date +%H:%M:%S >> /home/badmin/install.progress.txt
echo "~~~ INSTALLING Build Agent for Java, Maven, Docker ~~~" >> /home/badmin/install.progress.txt

baseAgentName=$4

# Check if a prior installation exists
agentCount=0
basePath="/home/badmin/vsts-agent"

if [ -d "$basePath" ]
 then echo "Initial installation exists" >> /home/badmin/install.progress.txt
 while true; do
  let agentCount=$agentCount+1
  newPath="$basePath-$agentCount"
  if [ -f "$newPath" ]
   then
	continue
  else
   echo "Installing Agent $baseAgentName-$agentCount " >> /home/badmin/install.progress.txt
   agentFolder="$newPath"
   agentName="$baseAgentName-$agentCount"
   break
  fi
 done
else
  echo "Installing Agent $baseAgentName-$agentCount " >> /home/badmin/install.progress.txt
  agentFolder="$basePath"
  agentName="$baseAgentName"
fi

sudo /bin/date +%H:%M:%S >> /home/badmin/install.progress.txt

#update and upgrade your system
sudo apt-get -y update
sudo apt-get -y upgrade

#install the required packages if don't exist already
sudo apt-get -y install software-properties-common

#Install the default JDK
# sudo add-apt-repository -y ppa:openjdk-r/ppa
# sudo apt-get update 
# sudo apt-get install default-jdk

# Install Java
echo "Installing openjdk-8-jdk package" >> /home/badmin/install.progress.txt

sudo add-apt-repository -y ppa:openjdk-r/ppa
sudo apt-get -y update
sudo apt-get install -y openjdk-8-jdk
sudo apt-get -y update --fix-missing
sudo apt-get install -y openjdk-8-jdk

sudo ln -s /usr/lib/jvm/java-8-openjdk-amd64/ /usr/lib/jvm/default-java

sudo /bin/date +%H:%M:%S >> /home/badmin/install.progress.txt

# Install Java build tools
echo "Installing Maven package" >> /home/badmin/install.progress.txt
sudo apt-get -y install maven

sudo /bin/date +%H:%M:%S >> /home/badmin/install.progress.txt

# Install Docker
echo "Updating Git..." >> /home/badmin/install.progress.txt
sudo add-apt-repository -y ppa:git-core/ppa 1>/dev/null
sudo apt-get -qq -y update 1>/dev/null
sudo apt-get -qq -y install git 1>/dev/null

echo "Installing and configuring Docker..." >> /home/badmin/install.progress.txt
sudo apt-get -qq -y --no-install-recommends install curl apt-transport-https ca-certificates curl software-properties-common 1>/dev/null
curl -fsSL https://apt.dockerproject.org/gpg | sudo apt-key add - 1>/dev/null
sudo add-apt-repository "deb https://apt.dockerproject.org/repo/ ubuntu-$(lsb_release -cs) main"
sudo apt-get -qq -y update 1>/dev/null
sudo apt-get -qq -y install docker-engine 1>/dev/null
sudo groupadd -f docker
sudo adduser badmin docker 1>/dev/null

sudo /bin/date +%H:%M:%S >> /home/badmin/install.progress.txt

# Install Dotnet Core for Ubuntu 16.04
sudo wget https://dot.net/v1/dotnet-install.sh
sudo chmod 777 dotnet-install.sh
sudo ./dotnet-install.sh

# Download and Install VSTS Agent
# Check if the agent is already downloaded
if [ -f "/home/badmin/downloads/vsts-agent-linux-x64-2.138.5.tar.gz" ]
	then echo "Agent Installation file is already downloaded.."  >> /home/badmin/install.progress.txt
else
	echo "Agent Installation file ToBe Downloaded.."  >> /home/badmin/install.progress.txt

	sudo mkdir /home/badmin/downloads
	sudo mkdir /home/badmin/lib

	cd /home/badmin/downloads

	# Download the releases json file
	echo "Downloading VSTS Agent Releases file" >> /home/badmin/install.progress.txt
	curl -i -H "Accept: application/json" -H "Content-Type: application/json" https://api.github.com/repos/Microsoft/vsts-agent/releases >> releases.json

	# install JQ package for parsing JSON file
	sudo apt-get -y install jq

	# TODO: Parse Releases.json File to Get assets.json file for the lates vsts agent release
	echo "Parsing VSTS Agent Releases file" >> /home/badmin/install.progress.txt

	# TODO: Parse assets.json file to get the download URL for VSTS Linux Agent
	echo "Parsing VSTS Agent Assets file" >> /home/badmin/install.progress.txt

	# Download the vsts agent
	echo "Downloading VSTS Build agent package" >> /home/badmin/install.progress.txt
	sudo wget https://vstsagentpackage.azureedge.net/agent/2.138.5/vsts-agent-linux-x64-2.138.5.tar.gz
fi

# Install VSTS build agent dependencies 
echo "Installing VSTS Build agent dependencies" >> /home/badmin/install.progress.txt
sudo mkdir $agentFolder
cd $agentFolder
sudo tar xzf /home/badmin/downloads/vsts-agent-linux-x64-2.138.5.tar.gz 
sudo ./bin/installdependencies.sh -y

# echo "Installing libunwind8 and libcurl3 package" >> /home/badmin/install.progress.txt
# sudo apt-get -y install libunwind8 libcurl3
# sudo /bin/date +%H:%M:%S >> /home/badmin/install.progress.txt

# Download VSTS build agent and required security patch
sudo apt-get -y install libicu55

sudo /bin/date +%H:%M:%S >> /home/badmin/install.progress.txt

echo "Installing VSTS Build agent package" >> /home/badmin/install.progress.txt

# Install VSTS agent
echo "LANG=en_US.UTF-8" > .env
echo "export LANG=en_US.UTF-8" >> /home/badmin/.bashrc
export LANG=en_US.UTF-8
echo "JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> .env
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> /home/badmin/.bashrc
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
echo "JAVA_HOME_8_X64=/usr/lib/jvm/java-8-openjdk-amd64" >> .env
echo "export JAVA_HOME_8_X64=/usr/lib/jvm/java-8-openjdk-amd64" >> /home/badmin/.bashrc
export JAVA_HOME_8_X64=/usr/lib/jvm/java-8-openjdk-amd64

echo URL: $1 > /home/badmin/$agentFolder/vsts.install.log.txt 2>&1
echo PAT: HIDDEN >> /home/badmin/$agentFolder/vsts.install.log.txt 2>&1
echo Pool: $3 >> /home/badmin/$agentFolder/vsts.install.log.txt 2>&1
echo Agent: $4 >> /home/badmin/$agentFolder/vsts.install.log.txt 2>&1
echo User: badmin >> /home/badmin/$agentFolder/vsts.install.log.txt 2>&1
echo =============================== >> /home/badmin/$agentFolder/vsts.install.log.txt 2>&1
echo Running Agent.Listener >> /home/badmin/$agentFolder/vsts.install.log.txt 2>&1
sudo -E ./bin/Agent.Listener configure --unattended --runasservice --replace --acceptteeeula --url $1 --auth PAT --token $2 --pool $3 --agent $agentName >> /home/badmin/$agentFolder/vsts.install.log.txt 2>&1
echo =============================== >> /home/badmin/$agentFolder/vsts.install.log.txt 2>&1
echo Running ./svc.sh install >> /home/badmin/$agentFolder/vsts.install.log.txt 2>&1
sudo -E ./svc.sh install >> /home/badmin/$agentFolder/vsts.install.log.txt 2>&1
echo =============================== >> /home/badmin/$agentFolder/vsts.install.log.txt 2>&1
echo Running ./svc.sh start >> /home/badmin/$agentFolder/vsts.install.log.txt 2>&1

sudo -E ./svc.sh start >> /home/badmin/$agentFolder/vsts.install.log.txt 2>&1
echo =============================== >> /home/badmin/$agentFolder/vsts.install.log.txt 2>&1

sudo chown -R badmin.badmin .*

sudo /bin/date +%H:%M:%S >> /home/badmin/install.progress.txt

echo "ALL DONE!" >> /home/badmin/install.progress.txt
sudo /bin/date +%H:%M:%S >> /home/badmin/install.progress.txt
