require 'faye/websocket'
require 'eventmachine'
require 'base64'
require 'wavefile'
require 'json'
require 'thread'

# Test configuration
HOST = '127.0.0.1'
PORT = 5613
CHUNK_SIZE = 4096 
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

# Create a queue for chunks to send
chunk_queue = Queue.new

EM.run do
  ws = Faye::WebSocket::Client.new("ws://#{HOST}:#{PORT}")
  chunks_sent = 0
  sender_timer = nil

  timeout = EventMachine::Timer.new(30) do
    puts "✗ FAIL: Timeout"
    ws.close(1000, "Timeout")
  end

  # Sequential sender function - processes queue one message at a time
  send_next_message = lambda do
    unless chunk_queue.empty?
      message_data = chunk_queue.pop(true) rescue nil  # non-blocking pop

      if message_data
        event_type, payload = message_data

        if event_type == :finish
          # Send finish event
          message = { event: 'finish' }.to_json
          puts "Sending finish event to commit audio buffer"
          ws.send(message)
        else
          # Send audio chunk
          index = event_type
          chunk = payload

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
      end
    else
      # Queue is empty, stop the timer
      sender_timer.cancel if sender_timer
      puts "All messages sent!"

      # Wait 20 seconds for server to process and receive responses, then close
      EventMachine::Timer.new(20) do
        puts "✓ SUCCESS: Sent all #{chunks_sent} chunks + finish event to server"
        timeout.cancel
        ws.close(1000, "Test complete")
        exit(0)
      end
    end
  end

  ws.on :open do |_event|
    puts "Connected - waiting 2 seconds before sending..."

    # Wait 3 seconds, then start the sequential sender
    EventMachine::Timer.new(3) do
      puts "Starting sequential chunk sender..."

      # Populate the queue with all chunks
      chunks.each_with_index do |chunk, index|
        chunk_queue.push([index, chunk])
      end

      # Add finish event to queue after all chunks
      chunk_queue.push([:finish, nil])
      puts "Added finish event to queue"

      # Start periodic timer to send messages sequentially (every 50ms)
      sender_timer = EventMachine::PeriodicTimer.new(0.05) do
        send_next_message.call
      end
    end
  end

  ws.on :message do |event|
    message = event.data
    puts "Received response: #{message}"

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
