/**
 * Convert base64 string to ArrayBuffer
 * @param {string} base64
 * @returns {ArrayBuffer}
 */
function base64ToArrayBuffer(base64) {
  const binaryString = atob(base64);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes.buffer;
}

/**
 * Audio playback manager for streaming PCM16 audio
 */
export class AudioPlayback {
  constructor(sampleRate = 24000) {
    this.sampleRate = sampleRate;
    this.audioContext = null;
    this.audioQueue = [];
    this.isPlaying = false;
    this.currentStartTime = 0;
  }

  /**
   * Initialize audio context
   */
  init() {
    if (!this.audioContext) {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
        sampleRate: this.sampleRate
      });
    }
  }

  /**
   * Play base64-encoded PCM16 audio
   * @param {string} base64Audio - Base64 encoded PCM16 audio data
   */
  async playChunk(base64Audio) {
    this.init();

    try {
      // Decode base64 to ArrayBuffer
      const arrayBuffer = base64ToArrayBuffer(base64Audio);

      // Convert PCM16 (Int16) to Float32
      const pcm16 = new Int16Array(arrayBuffer);
      const float32 = new Float32Array(pcm16.length);

      for (let i = 0; i < pcm16.length; i++) {
        // Convert Int16 to Float32 range [-1.0, 1.0]
        float32[i] = pcm16[i] / (pcm16[i] < 0 ? 0x8000 : 0x7FFF);
      }

      // Create audio buffer
      const audioBuffer = this.audioContext.createBuffer(
        1, // mono
        float32.length,
        this.sampleRate
      );

      // Copy data to audio buffer
      audioBuffer.getChannelData(0).set(float32);

      // Queue and play
      this.queueAudio(audioBuffer);

    } catch (error) {
      console.error('Error playing audio chunk:', error);
    }
  }

  /**
   * Queue audio buffer for playback
   * @param {AudioBuffer} audioBuffer
   */
  queueAudio(audioBuffer) {
    const source = this.audioContext.createBufferSource();
    source.buffer = audioBuffer;
    source.connect(this.audioContext.destination);

    // Calculate when to start this chunk
    const currentTime = this.audioContext.currentTime;

    if (this.currentStartTime < currentTime) {
      this.currentStartTime = currentTime;
    }

    // Schedule playback
    source.start(this.currentStartTime);

    // Update start time for next chunk
    this.currentStartTime += audioBuffer.duration;

    this.isPlaying = true;

    // Cleanup when done
    source.onended = () => {
      if (this.currentStartTime <= this.audioContext.currentTime) {
        this.isPlaying = false;
      }
    };
  }

  /**
   * Stop all audio playback
   */
  stop() {
    this.audioQueue = [];
    this.currentStartTime = 0;
    this.isPlaying = false;
  }

  /**
   * Close audio context
   */
  close() {
    this.stop();
    if (this.audioContext) {
      this.audioContext.close();
      this.audioContext = null;
    }
  }
}
