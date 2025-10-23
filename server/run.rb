require 'faye/websocket'
require 'thin'
require 'json'
require 'dotenv/load'
require 'base64'
require 'thread'

# Load the Thin adapter
Faye::WebSocket.load_adapter('thin')

# Constants for OpenAI connection
OPENAI_API_KEY = ENV['OPENAI_API_KEY']
OPENAI_REALTIME_URL = ENV['OPENAI_REALTIME_URL'] 

if OPENAI_API_KEY.nil? || OPENAI_REALTIME_URL.nil?
  puts "✗ ERROR: OPENAI_API_KEY and OPENAI_REALTIME_URL must be set in environment variables."
  exit(1)
end 

PROMPT = """
I want you to act as a drunk person.
You will only answer like a very drunk person and nothing else.
Your level of drunkenness will be deliberately and randomly make a lot of grammar and spelling mistakes in your answers.
You will also randomly say something random with the same level of drunkeness I mentioned.
You will randomly answer in aggressive and rude manner.
Use standard accent and familiar dialect for user.
Keep answers short with no more than 50 words.
"""

REALTIME_SESSION_CONFIG = {
  type: "session.update",
  session: {
    type: "realtime",
    instructions: PROMPT,
    # output_modalities: ["text"],
    output_modalities: ["audio"],
    audio: {
      input: {
        noise_reduction: nil,
        turn_detection: {
          type: "server_vad",
          threshold: 0.2,
          prefix_padding_ms: 300,
          silence_duration_ms: 300,
        },
      },
    },
    tracing: 'auto',
  }
}

# WebSocket Rack application
App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    client_ws = Faye::WebSocket.new(env)
    openai_ws = nil
    audio_queue = Queue.new
    sender_timer = nil

    # Sequential sender function - processes queue one message at a time
    # Messages are already transformed, just send them
    send_next_message = lambda do
      unless audio_queue.empty?
        message_json = audio_queue.pop(true) rescue nil  # non-blocking pop

        if message_json && openai_ws && openai_ws.ready_state == Faye::WebSocket::API::OPEN
          puts "Sending message to OpenAI: #{message_json[0..100]}..."
          openai_ws.send(message_json)
          puts "Sent message to OpenAI (queue size: #{audio_queue.size})"
        end
      end
    end

    client_ws.on :open do |event|
      puts "Client connected"

      # Create OpenAI WebSocket connection
      openai_ws = Faye::WebSocket::Client.new(
        OPENAI_REALTIME_URL,
        nil,
        headers: {
          'Authorization' => "Bearer #{OPENAI_API_KEY}",
          # 'OpenAI-Beta' => 'realtime=v1'
        }
      )

      # Handle OpenAI WebSocket open
      openai_ws.on :open do |event|
        puts "Connected to OpenAI"
        # Send initial session configuration
        openai_ws.send(REALTIME_SESSION_CONFIG.to_json)
        puts "Sent session config to OpenAI"

        # Start the sequential message sender (every 10ms)
        sender_timer = EventMachine::PeriodicTimer.new(0.01) do
          send_next_message.call
        end

        puts "Started sequential message sender"


          commit_message = {
            "type" => "input_audio_buffer.clear"
          }.to_json

          audio_queue.push(commit_message)
      end

      # Handle messages from OpenAI -> forward to client
      openai_ws.on :message do |event|
        puts "Received from OpenAI: #{event.data}..."
        client_ws.send(event.data)
      end

      # Handle OpenAI WebSocket close
      openai_ws.on :close do |event|
        puts "OpenAI disconnected (code: #{event.code}, reason: #{event.reason})"
        sender_timer.cancel if sender_timer
      end

      # Handle OpenAI WebSocket errors
      openai_ws.on :error do |event|
        puts "OpenAI error: #{event.message}"
      end
    end

    # Handle messages from client -> add to queue
    client_ws.on :message do |event|
      msg = event.data
      puts "Received from client: #{msg[0..100]}#{msg.length > 100 ? '...' : ''}"

      begin
        # Parse the incoming JSON message with symbolized keys
        parsed_msg = JSON.parse(msg, symbolize_names: true)

        # Use pattern matching to handle different event types
        case parsed_msg
        in { event: 'ping' }
          puts "Received ping, sending pong"
          client_ws.send({ event: 'pong' }.to_json)

        in { event: 'data', payload: audio_data }
          puts "Received audio data event, transforming and adding to queue"
          # Transform message before queuing
          message_to_provider = {
            "type" => "input_audio_buffer.append",
            "audio" => audio_data
          }.to_json

          audio_queue.push(message_to_provider)
          puts "Queue size: #{audio_queue.size}"

        in { event: 'finish' }
          puts "Received finish event, transforming and adding commit command to queue"
        else
          puts "Unknown event type received: #{parsed_msg[:event]}"
        end

      rescue JSON::ParserError => e
        puts "Failed to parse message as JSON: #{e.message}"
      end
    end

    # Handle client disconnect
    client_ws.on :close do |event|
      puts "Client disconnected (code: #{event.code}, reason: #{event.reason})"

      # Stop sender timer
      sender_timer.cancel if sender_timer

      # Close OpenAI connection if open
      if openai_ws && openai_ws.ready_state == Faye::WebSocket::API::OPEN
        openai_ws.close
      end

      client_ws = nil
      openai_ws = nil
    end

    # Return async Rack response
    client_ws.rack_response
  else
    # Normal HTTP request
    [200, { 'Content-Type' => 'text/plain' }, ['WebSocket server running']]
  end
end

# Run the server if executed directly
if __FILE__ == $0
  puts "Starting WebSocket server on 127.0.0.1:5613"

  Thin::Server.start('127.0.0.1', 5613, App)
end
