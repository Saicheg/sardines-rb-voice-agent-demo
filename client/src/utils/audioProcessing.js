/**
 * Convert audio blob to PCM16 base64 encoded string
 * @param {Blob} audioBlob - Audio data blob from react-mic
 * @returns {Promise<string>} Base64 encoded PCM16 audio
 */
export async function convertBlobToPCM16Base64(audioBlob) {
  try {
    // Convert blob to array buffer
    const arrayBuffer = await audioBlob.arrayBuffer();

    // Decode audio data
    const audioContext = new (window.AudioContext || window.webkitAudioContext)({
      sampleRate: 24000 // Set to 24kHz
    });

    const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);

    // Get PCM data (first channel if stereo)
    const channelData = audioBuffer.getChannelData(0);

    // Convert Float32 to Int16 (PCM16)
    const pcm16 = new Int16Array(channelData.length);
    for (let i = 0; i < channelData.length; i++) {
      // Clamp values between -1 and 1, then scale to Int16 range
      const s = Math.max(-1, Math.min(1, channelData[i]));
      pcm16[i] = s < 0 ? s * 0x8000 : s * 0x7FFF;
    }

    // Convert to base64
    const base64 = arrayBufferToBase64(pcm16.buffer);

    return base64;
  } catch (error) {
    console.error('Error converting audio blob:', error);
    throw error;
  }
}

/**
 * Convert ArrayBuffer to base64 string
 * @param {ArrayBuffer} buffer
 * @returns {string} Base64 encoded string
 */
function arrayBufferToBase64(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

/**
 * Process audio data from microphone stream directly
 * This is an alternative approach using MediaRecorder API directly
 */
export class AudioStreamProcessor {
  constructor(sampleRate = 24000) {
    this.sampleRate = sampleRate;
    this.audioContext = null;
    this.mediaStreamSource = null;
    this.processor = null;
    this.analyser = null;
  }

  async start(stream, onAudioData) {
    this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
      sampleRate: this.sampleRate
    });

    this.mediaStreamSource = this.audioContext.createMediaStreamSource(stream);

    // Create analyser for visualization
    this.analyser = this.audioContext.createAnalyser();
    this.analyser.fftSize = 2048;

    // Create a script processor for real-time audio processing
    const bufferSize = 4096;
    this.processor = this.audioContext.createScriptProcessor(bufferSize, 1, 1);

    this.processor.onaudioprocess = (e) => {
      const inputData = e.inputBuffer.getChannelData(0);

      // Convert Float32 to PCM16
      const pcm16 = new Int16Array(inputData.length);
      for (let i = 0; i < inputData.length; i++) {
        const s = Math.max(-1, Math.min(1, inputData[i]));
        pcm16[i] = s < 0 ? s * 0x8000 : s * 0x7FFF;
      }

      // Convert to base64
      const base64 = arrayBufferToBase64(pcm16.buffer);

      if (onAudioData) {
        onAudioData(base64);
      }
    };

    // Connect: source -> analyser -> processor -> destination
    this.mediaStreamSource.connect(this.analyser);
    this.analyser.connect(this.processor);
    this.processor.connect(this.audioContext.destination);

    return this.analyser;
  }

  getAnalyser() {
    return this.analyser;
  }

  stop() {
    if (this.processor) {
      this.processor.disconnect();
      this.processor = null;
    }
    if (this.analyser) {
      this.analyser.disconnect();
      this.analyser = null;
    }
    if (this.mediaStreamSource) {
      this.mediaStreamSource.disconnect();
      this.mediaStreamSource = null;
    }
    if (this.audioContext) {
      this.audioContext.close();
      this.audioContext = null;
    }
  }
}
