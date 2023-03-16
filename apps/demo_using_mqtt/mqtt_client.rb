# frozen_string_literal: true

# BUILD OUT FROM SCRATCH
# take input of MQTT server
# connect to MQTT
# listen to managemm topic
# allow a message to be set to actuatr

# proof of concept -
# MM work of passsion -
# client -> MQTT -> hardware
# client Y MQTT Y hardware - MQTT lib ? - works??????
#
# client JRuby on a phone ????? -
#
# Ruboto JRuby -> android
# - connect to MQTT
# - have dynamic store of actutors as buttons
# - send an MQTT signal to MQTT server
# - listen for update
#
# Mruby - ardunio C code - how do we chante this to mruby
# - mruby?
# - mruby/c
# - PicoRuby ?

require "io/console" # visual input
require "mqtt"
require "JSON"

class KickClient
  MANAGMENT_TOPIC = "kick/manage"

  def initialize(mqtt_server:, mqtt_port:, ui:)
    # assuming you are on WiFi
    @ui = ui
    @mqtt_server = mqtt_server
    @mqtt_port = mqtt_port
    @client = connect_to_mqtt
  end

  def connect_to_mqtt
    client = nil
    loop do
      client = MQTT::Client.connect(@mqtt_server, @mqtt_port)
      break # have a client
    rescue SocketError => e
      @ui.publish_event("having problems finding #{@mqtt_server}")
      @ui.publish_event(e.message)
      @ui.publish_event("will retry in 1 second")
      sleep(1)
    rescue Errno::ECONNREFUSED => e
      @ui.publish_event("seems like MQTT is not running on port #{@mqtt_port}")
      @ui.publish_event(e.message)
      @ui.publish_event("will retry in 1 second")
      sleep(1)
    end
    client
  end

  def start
    start_management_topic_listener
    loop do
      # TODO: work out how UI would respond to user input
      # Ascii version - q to quit, up and down and enter to send hit
      # Rubobto version button to quit button to hit an actuator
      #
      # input = @ui.listen_for_input
      # if input == "quit"
      # if input == "hit ABC"
      @ui.action_input
      sleep(1)
    end
  end

  def start_management_topic_listener
    @client.subscribe(MANAGMENT_TOPIC)
    Thread.new do
      @client.get do |topic, message|
        @ui.publish_event([topic, message])
      end
    end
  end
end

class AsciiUi
  def publish_event(message)
    puts message
  end

  def action_input
    action = read_char
    case action
    when "q"
      exit
    end
  end

  def read_char
    input = nil
    begin
      $stdin.echo = false
      $stdin.raw!

      input = $stdin.getc.chr
      if input == "\e"
        begin
          input << $stdin.read_nonblock(3)
        rescue
          nil
        end
        begin
          input << $stdin.read_nonblock(2)
        rescue
          nil
        end
      end
    ensure
      $stdin.echo = true
      $stdin.cooked!
    end
    input
  end
end

class RubotoUi
  def publish_event(message)
    # do the Ruboto best practice thing
  end

  def action_input
    # do the Ruboto best practice thing
  end
end

kick_client = KickClient.new(
  mqtt_server: ENV.fetch("MQTT_SERVER", "localhost"),
  mqtt_port: 1883,
  ui: AsciiUi.new,
)

kick_client.start

exit

__END__
events = []
client = nil
actuators = []

# 1. remove device if it is no longer alive
# 2. allow client to send message to device
# 3. allow device to listen on the topic

ANSI_COLOR1 = "\33[38;5;0;48;5;255m"
ANSI_COLOR2 = "\33[38;5;255;48;5;0m"
ANSI_RESET = "\33[m"

actuator_index = 0
def print_ui(events, actuators, actuator_index)
  # clear output and go to top left
  puts "\e[H\e[2J"

  width = 80
  # status
  output = []
  output << "╔#{"═" * width}╗"
  output << sprintf("║ %-#{width - 4}s ║", "🦵🥊 Status")
  output << "╠#{"═" * width}╣"
  ["WiFi connected", "MQTT connected", "PING status"].each do |status|
    output << sprintf("║ %-#{width - 2}s ║", status)
  end
  output << "╚#{"═" * width}╝"
  output << "\033[0;32m#{"▂" * (width + 2)}\033[0m"
  output << ""

  output << "╔#{"═" * width}╗"
  output << sprintf("║ %-#{width - 2}s ║", "Actuators")
  output << "╠#{"═" * width}╣"
  if actuators.empty?
    output << sprintf("║ %-#{width - 2}s ║", "waiting for devices to join ...")
  else
    actuators.each.with_index do |actuator, index|
      actuator_string = []
      actuator_string << ANSI_COLOR1 if index == actuator_index
      actuator_string << sprintf("%-#{width - 2}s", actuator)
      actuator_string << ANSI_RESET if index == actuator_index
      output << sprintf("║ %-#{width - 2}s ║", actuator_string.join(""))
    end
  end
  output << "╚#{"═" * width}╝"

  output << "\033[0;32m#{"▂" * (width + 2)}\033[0m"
  output << ""

  output << "╔#{"═" * width}╗"
  output << sprintf("║ %-#{width - 2}s ║", "Event Log")
  output << "╠#{"═" * width}╣"
  events.last(3).each.with_index do |event, index|
    output << sprintf("║ %-#{width - 2}s ║", event)
  end
  output << "╚#{"═" * width}╝"

  # call to action
  output << ""
  output << "q to quit, ⬇️  j ⬆️  k for down and up and ⏎ RETURN to select"
  output << "⬅️  h ➡️  k left and right"

  puts output.join("\e[E")
  puts "\e[E"
end

def read_char
  $stdin.echo = false
  $stdin.raw!

  input = $stdin.getc.chr
  if input == "\e"
    begin
      input << $stdin.read_nonblock(3)
    rescue
      nil
    end
    begin
      input << $stdin.read_nonblock(2)
    rescue
      nil
    end
  end
ensure
  return input
end

# Separate thread to listen for updates from MQTT server
management_topic = "kick/manage"
client.subscribe(management_topic)

Thread.new do
  client.get do |topic, message|
    # pp [topic, message]
    events << [topic, message]
    actuator_topic = JSON.parse(message).dig("actuator")
    if !actuators.include?(actuator_topic)
      actuators << actuator_topic
    end
    # TODO: remove actuators if we don't get a sign of life (ping) for 30 seconds
    print_ui(events, actuators, actuator_index)
  end
end

loop do
  print_ui(events, actuators, actuator_index)
  c = read_char

  case c
  when "\e[A", "\eOA", "j"
    # Up
    actuator_index = ((actuator_index + 1) >= actuators.length) ? 0 : (actuator_index + 1)
  when "\e[B", "\eOB", "k"
    # Down
    actuator_index = ((actuator_index - 1) < 0) ? (actuators.length - 1) : (actuator_index - 1)
  when "\e[D", "\eOD", "h"
    # Left
  when "\e[C", "\eOC", "l"
    # Right
  when "\r"
    # Return
    events << "sent hit to #{actuators[actuator_index]}"
    # TODO actually send a hit message to actuator
    payload = {action: "hit"}.to_json
    acutator_topic = actuators[actuator_index] # kick/UNIQ_ID
    client.subscribe(management_topic)
    client.publish(acutator_topic, payload, false, 1) # retain = false, qos = 1
  when "q"
    exit
  else
    puts "WTF #{c.inspect}"
  end
end
