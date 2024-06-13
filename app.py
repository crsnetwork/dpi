from flask import Flask, render_template, request, jsonify
import subprocess
import json
import sqlite3
 
app = Flask(__name__)
 
# Database setup
db = sqlite3.connect("app_config.db")
cursor = db.cursor()
 
# Create table if it doesn't exist
cursor.execute("""
    CREATE TABLE IF NOT EXISTS application_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        interface TEXT NOT NULL
    )
""")
db.commit()
 
@app.route("/")
def index():
    return render_template("index.html")
 
@app.route("/get_applications")
def get_applications():
    cursor.execute("SELECT name, interface FROM application_rules")
    applications = cursor.fetchall()
    return jsonify(applications)
 
@app.route("/add_rule", methods=["POST"])
def add_rule():
    name = request.form["name"]
    interface = request.form["interface"]
 
    cursor.execute(
        "INSERT INTO application_rules (name, interface) VALUES (?, ?)",
        (name, interface),
    )
    db.commit()
 
    return "Rule added successfully"
 
@app.route("/delete_rule", methods=["POST"])
def delete_rule():
    id = request.form["id"]
 
    cursor.execute("DELETE FROM application_rules WHERE id = ?", (id,))
    db.commit()
 
    return "Rule deleted successfully"
 
@app.route("/update_rules")
def update_rules():
    applications = request.get_json()
 
    for app in applications:
        cursor.execute(
            "UPDATE application_rules SET interface = ? WHERE name = ?",
            (app["interface"], app["name"]),
        )
    db.commit()
 
    return "Rules updated successfully"
 
@app.route("/get_ports")
def get_ports():
    # Load port mapping from config.json
    with open("config.json", "r") as f:
        config = json.load(f)
    ports = config.get("ports", {})
    return jsonify(ports)
 
@app.route("/get_interfaces")
def get_interfaces():
    # Get available interfaces (replace with appropriate system commands)
    interfaces = subprocess.check_output(
        ["ip", "-o", "link", "show"], text=True
    ).splitlines()
    interfaces = [
        interface.split()[1].strip(":")
        for interface in interfaces
        if "state UP" in interface
    ]
    return jsonify(interfaces)
 
if __name__ == "__main__":
    app.run(debug=True)

