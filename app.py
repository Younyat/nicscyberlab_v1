#!/usr/bin/env python3
import json
import os
from flask import Flask, jsonify, request, Response

app = Flask(__name__)

# Simple file-backed store for instance tools
TOOLS_STORE_PATH = os.path.join(os.path.dirname(__file__), 'state', 'tools_store.json')
os.makedirs(os.path.join(os.path.dirname(__file__), 'state'), exist_ok=True)

def _read_tools_store():
    if not os.path.exists(TOOLS_STORE_PATH):
        return {}
    try:
        with open(TOOLS_STORE_PATH, 'r') as f:
            return json.load(f)
    except Exception:
        return {}

def _write_tools_store(data):
    with open(TOOLS_STORE_PATH, 'w') as f:
        json.dump(data, f, indent=2)


@app.route('/')
def index():
    return jsonify({"status": "ok", "service": "nicscyberlab-dashboard"})


@app.route('/_health')
def health():
    return jsonify({"status": "healthy"})


@app.route('/api/health')
def api_health():
    return jsonify({"status": "ok", "api": "v1"})


@app.route('/api/openstack/instances')
def api_instances():
    # Minimal endpoint: try to read scenario state if exists
    state_path = os.path.join(os.path.dirname(__file__), 'scenario', 'state', 'summary.json')
    if os.path.exists(state_path):
        try:
            with open(state_path, 'r') as f:
                data = json.load(f)
            return jsonify({"instances": data.get('instances', [])})
        except Exception:
            return jsonify({"instances": []})
    return jsonify({"instances": []})


@app.route('/api/get_tools_for_instance')
def api_get_tools_for_instance():
    instance = request.args.get('instance')
    store = _read_tools_store()
    tools = store.get(instance, {}).get('tools', []) if instance else []
    return jsonify({"tools": tools})


@app.route('/api/add_tool_to_instance', methods=['POST'])
def api_add_tool_to_instance():
    payload = request.get_json() or {}
    instance = payload.get('instance')
    tools = payload.get('tools', [])
    if not instance:
        return jsonify({"status": "error", "msg": "instance required"}), 400
    store = _read_tools_store()
    entry = store.get(instance, {})
    entry['tools'] = tools
    store[instance] = entry
    _write_tools_store(store)
    return jsonify({"status": "ok"})


@app.route('/api/install_tools', methods=['POST'])
def api_install_tools():
    # Minimal streaming endpoint that simulates installation progress
    payload = request.get_json() or {}
    instance = payload.get('instance')
    tools = payload.get('tools', [])

    def generate():
        yield 'data: Starting installation...\n\n'
        for t in tools:
            yield f'data: Installing {t}...\n\n'
            # simulate work
            import time
            time.sleep(0.5)
            yield f'data: {t} installed successfully\n\n'
        # mark tools as installed
        if instance:
            store = _read_tools_store()
            entry = store.get(instance, {})
            installed = entry.get('installed', [])
            for t in tools:
                if t not in installed:
                    installed.append(t)
            entry['installed'] = installed
            entry['tools'] = list(set(entry.get('tools', []) + tools))
            store[instance] = entry
            _write_tools_store(store)

        yield 'data: Installation completed\n\n'

    return Response(generate(), mimetype='text/event-stream')


@app.route('/api/uninstall_tool_from_instance', methods=['POST'])
def api_uninstall_tool_from_instance():
    payload = request.get_json() or {}
    instance = payload.get('instance')
    tool = payload.get('tool')
    if not instance or not tool:
        return jsonify({"status": "error", "msg": "instance and tool required"}), 400
    store = _read_tools_store()
    entry = store.get(instance, {})
    tools = entry.get('tools', [])
    installed = entry.get('installed', [])
    if tool in tools:
        tools = [t for t in tools if t != tool]
    if tool in installed:
        installed = [t for t in installed if t != tool]
    entry['tools'] = tools
    entry['installed'] = installed
    store[instance] = entry
    _write_tools_store(store)
    return jsonify({"status": "success", "exit_code": 0})


if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5001)
