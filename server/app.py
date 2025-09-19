import os
from flask import Flask, send_from_directory, request, make_response

app = Flask(__name__)

# Directory where update files are stored
UPDATES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'updates')

@app.route('/')
def index():
    """Simple index page with links to available files"""
    files = os.listdir(UPDATES_DIR)
    links = ''.join([f'<li><a href="/{file}">{file}</a></li>' for file in files])
    return f"""
    <html>
        <head><title>AppleAI Update Server</title></head>
        <body>
            <h1>AppleAI Update Server</h1>
            <p>Available files:</p>
            <ul>{links}</ul>
        </body>
    </html>
    """

@app.route('/<path:filename>')
def serve_file(filename):
    """Serve the requested file from the updates directory"""
    return send_from_directory(UPDATES_DIR, filename)

if __name__ == '__main__':
    # Create updates directory if it doesn't exist
    os.makedirs(UPDATES_DIR, exist_ok=True)
    
    # Get port from environment variable (Heroku sets this)
    port = int(os.environ.get('PORT', 8000))
    
    # Run the app
    app.run(host='0.0.0.0', port=port) 