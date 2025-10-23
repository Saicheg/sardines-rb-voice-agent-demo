import { useState, useRef, useEffect, useCallback } from 'react';
import { Waveform } from './components/Waveform';
import { useWebSocket } from './hooks/useWebSocket';
import { AudioStreamProcessor } from './utils/audioProcessing';
import { AudioPlayback } from './utils/audioPlayback';
import './App.css';

function App() {
  const [isRecording, setIsRecording] = useState(false);
  const [permissionError, setPermissionError] = useState(null);
  const [analyser, setAnalyser] = useState(null);
  const audioProcessorRef = useRef(null);
  const mediaStreamRef = useRef(null);
  const audioPlaybackRef = useRef(null);

  // Initialize audio playback and cleanup on unmount
  useEffect(() => {
    audioPlaybackRef.current = new AudioPlayback(24000);

    return () => {
      // Cleanup audio playback
      if (audioPlaybackRef.current) {
        audioPlaybackRef.current.close();
      }
      // Cleanup audio processor
      if (audioProcessorRef.current) {
        audioProcessorRef.current.stop();
      }
      // Cleanup media stream
      if (mediaStreamRef.current) {
        mediaStreamRef.current.getTracks().forEach(track => track.stop());
      }
    };
  }, []);

  // Handle incoming WebSocket messages
  const handleMessage = useCallback((data) => {
    // Check if this is an audio delta message
    if (data.type === 'response.output_audio.delta' && data.delta) {
      console.log('Playing audio chunk from server, delta length:', data.delta.length);
      if (audioPlaybackRef.current) {
        audioPlaybackRef.current.playChunk(data.delta);
      }
    }
  }, []);

  const { isConnected, error: wsError, sendMessage } = useWebSocket(handleMessage);

  const handleStartStop = async () => {
    if (isRecording) {
      // Stop recording
      setIsRecording(false);
      setAnalyser(null);

      // Send finish event to server
      sendMessage({ event: 'finish' });

      // Stop audio processor
      if (audioProcessorRef.current) {
        audioProcessorRef.current.stop();
        audioProcessorRef.current = null;
      }

      // Stop media stream
      if (mediaStreamRef.current) {
        mediaStreamRef.current.getTracks().forEach(track => track.stop());
        mediaStreamRef.current = null;
      }
    } else {
      // Start recording
      try {
        // Request microphone access
        const stream = await navigator.mediaDevices.getUserMedia({
          audio: {
            echoCancellation: true,
            noiseSuppression: true,
            sampleRate: 24000
          }
        });

        mediaStreamRef.current = stream;
        setPermissionError(null);
        setIsRecording(true);

        // Initialize audio processor
        audioProcessorRef.current = new AudioStreamProcessor(24000);

        // Start processing audio and send to WebSocket
        const analyserNode = await audioProcessorRef.current.start(stream, (base64Audio) => {
          if (isConnected) {
            sendMessage({
              event: 'data',
              payload: base64Audio
            });
          }
        });

        // Set analyser for waveform visualization
        setAnalyser(analyserNode);

      } catch (err) {
        console.error('Error accessing microphone:', err);
        setPermissionError('Failed to access microphone. Please grant permission.');
        setIsRecording(false);
      }
    }
  };

  return (
    <div className="app-container">
      <h1>WebSocket Audio Streamer</h1>

      <div className="status-section">
        <div className={`status-indicator ${isConnected ? 'connected' : 'disconnected'}`}>
          <span className="status-dot"></span>
          <span className="status-text">
            {isConnected ? 'Connected' : 'Disconnected'}
          </span>
        </div>
      </div>

      {(wsError || permissionError) && (
        <div className="error-message">
          {wsError || permissionError}
        </div>
      )}

      <div className="visualizer-section">
        <Waveform
          analyser={analyser}
          isRecording={isRecording}
          strokeColor="#4CAF50"
          backgroundColor="#1a1a1a"
        />
      </div>

      <div className="controls-section">
        <button
          className={`control-button ${isRecording ? 'recording' : ''}`}
          onClick={handleStartStop}
          disabled={!isConnected}
        >
          {isRecording ? 'Stop' : 'Start'}
        </button>

        {!isConnected && (
          <p className="connection-warning">
            Waiting for WebSocket connection...
          </p>
        )}
      </div>

      <div className="info-section">
        <p className="info-text">
          Audio Format: PCM16 • Sample Rate: 24kHz • Channels: Mono
        </p>
      </div>
    </div>
  );
}

export default App;
