# Groq Audio Transcription API Specification

## Transcription Endpoint

- **Endpoint:** `https://api.groq.com/openai/v1/audio/transcriptions`
- **Method:** `POST`
- **Content-Type:** `multipart/form-data`
- **Model:** `whisper-large-v3-turbo` (or `whisper-large-v3`)

## cURL Request Example

```bash
curl -s https://api.groq.com/openai/v1/audio/transcriptions \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -F "file=@/path/to/recording.wav" \
  -F "model=whisper-large-v3-turbo" \
  -F "response_format=json"
```

## JSON Response Schema

```json
{
  "text": "Transcribed spoken text content here."
}
```

## Parsing JSON Output

```bash
osascript -l JavaScript -e "JSON.parse(\`$RESPONSE\`).text"
```
