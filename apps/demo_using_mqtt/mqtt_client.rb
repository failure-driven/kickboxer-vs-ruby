# frozen_string_literal: true

require "io/console" # visual input
require "mqtt"
require "JSON"

class KickClient
  MANAGMENT_TOPIC = "kick/manage"

  def initialize(mqtt_server:, mqtt_port:, ui:)
    # assuming you are on WiFi
    @events = []
    @actuators = []
    @ui = ui
    @ui.set_client(self)
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
      @events << "having problems finding #{@mqtt_server}"
      @events << e.message
      @events << "will retry in 1 second"
      @ui.events = @events.last(3)
      @ui.paint
      sleep(1)
    rescue Errno::ECONNREFUSED => e
      @events << ("seems like MQTT is not running on port #{@mqtt_port}")
      @events << (e.message)
      @events << ("will retry in 1 second")
      @ui.events = @events.last(3)
      @ui.paint
      sleep(1)
    end
    @events << "connected to client #{@mqtt_server}:#{@mqtt_port}"
    @ui.events = @events.last(3)
    @ui.paint
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
        @events << [topic, message]
        @ui.events = @events.last(3)
        actuator_topic = JSON.parse(message).dig("actuator")
        if !@actuators.include?(actuator_topic)
          @actuators << actuator_topic
          @ui.actuators = @actuators
        end

        @ui.paint
      end
    end
  end

  def hit(actuator)
    @events << "sent hit to #{actuator}"
    @ui.events = @events.last(3)
    payload = {action: "hit"}.to_json
    actuator_topic = actuator # kick/UNIQ_ID
    @client.publish(actuator_topic, payload, false, 1) # retain = false, qos = 1
  end
end

class AsciiUi
  ANSI_COLOR1 = "\33[38;5;0;48;5;255m"
  ANSI_RESET = "\33[m"

  attr_accessor :width
  attr_accessor :events, :actuators

  def initialize
    @width = 80
    @selected_actuator = 0
    @events = []
    @actuators = []
    @client = nil
  end

  def set_client(client)
    @client = client
  end

  def paint
    puts "\e[H\e[2J"

    paint_in_a_box("actuators", @actuators, @selected_actuator)
    paint_in_a_box("Event Log", @events, nil)
  end

  def paint_in_a_box(title, lines, selected_line)
    output = []
    output << "╔#{"═" * width}╗"
    output << sprintf("║ %-#{width - 2}s ║", title)
    output << "╠#{"═" * width}╣"
    if lines.empty?
      output << sprintf("║ %-#{width - 2}s ║", "waiting ...")
    else
      lines.each.with_index do |line, index|
        line_string = []
        line_string << ANSI_COLOR1 if index == selected_line
        line_string << sprintf("%-#{width - 2}s", line)
        line_string << ANSI_RESET if index == selected_line
        output << sprintf("║ %-#{width - 2}s ║", line_string.join(""))
      end
    end
    output << "╚#{"═" * width}╝"
    puts output.join("\e[E")
    puts "\e[E"
  end

  def action_input
    action = read_char
    case action
    when "\e[A", "\eOA", "k" # up
      @selected_actuator = [@selected_actuator - 1, 0].max
    when "\e[B", "\eOB", "j" # down
      @selected_actuator = [@selected_actuator + 1, (@actuators.length - 1)].min
    when "\r" # Return
      @client.hit(@actuators[@selected_actuator])
    when "q"
      exit
    else
      puts "WTF #{action.inspect}"
    end
    paint
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
