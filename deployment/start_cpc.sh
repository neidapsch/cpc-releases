#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
  echo -e "\n================================================"
  echo "This script must be run with sudo."
  echo -e "================================================\n"
  exit 1
fi

if [ ! -d "charging-point-controller" ]; then
  mkdir charging-point-controller
fi

cd charging-point-controller || exit

echo -e "\n================================================"
echo "making sure everything needed is installed ... "
echo -e "================================================\n"

if ! [ -x "$(command -v docker)" ]; then
  echo "Docker is not installed. Installing Docker..."
  apt-get update
  apt-get install docker.io -y
  echo "!! Docker installed."
  echo "!! System needs to reboot in order to make sure Docker is running."
  echo "!! The system is rebooting in 5 seconds."
  sleep 5
  sudo systemctl reboot
else
  echo "* Docker is already installed"
fi

# Check if the Postgres Docker image is already pulled
if ! docker images | grep -q "postgres"; then
  # Pull the Postgres Docker image if it is not already pulled
  echo "Postgres Docker image not found. Pulling image from Docker hub..."
  docker pull postgres
else
  echo "* Postgres Docker image already pulled"
fi

# Check if the container is already running
if docker ps | grep -q 'postgres'; then
  echo "* Postgres container is already running"
else
  echo "-> Starting Postgres Docker container..."
  docker run --name postgres -e POSTGRES_PASSWORD=postgres -d -p 5432:5432 postgres
fi

# Check if the pgadmin Docker image is already pulled
if ! docker images | grep -q "dpage/pgadmin4"; then
  # Pull the pgadmin Docker image if it is not already pulled
  echo "pgadmin Docker image not found. Pulling image from Docker hub..."
  docker pull dpage/pgadmin4
else
  echo "* pgadmin Docker image already pulled"
fi

# Check if the container is already running
if docker ps | grep -q 'pgadmin'; then
  echo "* pgadmin container is already running"
else
  echo "-> Starting pgadmin Docker container..."
  docker run --name pgadmin -e PGADMIN_DEFAULT_EMAIL=neudorfer@duck.com -e PGADMIN_DEFAULT_PASSWORD=pgadmin -d -p 1234:1234 dpage/pgadmin4
fi

# Check if nginx is installed
if ! [ -x "$(command -v nginx)" ]; then
  sudo apt-get update
  sudo apt-get install nginx -y
else
  echo "* nginx is already installed"
fi

echo -e "\n================================================"
echo "Downloading latest release from GitHub...  "
echo -e "================================================"

if [ -f ".version" ]; then
  current_version=$(cat .version)
  echo "Current version: $current_version"
else
  current_version=""
  echo -e "No version found locally"
fi

# Get the latest release information from the GitHub API
latest_release_info=$(curl -s https://api.github.com/repos/neidapsch/cpc-releases/releases/latest)

# Extract the version number and download URL from the release information
latest_version=$(echo "$latest_release_info" | grep "tag_name" | cut -d '"' -f 4)
echo "Latest version: $latest_version"
download_url=$(echo "$latest_release_info" | grep "browser_download_url" | cut -d '"' -f 4)

# Compare the current and latest versions, and download the latest release if it's newer
if [ "$latest_version" != "$current_version" ] || [ -z "$current_version" ]; then
  echo -e "\n-> Newer version available, downloading..."

  # Delete the old version
  if [ -d "frontend" ]; then
    echo -e "\nRemoving old Frontend version ..."
    rm -rf frontend
  fi
  if [ -f "backend.sh" ]; then
    echo -e "Removing old Backend version ..."
    rm -rf backend
  fi

  wget -q "$download_url"
  unzip -q *.zip
  chmod +x ./backend/src/src
  rm *.zip

  echo "Moving the env file to the project root ... "
  sudo mv -f ./backend/src/env .

  echo "$latest_version" >.version
else
  echo -e "\n-> Software is up to date"
fi

echo -e "\n================================================"
echo "Setting up Frontend with nginx ... "
echo -e "================================================\n"
root_dir="/var/www/html"
server_name="$(hostname -I | awk '{print $1}')"

if [ -d "frontend" ]; then
  # Copy the frontend files to the nginx web root directory
  echo "* Copying frontend files to nginx web root..."
  cp -r frontend/dist/frontend/* /var/www/html/

  # Create the configuration file
  cat >"/etc/nginx/sites-available/$server_name" <<EOF
server {
    listen 80;
    server_name $server_name;
    root $root_dir;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF

  # Check if the symbolic link exists
  if [ -L "/etc/nginx/sites-enabled/$server_name" ]; then
    rm "/etc/nginx/sites-enabled/$server_name"
  fi
  ln -s "/etc/nginx/sites-available/$server_name" "/etc/nginx/sites-enabled/"

  # Restart nginx to pick up the changes
  echo "* Restarting nginx..."
  sudo systemctl restart nginx
else
  echo "Frontend directory not found. Skipping nginx configuration."
fi

echo -e "\n================================================"
echo "IP address of this machine: $server_name"
echo "================================================"

echo -e "\n================================================"
echo "Starting the Backend ... "
echo -e "================================================\n"
sudo ./backend/src/src
