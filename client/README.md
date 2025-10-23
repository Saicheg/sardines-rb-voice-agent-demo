# WebSocket Audio Streamer Client

A React application that streams microphone audio to a WebSocket server in PCM16 24kHz format.

## Features

- Real-time microphone audio streaming
- WebSocket connection with automatic reconnection
- Audio waveform visualization
- PCM16 format at 24kHz sample rate
- Connection status indicator

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

### Sending Audio Data

```json
{
  "event": "data",
  "payload": "<base64-encoded-pcm16-audio>"
}
```

### Sending Finish Event

```json
{
  "event": "finish"
}
```

## Build for Production

```bash
npm run build
```

The production build will be in the `dist/` directory.

## Technologies

- **React** - UI framework
- **Vite** - Build tool and dev server
- **@cleandersonlobo/react-mic** - Audio visualization
- **Web Audio API** - Audio processing
- **WebSocket API** - Real-time communication
