# frozen_string_literal: true

require "mqtt"
require "JSON"
require "SecureRandom"

class KickMqtt
  MANAGMENT_TOPIC = "kick/manage"
  def initialize()
    @events = []
    @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
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
      @events = @events.last(3)
    rescue Errno::ECONNREFUSED => e
      @events << "seems like MQTT is not running on port #{@mqtt_port}"
      @events << e.message
      @events << "will retry in 1 second"
      @events = @events.last(3)
    ensure
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
    super()
  end

  def start
    notify_management
    subscribe_to_own_topic
    process_requests
    @ui.paint_actuator
    loop do
      @ui.action_input
      @ui.paint_actuator
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
            @events << [topic, message].inspect
            @ui.events = @events.last(3)
            @ui.paint_actuator
          end
        end
      end
    end
  end

  def notify_management
    Thread.new do
      loop do
        now_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        uptime = "%.2f sec" % (now_time - @start_time)
        @events << "sending i'm alive ping, uptime: #{uptime}"
        @ui.events = @events.last(3)
        @ui.paint_actuator
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

