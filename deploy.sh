#!/bin/bash
 
# ---  User Input ---
 
# Ask for domain name (optional)
read -p "Enter your domain name (leave blank if not using a domain): " domain_name
 
# Ask for the GitHub repository URL
read -p "Enter your GitHub repository URL: " repo_url
 
# --- Install Packages ---
 
sudo apt update
sudo apt install apache2 python3-pip npm git -y
 
# Install Vue.js CLI
sudo npm install -g @vue/cli
 
# --- Create Project Directories ---
 
mkdir -p /var/www/html/app-detection/frontend
 
# --- Install Flask and Dependencies ---
 
cd /var/www/html/app-detection
pip3 install flask sqlite3
 
# --- Install Vue.js Project ---
 
cd frontend
vue create .
 
# --- Copy Code from GitHub ---
 
# Flask application code
cd /var/www/html/app-detection
git clone $repo_url
mv $repo_url/* .
rm -rf $repo_url
 
# Vue.js template
cd frontend
wget -O public/index.html https://raw.githubusercontent.com/your-github-username/your-repo/main/index.html
wget -O src/main.js https://raw.githubusercontent.com/your-github-username/your-repo/main/main.js
 
# --- Configure Apache ---
 
sudo a2enmod rewrite headers
 
# Create a virtual host (if a domain name was provided)
if [[ -n "$domain_name" ]]; then
  sudo tee /etc/apache2/sites-available/$domain_name.conf <<EOF
<VirtualHost *:80>
    ServerName $domain_name
    ServerAlias www.$domain_name
 
    DocumentRoot /var/www/html/app-detection
    <Directory /var/www/html/app-detection>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
 
  sudo a2ensite $domain_name.conf
fi
 
# Restart Apache
sudo systemctl restart apache2
 
# --- Build Vue.js Application ---
 
cd frontend
npm run build
 
# --- Move Vue.js Build to Apache Directory ---
 
mv dist/* /var/www/html/app-detection
 
# --- Set up nftables Table ---
 
sudo nft add table inet filter {
    prerouting {
        type filter hook prerouting priority filter; policy accept;
    }
}
 
# --- Start the Flask Application ---
 
cd /var/www/html/app-detection
nohup python3 app.py &
 
# --- Success Message ---
 
echo "Application detection system deployed successfully!"
