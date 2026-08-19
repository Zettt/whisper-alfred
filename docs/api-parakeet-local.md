# Local Parakeet Transcription API Specification

## Endpoint Architecture

Local Parakeet running via local HTTP server (e.g. standard OpenAI-compatible audio API wrapper on port `8080` or `11434`).

- **Endpoint:** `http://127.0.0.1:8080/v1/audio/transcriptions`
- **Method:** `POST`
- **Content-Type:** `multipart/form-data`
- **Model:** `parakeet`

## cURL Request Example

```bash
curl -s "${PARAKEET_ENDPOINT:-http://127.0.0.1:8080/v1/audio/transcriptions}" \
  -F "file=@/path/to/recording.wav" \
  -F "model=parakeet"
```

## JSON Response Schema

```json
{
  "text": "Local transcribed speech output."
}
```
