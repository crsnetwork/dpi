#!/bin/bash

# --- Configuration Variables ---
APP_NAME="network_dashboard"
ENV_NAME="${APP_NAME}_env"
APP_DIR="/var/www/${APP_NAME}"
NGINX_CONFIG_DIR="/etc/nginx/sites-available"
NGINX_CONFIG_FILE="${APP_NAME}.conf"
NFTABLES_CONFIG_FILE="/etc/nftables.conf"
INTERFACE_MAPPINGS_FILE="${APP_DIR}/interface_mappings.json"
LOGFILE="/var/log/deploy.log"

# Redirect stdout and stderr to log file
exec > >(tee -a ${LOGFILE} ) 2>&1

# --- Helper Functions ---
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

create_dir() {
    log "Creating directory: $1"
    mkdir -p "$1"
    chown www-data:www-data "$1"
    chmod 755 "$1"
}

create_file() {
    log "Creating file: $1"
    echo "$2" > "$1"
    chown www-data:www-data "$1"
    chmod 644 "$1"
}

enable_service() {
    log "Enabling service: $1"
    sudo systemctl enable "$1"
}

# --- Main Deployment Script ---

log "Starting deployment script..."

# 1. Update and upgrade the system
log "Updating and upgrading the system..."
sudo apt update && sudo apt upgrade -y || {
    log "System update and upgrade failed."
    exit 1
}

# 2. Install necessary packages
log "Installing necessary packages..."
sudo apt install -y python3 python3-pip python3-venv nginx uwsgi uwsgi-plugin-python3 || {
    log "Failed to install necessary packages."
    exit 1
}

# 3. Stop any service that might be using port 80
log "Stopping services that might be using port 80..."
sudo systemctl stop apache2 || true
sudo systemctl stop nginx || true

# Kill any process that might be using port 80
log "Killing any process that might be using port 80..."
sudo fuser -k 80/tcp || true

# 4. Create application directory
create_dir "${APP_DIR}"

# 5. Create virtual environment
log "Creating virtual environment..."
python3 -m venv "${APP_DIR}/${ENV_NAME}" || {
    log "Failed to create virtual environment."
    exit 1
}

# 6. Activate the virtual environment
log "Activating virtual environment..."
source "${APP_DIR}/${ENV_NAME}/bin/activate" || {
    log "Failed to activate virtual environment."
    exit 1
}

# 7. Install dependencies
log "Installing Python dependencies..."
pip install Flask plotly psutil dnspython || {
    log "Failed to install Python dependencies."
    exit 1
}

# 8. Create Flask application file (`app.py`)
create_file "${APP_DIR}/app.py" "
from flask import Flask, render_template, request, jsonify
import psutil
import json
import dns.resolver

app = Flask(__name__)

interface_mappings = {}
try:
    with open('${INTERFACE_MAPPINGS_FILE}', 'r') as f:
        interface_mappings = json.load(f)
except FileNotFoundError:
    pass

applications = {
    'http': 80,
    'https': 443,
    'ssh': 22,
    'dns': 53,
    'ftp': 21,
    'smtp': 25,
    'pop3': 110,
    'imap': 143,
    'telnet': 23,
    'mysql': 3306,
    'postgresql': 5432,
    'mongodb': 27017,
    'redis': 6379,
    'youtube': 443,
    'facebook': 443,
    'google': 443,
    'netflix': 443,
    'instagram': 443,
    'twitter': 443,
    'spotify': 443,
    'amazon': 443,
    'dropbox': 443,
}

def get_network_stats():
    net_io = psutil.net_io_counters()
    return {
        'bytes_sent': net_io.bytes_sent,
        'bytes_recv': net_io.bytes_recv,
        'packets_sent': net_io.packets_sent,
        'packets_recv': net_io.packets_recv,
    }

def get_app_traffic(interface):
    app_traffic = {}
    for app_name, port in applications.items():
        app_traffic[app_name] = {'bytes_sent': 0, 'bytes_recv': 0}
    return app_traffic

@app.route('/')
def index():
    data = {
        'network_stats': get_network_stats(),
        'interface_mappings': interface_mappings,
        'app_traffic': {}
    }
    for interface in interface_mappings:
        data['app_traffic'][interface] = get_app_traffic(interface)
    return render_template('index.html', data=data)

@app.route('/api/data')
def get_data():
    data = {
        'network_stats': get_network_stats(),
        'interface_mappings': interface_mappings,
        'app_traffic': {}
    }
    for interface in interface_mappings:
        data['app_traffic'][interface] = get_app_traffic(interface)
    return jsonify(data)

@app.route('/update_mappings', methods=['POST'])
def update_mappings():
    new_mappings = request.get_json()
    interface_mappings.update(new_mappings)
    with open('${INTERFACE_MAPPINGS_FILE}', 'w') as f:
        json.dump(interface_mappings, f)
    return jsonify({'message': 'Mappings updated successfully!'})

if __name__ == '__main__':
    app.run(debug=True, host='127.0.0.1')
"

# 9. Create HTML template file (`templates/index.html`)
create_dir "${APP_DIR}/templates"
create_file "${APP_DIR}/templates/index.html" "
<!DOCTYPE html>
<html>
<head>
    <title>Network Dashboard</title>
    <script src='https://cdn.plot.ly/plotly-latest.min.js'></script>
</head>
<body>
    <h1>Network Dashboard</h1>
    <h2>Network Statistics</h2>
    <div id='network-stats'></div>
    <h2>Application Traffic</h2>
    <div id='app-traffic'></div>
    <h2>Interface Mappings</h2>
    <form id='mapping-form'>
        {% for interface in interface_mappings %}
        <label for='{{ interface }}'>{{ interface }}</label>
        <select name='{{ interface }}'>
            {% for app_name in applications %}
            <option value='{{ app_name }}' {% if interface_mappings[interface] == app_name %}selected{% endif %}>{{ app_name }}</option>
            {% endfor %}
        </select>
        <br>
        {% endfor %}
        <button type='submit'>Update Mappings</button>
    </form>
    <script>
        function updateNetworkStats(data) {
        }
        function updateAppTraffic(data) {
        }
        fetch('/api/data')
            .then(response => response.json())
            .then(data => {
                updateNetworkStats(data);
                updateAppTraffic(data);
            });
    </script>
</body>
</html>
"

# 10. Check if NGINX config exists and back it up
log "Checking and backing up existing NGINX config..."
if [ -f "/etc/nginx/nginx.conf" ]; then
    sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    log "NGINX config backed up."
fi

# 11. Create NGINX configuration file
log "Creating NGINX configuration file..."
create_file "${NGINX_CONFIG_DIR}/${NGINX_CONFIG_FILE}" "
server {
    listen 80;
    server_name _;

    location / {
        include uwsgi_params;
        uwsgi_pass unix:/var/www/${APP_NAME}/${APP_NAME}.sock;
    }
}
"

# 12. Link NGINX configuration and restart service
log "Linking NGINX configuration and restarting service..."
sudo ln -s "${NGINX_CONFIG_DIR}/${NGINX_CONFIG_FILE}" /etc/nginx/sites-enabled/
sudo systemctl restart nginx || {
    log "Failed to restart NGINX. Checking status..."
    sudo systemctl status nginx
    exit 1
}

log "Deployment script completed successfully."
