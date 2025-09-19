# AppleAI Update Server

This is a simple Flask server for hosting AppleAI update files. It's designed to be deployed on Heroku.

## Local Setup

1. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

2. Run the server locally:
   ```
   python app.py
   ```

   The server will run on http://localhost:8000

## Heroku Deployment

1. Install the [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli)

2. Login to Heroku:
   ```
   heroku login
   ```

3. Create a new Heroku app:
   ```
   heroku create your-app-name
   ```

4. Deploy to Heroku:
   ```
   git init
   git add .
   git commit -m "Initial commit"
   git push heroku main
   ```

5. Open your app:
   ```
   heroku open
   ```

6. Update your appcast.xml to use your Heroku URL:
   - Replace `http://localhost:8000` with `https://your-app-name.herokuapp.com` 