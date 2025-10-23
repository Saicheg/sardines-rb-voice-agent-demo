# OpenAI Realtime API Demo

A technical proof of concept demonstrating real-time audio interaction with OpenAI's Realtime API. This project consists of a Ruby WebSocket server that proxies connections to OpenAI and a React-based client for testing audio streaming.

## About

This demo was vibe-coded for a presentation at the [Sardines.rb meetup](https://www.meetup.com/sardinesrb/events/311340390/). It serves as a practical example of integrating OpenAI's Realtime API with a Ruby backend.

## Architecture

The application is split into two main components:

- **Server (Ruby)**: WebSocket server that acts as a proxy between the client and OpenAI's Realtime API
- **Client (React)**: Web-based interface for recording and streaming audio to the server

## Prerequisites

### Server Requirements
- Ruby (2.7 or higher)
- Bundler

### Client Requirements
- Node.js (16 or higher)
- npm

### API Requirements
- OpenAI API key with access to the Realtime API

## Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd sardines-rb-demo
```

### 2. Server Setup

Navigate to the server directory and install dependencies:

```bash
cd server
bundle install
```

Configure environment variables by creating a `.env` file:

```bash
cp .env.example .env
```

Edit the `.env` file and add your OpenAI API credentials:

```
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_REALTIME_URL=wss://api.openai.com/v1/realtime?model=gpt-realtime
```

### 3. Client Setup

Navigate to the client directory and install dependencies:

```bash
cd ../client
npm install
```

## Running the Application

### Start the Server

From the `server` directory:

```bash
ruby run.rb
```

The server will start on `127.0.0.1:5613`

### Start the Client

From the `client` directory:

```bash
npm run dev
```

The client will typically start on `http://localhost:5173` (Vite's default port)

### Access the Application

Open your browser and navigate to the URL shown in the client terminal (usually `http://localhost:5173`)

## How It Works

1. The client captures audio from the user's microphone
2. Audio data is sent to the Ruby WebSocket server in real-time
3. The server forwards the audio data to OpenAI's Realtime API
4. OpenAI processes the audio and sends responses back through the server
5. The client receives and plays the audio responses

## Project Structure

```
sardines-rb-demo/
├── server/
│   ├── run.rb              # Main WebSocket server
│   ├── test.rb             # Test file
│   ├── Gemfile             # Ruby dependencies
│   ├── .env.example        # Example environment variables
│   └── fixtures/           # Test fixtures
│
└── client/
    ├── src/
    │   ├── App.jsx         # Main React component
    │   ├── components/     # React components
    │   ├── hooks/          # Custom React hooks
    │   └── utils/          # Utility functions
    ├── package.json        # Node dependencies
    └── vite.config.js      # Vite configuration
```

## Development Notes

### Server (server/run.rb:1)

- Built with Faye WebSocket and Thin server
- Implements audio data queuing for sequential processing
- Handles connection lifecycle between client and OpenAI
- Configurable session parameters for voice interaction

### Client

- React 19 with Vite build tooling
- WebSocket-based communication with the server
- Real-time audio recording and streaming
- Audio playback for OpenAI responses

## Configuration

The server's AI behavior can be customized by modifying the `PROMPT` constant in `server/run.rb:20`. The default configuration includes:

- Custom instructions for AI personality
- Audio output modality
- Voice Activity Detection (VAD) settings
- Turn detection thresholds

## Troubleshooting

### Server won't start
- Ensure all gems are installed: `bundle install`
- Verify `.env` file exists with valid credentials
- Check if port 5613 is already in use

### Client won't connect
- Verify the server is running on `127.0.0.1:5613`
- Check browser console for WebSocket connection errors
- Ensure microphone permissions are granted

### No audio response
- Verify OpenAI API key has Realtime API access
- Check server logs for OpenAI connection errors
- Ensure browser supports Web Audio API

## Technology Stack

### Backend
- Ruby
- faye-websocket
- thin (web server)
- eventmachine
- dotenv

### Frontend
- React 19
- Vite
- Web Audio API
- WebSocket API

## License

[Add your license here]

## Contributing

This is a proof of concept demo. Feel free to fork and experiment!
