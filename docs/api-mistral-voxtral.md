# Mistral AI Audio Transcription & Polish API Specification

## 1. Transcription Endpoint

- **Endpoint:** `https://api.mistral.ai/v1/audio/transcriptions`
- **Method:** `POST`
- **Content-Type:** `multipart/form-data`
- **Model:** `voxtral-mini-latest`

### cURL Request Example

```bash
curl -s --location 'https://api.mistral.ai/v1/audio/transcriptions' \
  --header "Authorization: Bearer $MISTRAL_API_KEY" \
  --form 'file=@"/path/to/recording.wav"' \
  --form 'model="voxtral-mini-latest"'
```

### JSON Response Schema

```json
{
  "text": "Transcribed spoken text content here."
}
```

---

## 2. LLM Text Polish Endpoint

- **Endpoint:** `https://api.mistral.ai/v1/chat/completions`
- **Method:** `POST`
- **Content-Type:** `application/json`
- **Model:** `mistral-small-latest`

### cURL Request Example

```bash
curl -s https://api.mistral.ai/v1/chat/completions \
  -H "Authorization: Bearer $MISTRAL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral-small-latest",
    "messages": [
      {
        "role": "system",
        "content": "You are a text cleanup assistant. Fix grammar, remove filler words (e.g., um, uh, like), eliminate speech repetitions, and fix punctuation. Return ONLY the polished text with no introduction or markdown formatting."
      },
      {
        "role": "user",
        "content": "'"$RAW_TRANSCRIPTION"'"
      }
    ],
    "temperature": 0.2
  }'
```

### Response Parsing (JXA / osascript)

```bash
RESPONSE=$(cat response.json)
osascript -l JavaScript -e "JSON.parse(\`$RESPONSE\`).choices[0].message.content.trim()"
```
