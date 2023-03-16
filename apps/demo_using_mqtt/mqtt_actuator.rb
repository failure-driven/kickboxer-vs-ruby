# frozen_string_literal: true

require "io/console" # for visual input like `$stdin.echo =`
require "mqtt"
require "JSON"
require "SecureRandom"

class KickMqtt
  MANAGMENT_TOPIC = "kick/manage"

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
end

class KickActuator < KickMqtt
  def initialize(mqtt_server:, mqtt_port:, ui:)
    # assuming you are on WiFi
    @ui = ui
    @mqtt_server = mqtt_server
    @mqtt_port = mqtt_port
    @client = connect_to_mqtt
    @actuator_id = SecureRandom.hex(3) # on device this is MAC address
  end

  def start
    notify_management
    subscribe_to_own_topic
    process_requests
    loop do
      @ui.action_input
      sleep(1)
    end
  end

  def process_requests
    Thread.new do
      loop do
        @client.get do |topic, message|
          case message
          when '{"action":"hit"}'
            @ui.hit
          else
            @ui.publish_event [topic, message].inspect
          end
        end
      end
    end
  end

  def notify_management
    Thread.new do
      loop do
        @ui.publish_event("sending i'm alive ping")
        payload = {message: "OK", actuator: actuator_topic}.to_json
        @client.publish(MANAGMENT_TOPIC, payload, false, 1) # retain = false, QoS = 1
        sleep(5)
      end
    end
  end

  def subscribe_to_own_topic
    @client.subscribe(actuator_topic)
  end

  def actuator_topic = "kick/#{@actuator_id}"
end

class AsciiUi
  def publish_event(message)
    puts message + "\e[E"
  end

  def action_input
    action = read_char
    case action
    when "q"
      exit
    when "\u0003" # CTRL-C ^C
      exit
    else
      puts "I don't know how to #{action.inspect}"
    end
  end

  def hit
    (5..0).step(-1).each do |offset|
      sleep(0.1)
      printf "%#{offset}s\e[E\e[U", "🥊"
    end
    6.times do |offset|
      printf "%#{offset}s\e[E\e[U", "🥊"
      sleep(0.1)
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

kick_actuator = KickActuator.new(
  mqtt_server: ENV.fetch("MQTT_SERVER", "localhost"),
  mqtt_port: 1883,
  ui: AsciiUi.new,
)

kick_actuator.start
