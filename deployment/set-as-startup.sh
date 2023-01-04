if [ "$(id -u)" -ne 0 ]; then
  echo -e "\n================================================"
  echo "This script must be run with sudo."
  echo -e "================================================\n"
  exit 1
fi

# SETTING THE SCRIPT TO AUTOSTART
echo -e "\n================================================"
echo "Setting Script to autostart ... "
echo -e "================================================\n"

if [ ! -f /etc/systemd/system/start_cpc.service ]; then
  # Get the current path
  path=$(pwd)

  # Create the service file
  sudo bash -c "cat > /etc/systemd/system/start_cpc.service <<EOF
  [Unit]
  Description=Startup CPC Script
  After=multi-user.target

  [Service]
  Type=idle
  ExecStart=sudo $path/start_cpc.sh

  [Install]
  WantedBy=multi-user.target
  EOF"

  # Enable the service
  sudo systemctl enable start_cpc.service
  echo "* Set to autostart"

  # Start the service
  sudo systemctl start start_cpc.service
  echo "* Started the service"

else
  echo "* The autostart service is already configured."
  echo "* Restarting the service ..."
  sudo systemctl restart start_cpc.service
fi
