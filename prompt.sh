#!/bin/bash

# Check if the content is provided
if [ -z "$1" ]; then
  echo "Please provide the name of the Bible book as the first argument."
  exit 1
fi

# Define the SQLite database file
DB_FILE="api_results.db"

# Create a table in the SQLite database (if not exists)
sqlite3 $DB_FILE "CREATE TABLE IF NOT EXISTS api_responses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  response TEXT,
  request_date TEXT
);"

# Define the API endpoint
API_ENDPOINT="http://localhost:11434/api/chat"

# Prepare the dynamic content using the $1 variable (Bible book)
CONTENT="Give me a 250 word summary of a random bible story, with quiz questions, 5 vocabulary words each in both English and Hebrew. Make this look like a workbook page; add page breaks via markdown and give the answer key on a separate page. Make the story from the book of $1."

# Prepare the API data with the dynamic content
API_DATA=$(cat <<EOF
{
  "model": "llama3.2",
  "messages": [
    {
      "role": "user",
      "content": "$CONTENT"
    }
  ],
  "stream": false
}
EOF
)

# Use curl to send the request to the API and capture the response
API_RESPONSE=$(curl -s -X POST $API_ENDPOINT -H "Content-Type: application/json" -d "$API_DATA")

# Extract only the relevant content from the API response (removing metadata)
CLEAN_RESPONSE=$(echo "$API_RESPONSE" | sed -n 's/.*"content":"\([^"]*\)".*/\1/p')

# Clean up the response by removing \n and special characters
CLEAN_RESPONSE=$(echo "$CLEAN_RESPONSE" | sed 's/\\n/\n\n/g' | sed 's/\\//g')

# Get the current timestamp (date and time)
CURRENT_TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Define instructions to prepend to the PDF with a page break after the instructions
INSTRUCTIONS="### Instructions\n\n1. Read the story carefully.\n\n2. Answer the quiz questions.\n\n3. Use the answer key provided at the end to check your answers.\n\n4. Review the vocabulary words in both English and Hebrew.\n\n\\newpage\n\n"

# Define the answer key section with a page break before it
ANSWER_KEY="\n\n\\newpage\n\n### Answer Key\n\nHere you will find the correct answers to the quiz questions.\n\n1. The first thing God created was the earth.\n2. God put humans in the Garden of Eden to give them a home.\n3. The name of the forbidden tree was the Tree of Knowledge.\n\n"

# Save the instructions, cleaned API response, and the answer key to a text file named after the Bible book
TEXT_FILENAME="${1,,}_response_$CURRENT_TIMESTAMP.txt"  # Convert $1 to lowercase for filenames
echo -e "$INSTRUCTIONS$CLEAN_RESPONSE$ANSWER_KEY" > "$TEXT_FILENAME"

# Insert the cleaned response and current timestamp into the SQLite database
sqlite3 $DB_FILE "INSERT INTO api_responses (response, request_date) VALUES ('$CLEAN_RESPONSE', '$CURRENT_TIMESTAMP');"

# Convert the text file to a PDF using Pandoc, naming the PDF file after the provided Bible book
PDF_FILENAME="${1,,}_response_$CURRENT_TIMESTAMP.pdf"  # Convert $1 to lowercase for filenames
pandoc "$TEXT_FILENAME" -o "$PDF_FILENAME"

# Output success message
echo "API response saved to '$TEXT_FILENAME' and converted to PDF '$PDF_FILENAME'."