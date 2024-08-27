#!/bin/bash

# Function to switch PHP version
switch_php_version() {
  local target_version=$1

  if [ -z "$target_version" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 7.4"
    exit 1
  fi

  # Validate target version (assuming 7.4, 8.3, and 8.4 are valid options)
  if [[ "$target_version" != "7.4" && "$target_version" != "8.3" && "$target_version" != "8.4" ]]; then
    echo "Error: Unsupported PHP version '$target_version'. Supported versions are 7.4, 8.3, 8.4."
    exit 1
  fi

  # Change the PHP version using update-alternatives
  if sudo update-alternatives --set php /usr/bin/php${target_version}; then
    # Verify the switch
    php_version=$(php -v | grep -oP "^PHP \K[^\s]+")
    if [[ "$php_version" == "$target_version"* ]]; then
      echo "Successfully switched to PHP $php_version"
    else
      echo "Failed to switch to PHP $target_version"
    fi
  else
    echo "Error: Could not switch to PHP $target_version!"
  fi
}

# Call the function with the argument passed to the script
switch_php_version "$1"
