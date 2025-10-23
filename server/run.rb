require 'faye/websocket'
require 'thin'

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
      puts "Received: #{msg}"

      if msg == 'ping'
        ws.send('pong')
        puts "Sent: pong"
      else
        ws.send(msg) # Echo back other messages
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
