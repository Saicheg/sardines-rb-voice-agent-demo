require 'faye/websocket'
require 'eventmachine'
require 'base64'
require 'wavefile'
require 'json'

# Test configuration
HOST = '127.0.0.1'
PORT = 5613
CHUNK_SIZE = 1024
FILE_PATH = File.join(__dir__, 'fixtures', 'question.wav')

puts "Starting chunked file transfer test..."
puts "Connecting to ws://#{HOST}:#{PORT}"
puts "File: #{FILE_PATH}"
puts "-" * 50

# Read the WAV file
unless File.exist?(FILE_PATH)
  puts "✗ ERROR: File not found: #{FILE_PATH}"
  exit(1)
end

# Read WAV file using wavefile library
reader = WaveFile::Reader.new(FILE_PATH)
format = reader.format
puts "WAV Format:"
puts "  Channels: #{format.channels}"
puts "  Sample Rate: #{format.sample_rate} Hz"
puts "  Bits per Sample: #{format.bits_per_sample}"

# Read all audio samples and convert to binary string
buffer = reader.read(reader.total_sample_frames)
samples = buffer.samples

# Pack samples into binary data (assuming 16-bit samples)
file_data = samples.flatten.pack('s*')
reader.close

puts "Audio data size: #{file_data.bytesize} bytes"
puts "Total samples: #{samples.flatten.length}"

# Split into chunks
chunks = []
offset = 0
while offset < file_data.bytesize
  chunk_size = [CHUNK_SIZE, file_data.bytesize - offset].min
  chunks << file_data[offset, chunk_size]
  offset += chunk_size
end

puts "Chunks: #{chunks.length}"
puts "-" * 50

EM.run do
  ws = Faye::WebSocket::Client.new("ws://#{HOST}:#{PORT}")
  chunk_index = 0
  chunks_sent = 0

  timeout = EventMachine::Timer.new(30) do
    puts "✗ FAIL: Timeout"
    ws.close(1000, "Timeout")
  end

  ws.on :open do |_event|
    puts "Connected - waiting 2 seconds before sending..."

    # Wait 2 seconds, then start sending chunks
    EventMachine::Timer.new(2) do
      puts "Starting to send chunks..."

      chunks.each_with_index do |chunk, index|
        # Encode chunk to base64
        encoded = Base64.strict_encode64(chunk)

        # Create JSON message with event and payload
        message = {
          event: 'data',
          payload: encoded
        }.to_json

        puts "[Chunk #{index + 1}/#{chunks.length}] Sending #{chunk.bytesize} bytes (base64: #{encoded.length} chars)"
        ws.send(message)
        chunks_sent += 1
      end

      puts "All chunks sent!"

      # Wait a bit for server to process, then close
      EventMachine::Timer.new(2) do
        puts "✓ SUCCESS: Sent all #{chunks_sent} chunks to server"
        timeout.cancel
        ws.close(1000, "Test complete")
        exit(0)
      end
    end
  end

  ws.on :message do |event|
    message = event.data
    puts "Received response: '#{message[0..50]}#{message.length > 50 ? '...' : ''}'"

    # Parse JSON response
    begin
      data = JSON.parse(message)
      puts "Event type: #{data['event']}"
    rescue JSON::ParserError
      puts "Non-JSON response received"
    end
  end

  ws.on :close do |event|
    puts "Connection closed (code: #{event.code}, reason: #{event.reason})"
    EM.stop
  end

  ws.on :error do |event|
    puts "✗ ERROR: #{event.message}"
    timeout.cancel
    EM.stop
    exit(1)
  end
end
