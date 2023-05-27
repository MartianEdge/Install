#!/bin/bash

# Install Node.js
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt-get install -y nodejs

# Get into the right folder
cd /etc

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Wings
# For info purposes: The panel handles the transferring of servers off and on, not any of our daemons
mkdir -p /etc/pterodactyl
curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
chmod u+x /usr/local/bin/wings
apt install certbot -y
# Once Wings is online and connected as an Edge cluster, the MCX handler will be installed as a container and deployed

# Soon: Automate the edge cluster installation system, for now someone needs to manually generate a command and connect it

# Create a directory for the app
mkdir martian
cd martian

# Create the folder for Edge
mkdir edge
cd edge

# Initialize a new npm project
npm init -y

# Install required packages
npm install express systeminformation

# Create the app file for Info Daemon (we need this info to calculate earnings)
echo "
const express = require('express');
const si = require('systeminformation');

const app = express();
const port = 7001;

app.get('/', async (req, res) => {
  try {
    const [ram, cpu] = await Promise.all([si.mem(), si.cpu()]);
    const systemInfo = {
      status: 'online',
      ram: (ram.total / 1024 / 1024 / 1024).toFixed(2) + ' GB',
      cpu: cpu.currentspeed,
      cpuModel: \`\${cpu.manufacturer} \${cpu.brand} \${cpu.family} \${cpu.model}\`,
      // Add other system information properties here
    };
    res.json(systemInfo);
  } catch (error) {
    console.error('Error retrieving system information:', error);
    res.status(500).send('Internal Server Error');
  }
});

app.listen(port, () => {
  console.log(\`Edge information daemon is running on port \${port}\`);
});
" > app.js

# Build a Docker image for the app
echo "
FROM node:14
WORKDIR /app
COPY package*.json ./
RUN npm install --only=production
COPY . .
EXPOSE 7001
CMD [\"node\", \"app.js\"]
" > Dockerfile

# Build and run the Docker container
sudo docker build -t nodejs-app .
sudo docker run -d -p 7001:7001 --name nodejs-container nodejs-app
