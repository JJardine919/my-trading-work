from flask import Flask, jsonify, request
from flask_cors import CORS
import json
import os
import requests

app = Flask(__name__)
CORS(app)

# Load Anthropic API key from anthropic_key.txt file
def load_anthropic_key():
    if os.path.exists('anthropic_key.txt'):
        with open('anthropic_key.txt', 'r') as f:
            return f.read().strip()
    return os.getenv('ANTHROPIC_API_KEY', '')

ANTHROPIC_API_KEY = load_anthropic_key()
ANTHROPIC_ENDPOINT = "https://api.anthropic.com/v1/messages"

def convert_openai_to_anthropic(openai_request):
    """Converts OpenAI format request to Anthropic format"""
    messages = []

    # Extract messages from OpenAI format
    for msg in openai_request.get('messages', []):
        role = msg.get('role')
        content = msg.get('content', '')

        # Anthropic uses 'user' and 'assistant', not 'system'
        if role == 'system':
            # Prepend system message to first user message
            if messages and messages[-1]['role'] == 'user':
                messages[-1]['content'] = content + "\n\n" + messages[-1]['content']
            else:
                messages.append({'role': 'user', 'content': content})
        else:
            messages.append({'role': role, 'content': content})

    # Build Anthropic request
    anthropic_request = {
        'model': 'claude-3-5-sonnet-20241022',  # Using Claude 3.5 Sonnet
        'max_tokens': openai_request.get('max_tokens', 1024),
        'messages': messages
    }

    return anthropic_request

def convert_anthropic_to_openai(anthropic_response):
    """Converts Anthropic format response to OpenAI format"""
    content = ""

    # Extract content from Anthropic response
    if 'content' in anthropic_response:
        for block in anthropic_response['content']:
            if block.get('type') == 'text':
                content += block.get('text', '')

    # Build OpenAI-format response
    openai_response = {
        'choices': [{
            'message': {
                'role': 'assistant',
                'content': content
            },
            'finish_reason': 'stop'
        }],
        'usage': {
            'prompt_tokens': anthropic_response.get('usage', {}).get('input_tokens', 0),
            'completion_tokens': anthropic_response.get('usage', {}).get('output_tokens', 0),
            'total_tokens': (anthropic_response.get('usage', {}).get('input_tokens', 0) +
                           anthropic_response.get('usage', {}).get('output_tokens', 0))
        }
    }

    return openai_response

@app.route('/chat', methods=['POST', 'OPTIONS'])
def handle_chat():
    """Forwards chat requests to Anthropic API (Claude)"""
    if request.method == 'OPTIONS':
        return jsonify(success=True)

    try:
        # Get the request from MT5 EA (OpenAI format)
        ea_request = request.get_json()
        print(f"➡️  Request from EA (OpenAI format)")

        # Convert to Anthropic format
        anthropic_request = convert_openai_to_anthropic(ea_request)
        print(f"🔄 Converted to Anthropic format")

        # Forward to Anthropic
        headers = {
            "x-api-key": ANTHROPIC_API_KEY,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json"
        }

        response = requests.post(
            ANTHROPIC_ENDPOINT,
            headers=headers,
            json=anthropic_request,
            timeout=30
        )

        if response.status_code == 200:
            anthropic_response = response.json()
            print(f"✅ Claude responded successfully")

            # Convert back to OpenAI format for EA
            openai_format = convert_anthropic_to_openai(anthropic_response)
            return jsonify(openai_format)
        else:
            error_msg = f"Anthropic API error: {response.status_code} - {response.text}"
            print(f"❌ {error_msg}")
            return jsonify({"error": error_msg}), response.status_code

    except Exception as e:
        error_msg = f"Relay error: {str(e)}"
        print(f"❌ {error_msg}")
        import traceback
        traceback.print_exc()
        return jsonify({"error": error_msg}), 500

if __name__ == '__main__':
    print("🚀 Starting Anthropic (Claude) Relay Server...")
    print(f"📡 Listening on http://127.0.0.1:5000/chat")
    print(f"🤖 Using Claude 3.5 Sonnet for responses")
    if ANTHROPIC_API_KEY:
        print(f"🔑 Anthropic API Key loaded successfully")
    else:
        print("❌ WARNING: No Anthropic API key found. Create 'anthropic_key.txt' with your key.")
        print("📝 Get your key at: https://console.anthropic.com/settings/keys")
    app.run(host='0.0.0.0', port=5000, debug=True)
