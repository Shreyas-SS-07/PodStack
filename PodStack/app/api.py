#!/usr/bin/env python3
"""
PodStack Backend API Service (Service #2 of 3)
RH134 Ch 6, 14, 17 | RH124 Ch 16
Provides persistent transaction ledger and microservice telemetry on port 8081.
"""

import os
import json
import time
import datetime
from flask import Flask, jsonify, request

app = Flask(__name__)

API_DATA_FILE = "/data/api_records.json"
START_TIME = time.time()


def load_records():
    try:
        if os.path.exists(API_DATA_FILE):
            with open(API_DATA_FILE, "r") as f:
                return json.load(f)
    except Exception:
        pass
    return []


def save_records(records):
    os.makedirs(os.path.dirname(API_DATA_FILE), exist_ok=True)
    with open(API_DATA_FILE, "w") as f:
        json.dump(records, f, indent=2)


@app.route("/")
def index():
    return jsonify({
        "service": "podstack-api",
        "role": "Backend Business Logic & Transaction Service",
        "port": 8081,
        "status": "online",
        "running_as_uid": os.getuid(),
        "persistent_records": len(load_records()),
        "uptime_seconds": int(time.time() - START_TIME)
    })


@app.route("/health")
def health():
    return jsonify({
        "status": "healthy",
        "service": "podstack-api",
        "records_count": len(load_records())
    })


@app.route("/api/records", methods=["GET", "POST"])
def records():
    current = load_records()
    if request.method == "POST":
        payload = request.get_json() or {}
        new_record = {
            "id": len(current) + 1,
            "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "payload": payload,
            "worker_uid": os.getuid()
        }
        current.append(new_record)
        save_records(current)
        return jsonify({"status": "created", "record": new_record}), 201
    return jsonify({"total": len(current), "records": current})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081)
