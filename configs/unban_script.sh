#!/bin/sh

# This script runs continuously to unban IPs after 30 minutes
while true; do
    # Get current timestamp
    current_time=$(date +%s)
    
    # Read the banned_ips.conf file
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [ -z "$line" ] || [ "${line#\#}" != "$line" ]; then
            continue
        fi
        
        # Extract IP and ban time
        ip=$(echo "$line" | cut -d' ' -f1)
        ban_time=$(echo "$line" | cut -d'#' -f2)
        
        # If ban time exists and 30 minutes have passed
        if [ ! -z "$ban_time" ] && [ $((current_time - ban_time)) -ge 1800 ]; then
            # Remove the IP from banned_ips.conf
            sed -i "/$ip/d" /etc/nginx/banned_ips.conf
            echo "$(date): Unbanned IP $ip" >> /var/log/nginx/unban.log
        fi
    done < /etc/nginx/banned_ips.conf
    
    # Reload nginx configuration
    nginx -s reload
    
    # Sleep for 1 minute before next check
    sleep 60
done 