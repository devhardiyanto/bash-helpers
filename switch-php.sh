#!/bin/bash

# Function to switch PHP version
switch_php_version() {
  local target_version=$1

  if [ -z "$target_version" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 7.4"
    exit 1
  fi

  # Validate target version
  if [[ "$target_version" != "7.4" && "$target_version" != "8.3" && "$target_version" != "8.4" ]]; then
    echo "Error: Unsupported PHP version '$target_version'. Supported versions are 7.4, 8.3, 8.4."
    exit 1
  fi

  # Identify the currently active PHP module (if any)
  current_php_module=$(a2query -m | grep "php" | grep "enabled" | awk '{print $1}')

  if [ -n "$current_php_module" ]; then
    echo "Disabling currently active PHP module: $current_php_module"
    sudo a2dismod $current_php_module
  else
    echo "No active PHP module found."
  fi

  # Enable the target PHP version
  if sudo a2enmod php${target_version}; then
    sudo update-alternatives --set php /usr/bin/php${target_version}
    sudo systemctl restart apache2

    # Verify the switch
    php_version=$(php -v | grep -oP "^PHP \K[^\s]+")
    if [[ "$php_version" == "$target_version"* ]]; then
      echo "Successfully switched to PHP $php_version"
    else
      echo "Failed to switch to PHP $target_version"
    fi
  else
    echo "Error: Module php${target_version} does not exist!"
  fi
}

# Call the function with the argument passed to the script
switch_php_version "$1"
