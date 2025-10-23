# WebSocket Audio Streamer Client

A React application that streams microphone audio to a WebSocket server and plays back audio responses in PCM16 24kHz format.

## Features

- **Real-time microphone audio streaming** - Captures and streams audio to server
- **Audio playback** - Receives and plays audio responses from server
- **WebSocket connection** - Bidirectional audio communication with automatic reconnection
- **Audio waveform visualization** - Real-time oscilloscope display using Canvas
- **PCM16 format at 24kHz** - High-quality audio processing
- **Connection status indicator** - Visual feedback for connection state

## Prerequisites

- Node.js (v14 or higher)
- A running WebSocket server at `ws://127.0.0.1:5613`

## Installation

```bash
npm install
```

## Development

Start the development server:

```bash
npm run dev
```

The application will be available at `http://localhost:5173`

## Usage

1. Make sure your WebSocket server is running at `ws://127.0.0.1:5613`
2. Open the application in your browser
3. Grant microphone permissions when prompted
4. Click the "Start" button to begin streaming audio
5. Click "Stop" to end the stream

## Audio Format

- **Format**: PCM16 (16-bit signed integer)
- **Sample Rate**: 24000 Hz (24kHz)
- **Channels**: Mono (1 channel)
- **Encoding**: Base64

## WebSocket Message Format

### Sending Audio Data (to server)

```json
{
  "event": "data",
  "payload": "<base64-encoded-pcm16-audio>"
}
```

### Sending Finish Event (to server)

```json
{
  "event": "finish"
}
```

### Receiving Audio Data (from server)

```json
{
  "type": "response.output_audio.delta",
  "event_id": "event_...",
  "response_id": "resp_...",
  "item_id": "item_...",
  "output_index": 0,
  "content_index": 0,
  "delta": "<base64-encoded-pcm16-audio>"
}
```

The client automatically decodes the `delta` field and plays back audio received from the server.

## Build for Production

```bash
npm run build
```

The production build will be in the `dist/` directory.

## Technologies

- **React** - UI framework
- **Vite** - Build tool and dev server
- **Web Audio API** - Audio capture, processing, and playback
- **Canvas API** - Real-time waveform visualization
- **WebSocket API** - Bidirectional real-time communication
- **MediaStream API** - Microphone access

All audio handling uses native browser APIs - no external dependencies!
