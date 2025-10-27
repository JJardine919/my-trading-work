from flask import Flask, jsonify, request
from flask_cors import CORS
import json
import os
import requests

app = Flask(__name__)
CORS(app)

# Load OpenAI API key from openai_key.txt file
def load_openai_key():
    if os.path.exists('openai_key.txt'):
        with open('openai_key.txt', 'r') as f:
            return f.read().strip()
    return os.getenv('OPENAI_API_KEY', '')

OPENAI_API_KEY = load_openai_key()
OPENAI_ENDPOINT = "https://api.openai.com/v1/chat/completions"

@app.route('/chat', methods=['POST', 'OPTIONS'])
def handle_chat():
    """Forwards chat requests to OpenAI API"""
    if request.method == 'OPTIONS':
        return jsonify(success=True)

    try:
        # Get the request from MT5 EA
        ea_request = request.get_json()
        print(f"➡️  Request from EA: {json.dumps(ea_request, indent=2)}")

        # Forward to OpenAI
        headers = {
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "Content-Type": "application/json"
        }

        response = requests.post(
            OPENAI_ENDPOINT,
            headers=headers,
            json=ea_request,
            timeout=30
        )

        if response.status_code == 200:
            openai_response = response.json()
            print(f"✅ OpenAI responded successfully")
            return jsonify(openai_response)
        else:
            error_msg = f"OpenAI API error: {response.status_code} - {response.text}"
            print(f"❌ {error_msg}")
            return jsonify({"error": error_msg}), response.status_code

    except Exception as e:
        error_msg = f"Relay error: {str(e)}"
        print(f"❌ {error_msg}")
        return jsonify({"error": error_msg}), 500

if __name__ == '__main__':
    print("🚀 Starting OpenAI Relay Server...")
    print(f"📡 Listening on http://127.0.0.1:5000/chat")
    if OPENAI_API_KEY:
        print(f"🔑 OpenAI API Key loaded successfully")
    else:
        print("❌ WARNING: No OpenAI API key found. Create 'openai_key.txt' with your key.")
    app.run(host='0.0.0.0', port=5000, debug=True)
