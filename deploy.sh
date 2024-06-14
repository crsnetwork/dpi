#!/bin/bash

# --- Configuration Variables ---
APP_NAME="network_dashboard"
ENV_NAME="${APP_NAME}_env"
APP_DIR="/var/www/${APP_NAME}"
Nginx_CONFIG_DIR="/etc/nginx/sites-available"
Nginx_CONFIG_FILE="${APP_NAME}.conf"
NFtables_CONFIG_FILE="/etc/nftables.conf"
INTERFACE_MAPPINGS_FILE="${APP_DIR}/interface_mappings.json"

# --- Function to create directories with permissions ---
create_dir() {
  mkdir -p "$1"
  chown www-data:www-data "$1"
  chmod 755 "$1"
}

# --- Function to create files with permissions ---
create_file() {
  echo "$2" > "$1"
  chown www-data:www-data "$1"
  chmod 644 "$1"
}

# --- Function to enable a service at boot ---
enable_service() {
  sudo systemctl enable "$1"
}

# --- Main Deployment Script ---

# 1. Update and upgrade the system
sudo apt update
sudo apt upgrade -y

# 2. Install necessary packages
sudo apt install -y python3 python3-pip python3-venv nginx uwsgi uwsgi-plugin-python3

# 3. Create application directory
create_dir "${APP_DIR}"

# 4. Create virtual environment
python3 -m venv "${APP_DIR}/${ENV_NAME}"

# 5. Activate the virtual environment
source "${APP_DIR}/${ENV_NAME}/bin/activate"

# 6. Install dependencies
pip install Flask plotly psutil dnspython

# 7. Create Flask application file (`app.py`)
create_file "${APP_DIR}/app.py" "
from flask import Flask, render_template, request, jsonify
import psutil
import json
import dns.resolver

app = Flask(__name__)

# Define a dictionary to store interface mappings
interface_mappings = {}

# Load interface mappings from a file (if available)
try:
    with open('${INTERFACE_MAPPINGS_FILE}', 'r') as f:
        interface_mappings = json.load(f)
except FileNotFoundError:
    pass  # File not found, use default mappings

# Define your application list (with common services)
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
    'youtube': 443,  # Assume HTTPS
    'facebook': 443, # Assume HTTPS
    'google': 443,   # Assume HTTPS
    'netflix': 443,  # Assume HTTPS
    'instagram': 443, # Assume HTTPS
    'twitter': 443,  # Assume HTTPS
    'spotify': 443,  # Assume HTTPS
    'amazon': 443,   # Assume HTTPS
    'dropbox': 443,  # Assume HTTPS
    # ... (Add more applications as needed) ...
}

def get_network_stats():
    \"\"\"Collects basic network statistics.\"\"\"
    net_io = psutil.net_io_counters()
    return {
        'bytes_sent': net_io.bytes_sent,
        'bytes_recv': net_io.bytes_recv,
        'packets_sent': net_io.packets_sent,
        'packets_recv': net_io.packets_recv,
    }

def get_app_traffic(interface):
    \"\"\"Collects traffic for specific applications on the given interface.\"\"\"
    app_traffic = {}
    for app_name, port in applications.items():
        # Use nftables to count traffic for the specified application and interface
        # (This requires more advanced nftables configuration and scripting)
        # ... (Use nftables to count traffic for the specified application and interface) ...
        app_traffic[app_name] = {'bytes_sent': 0, 'bytes_recv': 0} 
    return app_traffic

def get_domain_from_request(request):
    \"\"\"Extracts the domain name from the HTTP request.\"\"\"
    # This is a simplified example; a real-world solution might require more robust parsing
    try:
        host = request.headers['Host']
        domain = host.split(':')[0]
        return domain
    except KeyError:
        return None

def get_interface_for_domain(domain):
    \"\"\"Determines the interface to redirect traffic to based on the domain name.\"\"\"
    # This is a placeholder for your domain-to-interface mapping logic
    # ... (Implement your logic to map domains to interfaces) ...
    # For example, you could use a dictionary:
    # interface_mappings = {'netflix.com': 'eth1', 'youtube.com': 'eth2', ...}
    return interface_mappings.get(domain)

@app.route('/')
def index():
    \"\"\"Renders the main dashboard page.\"\"\"
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
    \"\"\"Provides data for the dashboard in JSON format.\"\"\"
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
    \"\"\"Updates interface mappings based on user input.\"\"\"
    new_mappings = request.get_json()
    # Update `interface_mappings` based on `new_mappings`
    # ... (Implement logic to update `interface_mappings` safely) ...
    # Save updated mappings to `interface_mappings.json`
    with open('${INTERFACE_MAPPINGS_FILE}', 'w') as f:
        json.dump(interface_mappings, f)
    return jsonify({'message': 'Mappings updated successfully!'})

if __name__ == '__main__':
    app.run(debug=True, host='127.0.0.1')
"

# 8. Create HTML template file (`templates/index.html`)
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
        // Function to update network stats chart
        function updateNetworkStats(data) {
            // Use Plotly to create a chart based on data.network_stats
            // ... (Implement Plotly chart creation logic) ...
        }

        // Function to update application traffic charts
        function updateAppTraffic(data) {
            // Use Plotly to create charts for each interface
            // based on data.app_traffic[interface]
            // ... (Implement Plotly chart creation logic) ...
        }

        // Fetch data from the API and update charts
        fetch('/api/data')
            .then(response => response.json())
            .then(data => {
                updateNetworkStats(data);
                updateAppTraffic(data);
            });

        // Handle form submission to update mappings
       