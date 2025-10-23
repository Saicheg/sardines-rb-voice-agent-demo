require 'faye/websocket'
require 'eventmachine'

# Test configuration
HOST = '127.0.0.1'
PORT = 5613

puts "Starting ping/pong test..."
puts "Connecting to ws://#{HOST}:#{PORT}"
puts "-" * 50

EM.run do
  ws = Faye::WebSocket::Client.new("ws://#{HOST}:#{PORT}")

  timeout = EventMachine::Timer.new(5) do
    puts "✗ FAIL: Timeout - no response received"
    ws.close(1000, "Timeout")
  end

  ws.on :open do |_event|
    puts "Connected - sending 'ping'"
    ws.send('ping')
  end

  ws.on :message do |event|
    message = event.data
    puts "Received: '#{message}'"

    if message == 'pong'
      puts "✓ SUCCESS: Got 'pong' response"
      timeout.cancel
      ws.close(1000, "Test complete")
      exit(0)
    else
      puts "✗ FAIL: Expected 'pong', got '#{message}'"
      timeout.cancel
      ws.close(1000, "Test failed")
      exit(1)
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
