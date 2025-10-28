"""
Google Docs API Integration
Provides functionality to interact with Google Docs using OAuth2 authentication
"""

import os
import pickle
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# If modifying these scopes, delete the file token.json.
SCOPES = ['https://www.googleapis.com/auth/documents']


class GoogleDocsAPI:
    """Handles authentication and operations with Google Docs API"""

    def __init__(self, credentials_file='credentials.json', token_file='token.json'):
        """
        Initialize the Google Docs API client

        Args:
            credentials_file: Path to the OAuth2 credentials JSON file
            token_file: Path to store the authentication token
        """
        self.credentials_file = credentials_file
        self.token_file = token_file
        self.creds = None
        self.service = None

    def authenticate(self):
        """
        Authenticate with Google and create the service client

        Returns:
            bool: True if authentication successful, False otherwise
        """
        # Check if we have a valid token stored
        if os.path.exists(self.token_file):
            self.creds = Credentials.from_authorized_user_file(self.token_file, SCOPES)

        # If there are no (valid) credentials available, let the user log in
        if not self.creds or not self.creds.valid:
            if self.creds and self.creds.expired and self.creds.refresh_token:
                try:
                    self.creds.refresh(Request())
                except Exception as e:
                    print(f"Error refreshing token: {e}")
                    return False
            else:
                if not os.path.exists(self.credentials_file):
                    print(f"Error: Credentials file '{self.credentials_file}' not found!")
                    print("Please download your OAuth2 credentials from Google Cloud Console")
                    return False

                try:
                    flow = InstalledAppFlow.from_client_secrets_file(
                        self.credentials_file, SCOPES)
                    self.creds = flow.run_local_server(port=8080)
                except Exception as e:
                    print(f"Error during authentication: {e}")
                    return False

            # Save the credentials for the next run
            with open(self.token_file, 'w') as token:
                token.write(self.creds.to_json())

        try:
            self.service = build('docs', 'v1', credentials=self.creds)
            print("Successfully authenticated with Google Docs API")
            return True
        except Exception as e:
            print(f"Error building service: {e}")
            return False

    def create_document(self, title):
        """
        Create a new Google Doc

        Args:
            title: Title of the new document

        Returns:
            dict: Document metadata including document_id, or None on error
        """
        if not self.service:
            print("Error: Not authenticated. Call authenticate() first.")
            return None

        try:
            document = self.service.documents().create(body={'title': title}).execute()
            print(f"Created document: {document.get('title')}")
            print(f"Document ID: {document.get('documentId')}")
            return document
        except HttpError as error:
            print(f"An error occurred: {error}")
            return None

    def get_document(self, document_id):
        """
        Retrieve a Google Doc by ID

        Args:
            document_id: The ID of the document to retrieve

        Returns:
            dict: Document content and metadata, or None on error
        """
        if not self.service:
            print("Error: Not authenticated. Call authenticate() first.")
            return None

        try:
            document = self.service.documents().get(documentId=document_id).execute()
            print(f"Retrieved document: {document.get('title')}")
            return document
        except HttpError as error:
            print(f"An error occurred: {error}")
            return None

    def read_document_text(self, document_id):
        """
        Extract all text content from a Google Doc

        Args:
            document_id: The ID of the document to read

        Returns:
            str: All text content from the document, or None on error
        """
        document = self.get_document(document_id)
        if not document:
            return None

        content = document.get('body').get('content')
        text = []

        for element in content:
            if 'paragraph' in element:
                for text_run in element.get('paragraph').get('elements'):
                    if 'textRun' in text_run:
                        text.append(text_run.get('textRun').get('content'))

        return ''.join(text)

    def append_text(self, document_id, text):
        """
        Append text to the end of a Google Doc

        Args:
            document_id: The ID of the document
            text: Text to append

        Returns:
            bool: True if successful, False otherwise
        """
        if not self.service:
            print("Error: Not authenticated. Call authenticate() first.")
            return False

        try:
            requests = [
                {
                    'insertText': {
                        'location': {
                            'index': 1,
                        },
                        'text': text
                    }
                }
            ]

            result = self.service.documents().batchUpdate(
                documentId=document_id, body={'requests': requests}).execute()
            print(f"Successfully appended text to document")
            return True
        except HttpError as error:
            print(f"An error occurred: {error}")
            return False

    def update_document(self, document_id, requests):
        """
        Execute batch update requests on a document

        Args:
            document_id: The ID of the document
            requests: List of request objects (see Google Docs API documentation)

        Returns:
            dict: Response from the API, or None on error
        """
        if not self.service:
            print("Error: Not authenticated. Call authenticate() first.")
            return None

        try:
            result = self.service.documents().batchUpdate(
                documentId=document_id, body={'requests': requests}).execute()
            print(f"Successfully updated document")
            return result
        except HttpError as error:
            print(f"An error occurred: {error}")
            return None
