# Google Docs API Setup Guide

This guide will help you set up Google Docs API with OAuth2 authentication (Client ID and Secret).

## Prerequisites

- Python 3.7 or higher
- A Google Account
- Google Cloud Console access

## Step 1: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click on the project dropdown at the top of the page
3. Click "New Project"
4. Enter a project name (e.g., "Trading Docs Integration")
5. Click "Create"

## Step 2: Enable Google Docs API

1. In the Google Cloud Console, navigate to "APIs & Services" > "Library"
2. Search for "Google Docs API"
3. Click on "Google Docs API"
4. Click "Enable"

## Step 3: Create OAuth2 Credentials

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth client ID"
3. If prompted, configure the OAuth consent screen:
   - Choose "External" (or "Internal" if you have a Google Workspace account)
   - Fill in the required fields:
     - App name: Your application name
     - User support email: Your email
     - Developer contact information: Your email
   - Click "Save and Continue"
   - On the Scopes page, click "Save and Continue" (we'll add scopes in code)
   - On Test users page, add your email as a test user
   - Click "Save and Continue"

4. Back on the Credentials page, click "Create Credentials" > "OAuth client ID"
5. Choose "Web application" as the application type
6. Enter a name (e.g., "Google Docs Client")
7. Under "Authorized redirect URIs", add: `http://localhost:8080/`
8. Click "Create"
9. A dialog will appear with your Client ID and Client Secret - **keep this open**

## Step 4: Download and Configure Credentials

1. On the credentials page, find your newly created OAuth 2.0 Client ID
2. Click the download icon (⬇️) to download the JSON file
3. Rename the downloaded file to `credentials.json`
4. Move `credentials.json` to your project directory: `/home/user/my-trading-work/`

**Alternative Method:** If you prefer to manually create the file:

1. Copy the `credentials.json.template` file to `credentials.json`
2. Replace `YOUR_CLIENT_ID_HERE` with your Client ID
3. Replace `YOUR_CLIENT_SECRET_HERE` with your Client Secret
4. Replace `your-project-id` with your actual project ID

## Step 5: Install Required Python Packages

```bash
pip install -r requirements.txt
```

Or install manually:

```bash
pip install google-auth-oauthlib google-auth-httplib2 google-api-python-client
```

## Step 6: First Time Authentication

Run the example script to authenticate:

```bash
python example_google_docs.py
```

This will:
1. Open your web browser
2. Ask you to log in to your Google Account
3. Ask you to authorize the application
4. Save an authentication token to `token.json`

After the first authentication, the token will be reused automatically.

## Security Notes

⚠️ **IMPORTANT:**

- Never commit `credentials.json` or `token.json` to version control
- These files contain sensitive authentication information
- They are already added to `.gitignore` for your protection
- Keep your Client Secret secure
- Regenerate credentials if they are ever compromised

## Troubleshooting

### "Access blocked: This app's request is invalid"

If you see this error, make sure:
1. You've added your email as a test user in the OAuth consent screen
2. The redirect URI `http://localhost:8080/` is added to your OAuth client

### "The file credentials.json is missing"

Make sure you've downloaded and placed the credentials file in the project root directory.

### Token expired errors

Delete `token.json` and run the script again to re-authenticate.

## Usage

See `example_google_docs.py` for usage examples, including:
- Creating new documents
- Reading document content
- Appending text to documents
- Batch updating documents

## API Documentation

For more advanced usage, see the official [Google Docs API documentation](https://developers.google.com/docs/api).
