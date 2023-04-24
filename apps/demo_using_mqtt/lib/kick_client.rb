# frozen_string_literal: true

require "util"
require "mqtt"
require "json"

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
      @ui.action_input
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
    Util.elapsed_time do
      @ui.events = @events.last(3)
      payload = {action: "hit"}.to_json
      actuator_topic = actuator # kick/UNIQ_ID
      @client.publish(actuator_topic, payload, false, 1) # retain = false, qos = 1
    end.tap do |timing|
      @events << "sent hit to #{actuator}, duration: #{timing}"
      @ui.events = @events.last(3)
    end
  end
end
