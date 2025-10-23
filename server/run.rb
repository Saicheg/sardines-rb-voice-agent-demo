require 'faye/websocket'
require 'thin'
require 'json'

# Load the Thin adapter
Faye::WebSocket.load_adapter('thin')

# WebSocket Rack application
App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env)

    ws.on :open do |event|
      puts "Client connected"
    end

    ws.on :message do |event|
      msg = event.data
      puts "Received message: #{msg[0..100]}#{msg.length > 100 ? '...' : ''}"

      begin
        # Parse JSON message
        data = JSON.parse(msg)
        event_type = data['event']

        case event_type
        when 'ping'
          # Respond with pong event
          response = { event: 'pong' }.to_json
          ws.send(response)
          puts "Sent: #{response}"

        when 'data'
          # Print the payload data
          payload = data['payload']
          puts "Data event received - payload size: #{payload&.length || 0} bytes"
          puts "Payload preview: #{payload&.[](0..50)}..." if payload
          # No response needed for data events

        else
          puts "Unknown event type: #{event_type}"
        end

      rescue JSON::ParserError => e
        puts "Error parsing JSON: #{e.message}"
        error_response = { event: 'error', message: 'Invalid JSON' }.to_json
        ws.send(error_response)
      end
    end

    ws.on :close do |event|
      puts "Client disconnected (code: #{event.code}, reason: #{event.reason})"
      ws = nil
    end

    # Return async Rack response
    ws.rack_response
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
