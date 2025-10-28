#!/usr/bin/env python3
"""
Example script demonstrating Google Docs API usage
"""

from google_docs_api import GoogleDocsAPI


def main():
    """Main function demonstrating various Google Docs API operations"""

    print("=" * 60)
    print("Google Docs API Example")
    print("=" * 60)

    # Initialize the API client
    docs_api = GoogleDocsAPI()

    # Authenticate
    print("\n1. Authenticating with Google...")
    if not docs_api.authenticate():
        print("Authentication failed. Please check your credentials.")
        return

    # Example 1: Create a new document
    print("\n2. Creating a new document...")
    document = docs_api.create_document("Trading Strategy Notes")

    if document:
        document_id = document.get('documentId')
        print(f"   Document URL: https://docs.google.com/document/d/{document_id}/edit")

        # Example 2: Append text to the document
        print("\n3. Adding content to the document...")
        trading_notes = """
Trading Strategy Notes
======================

Date: 2025-10-28

Market Analysis:
- Bitcoin showing strong support at $67,000
- Volume increasing on upward movements
- RSI indicating neutral momentum

Strategy Parameters:
- Entry: $67,500
- Stop Loss: $66,000
- Take Profit: $72,000
- Risk/Reward Ratio: 1:3

Notes:
- Monitor for breakout above resistance
- Watch for volume confirmation
- Consider scaling in position

"""
        docs_api.append_text(document_id, trading_notes)

        # Example 3: Read the document content
        print("\n4. Reading document content...")
        content = docs_api.read_document_text(document_id)
        print("   Document content:")
        print("   " + "-" * 40)
        print("   " + content[:200] + "..." if len(content) > 200 else "   " + content)
        print("   " + "-" * 40)

        # Example 4: Add formatted content using batch update
        print("\n5. Adding formatted content...")
        requests = [
            {
                'insertText': {
                    'location': {
                        'index': 1,
                    },
                    'text': '\n\n--- End of Notes ---\n'
                }
            }
        ]
        docs_api.update_document(document_id, requests)

        print(f"\n✓ All operations completed successfully!")
        print(f"✓ View your document at: https://docs.google.com/document/d/{document_id}/edit")

    else:
        print("Failed to create document")


def example_read_existing_document():
    """Example: Read an existing document by ID"""

    docs_api = GoogleDocsAPI()

    if not docs_api.authenticate():
        print("Authentication failed")
        return

    # Replace with your actual document ID
    document_id = "YOUR_DOCUMENT_ID_HERE"

    print(f"\nReading document: {document_id}")
    content = docs_api.read_document_text(document_id)

    if content:
        print("Document content:")
        print("-" * 60)
        print(content)
        print("-" * 60)


def example_append_to_existing():
    """Example: Append text to an existing document"""

    docs_api = GoogleDocsAPI()

    if not docs_api.authenticate():
        print("Authentication failed")
        return

    # Replace with your actual document ID
    document_id = "YOUR_DOCUMENT_ID_HERE"

    new_entry = f"""

Trade Entry - {__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
-------------------------------------------------------------
Symbol: BTC/USD
Action: BUY
Quantity: 0.1
Price: $67,500
Reason: Breakout above resistance with volume confirmation

"""

    print(f"\nAppending to document: {document_id}")
    if docs_api.append_text(document_id, new_entry):
        print("✓ Successfully added new entry")


if __name__ == "__main__":
    # Run the main example
    main()

    # Uncomment to run other examples:
    # example_read_existing_document()
    # example_append_to_existing()
