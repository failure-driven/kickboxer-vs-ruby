#!/usr/bin/env ruby

# an attempt to get around not being able to gem install on android-irb
#
#   ruby -e 'require "./flat_mqtt";  \
#     client = MQTT::Client.connect("localhost", 1883);  \
#     client.subscribe("kick/manage"); \
#     client.get{|topic, message| pp [topic, message]}'

require 'logger'
require 'socket'
require 'thread'
require 'timeout'

require 'mqtt/version'

module MQTT
  # Default port number for unencrypted connections
  DEFAULT_PORT = 1883

  # Default port number for TLS/SSL encrypted connections
  DEFAULT_SSL_PORT = 8883

  # Super-class for other MQTT related exceptions
  class Exception < ::Exception
  end

  # A ProtocolException will be raised if there is a
  # problem with data received from a remote host
  class ProtocolException < MQTT::Exception
  end

  # A NotConnectedException will be raised when trying to
  # perform a function but no connection has been
  # established
  class NotConnectedException < MQTT::Exception
  end

  # autoload :Client,   'mqtt/client'
  autoload :OpenSSL, 'openssl'
  autoload :URI, 'uri'
  autoload :CGI, 'cgi'

  # Client class for talking to an MQTT server
  class Client
    # Hostname of the remote server
    attr_accessor :host

    # Port number of the remote server
    attr_accessor :port

    # The version number of the MQTT protocol to use (default 3.1.1)
    attr_accessor :version

    # Set to true to enable SSL/TLS encrypted communication
    #
    # Set to a symbol to use a specific variant of SSL/TLS.
    # Allowed values include:
    #
    # @example Using TLS 1.0
    #    client = Client.new('mqtt.example.com', :ssl => :TLSv1)
    # @see OpenSSL::SSL::SSLContext::METHODS
    attr_accessor :ssl

    # Time (in seconds) between pings to remote server (default is 15 seconds)
    attr_accessor :keep_alive

    # Set the 'Clean Session' flag when connecting? (default is true)
    attr_accessor :clean_session

    # Client Identifier
    attr_accessor :client_id

    # Number of seconds to wait for acknowledgement packets (default is 5 seconds)
    attr_accessor :ack_timeout

    # Username to authenticate to the server with
    attr_accessor :username

    # Password to authenticate to the server with
    attr_accessor :password

    # The topic that the Will message is published to
    attr_accessor :will_topic

    # Contents of message that is sent by server when client disconnect
    attr_accessor :will_payload

    # The QoS level of the will message sent by the server
    attr_accessor :will_qos

    # If the Will message should be retain by the server after it is sent
    attr_accessor :will_retain

    # Last ping response time
    attr_reader :last_ping_response

    # Timeout between select polls (in seconds)
    SELECT_TIMEOUT = 0.5

    # Default attribute values
    ATTR_DEFAULTS = {
      :host => nil,
      :port => nil,
      :version => '3.1.1',
      :keep_alive => 15,
      :clean_session => true,
      :client_id => nil,
      :ack_timeout => 5,
      :username => nil,
      :password => nil,
      :will_topic => nil,
      :will_payload => nil,
      :will_qos => 0,
      :will_retain => false,
      :ssl => false
    }

    # Create and connect a new MQTT Client
    #
    # Accepts the same arguments as creating a new client.
    # If a block is given, then it will be executed before disconnecting again.
    #
    # Example:
    #  MQTT::Client.connect('myserver.example.com') do |client|
    #    # do stuff here
    #  end
    #
    def self.connect(*args, &block)
      client = MQTT::Client.new(*args)
      client.connect(&block)
      client
    end

    # Generate a random client identifier
    # (using the characters 0-9 and a-z)
    def self.generate_client_id(prefix = 'ruby', length = 16)
      str = prefix.dup
      length.times do
        num = rand(36)
        # Adjust based on number or letter.
        num += num < 10 ? 48 : 87
        str += num.chr
      end
      str
    end

    # Create a new MQTT Client instance
    #
    # Accepts one of the following:
    # - a URI that uses the MQTT scheme
    # - a hostname and port
    # - a Hash containing attributes to be set on the new instance
    #
    # If no arguments are given then the method will look for a URI
    # in the MQTT_SERVER environment variable.
    #
    # Examples:
    #  client = MQTT::Client.new
    #  client = MQTT::Client.new('mqtt://myserver.example.com')
    #  client = MQTT::Client.new('mqtt://user:pass@myserver.example.com')
    #  client = MQTT::Client.new('myserver.example.com')
    #  client = MQTT::Client.new('myserver.example.com', 18830)
    #  client = MQTT::Client.new(:host => 'myserver.example.com')
    #  client = MQTT::Client.new(:host => 'myserver.example.com', :keep_alive => 30)
    #
    def initialize(*args)
      attributes = args.last.is_a?(Hash) ? args.pop : {}

      # Set server URI from environment if present
      attributes.merge!(parse_uri(ENV['MQTT_SERVER'])) if args.length.zero? && ENV['MQTT_SERVER']

      if args.length >= 1
        case args[0]
        when URI
          attributes.merge!(parse_uri(args[0]))
        when %r{^mqtts?://}
          attributes.merge!(parse_uri(args[0]))
        else
          attributes[:host] = args[0]
        end
      end

      if args.length >= 2
        attributes[:port] = args[1] unless args[1].nil?
      end

      raise ArgumentError, 'Unsupported number of arguments' if args.length >= 3

      # Merge arguments with default values for attributes
      ATTR_DEFAULTS.merge(attributes).each_pair do |k, v|
        send("#{k}=", v)
      end

      # Set a default port number
      if @port.nil?
        @port = @ssl ? MQTT::DEFAULT_SSL_PORT : MQTT::DEFAULT_PORT
      end

      if @ssl
        require 'openssl'
        require 'mqtt/openssl_fix'
      end

      # Initialise private instance variables
      @last_ping_request = current_time
      @last_ping_response = current_time
      @socket = nil
      @read_queue = Queue.new
      @pubacks = {}
      @read_thread = nil
      @write_semaphore = Mutex.new
      @pubacks_semaphore = Mutex.new
    end

    # Get the OpenSSL context, that is used if SSL/TLS is enabled
    def ssl_context
      @ssl_context ||= OpenSSL::SSL::SSLContext.new
    end

    # Set a path to a file containing a PEM-format client certificate
    def cert_file=(path)
      self.cert = File.read(path)
    end

    # PEM-format client certificate
    def cert=(cert)
      ssl_context.cert = OpenSSL::X509::Certificate.new(cert)
    end

    # Set a path to a file containing a PEM-format client private key
    def key_file=(*args)
      path, passphrase = args.flatten
      ssl_context.key = OpenSSL::PKey::RSA.new(File.open(path), passphrase)
    end

    # Set to a PEM-format client private key
    def key=(*args)
      cert, passphrase = args.flatten
      ssl_context.key = OpenSSL::PKey::RSA.new(cert, passphrase)
    end

    # Set a path to a file containing a PEM-format CA certificate and enable peer verification
    def ca_file=(path)
      ssl_context.ca_file = path
      ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER unless path.nil?
    end

    # Set the Will for the client
    #
    # The will is a message that will be delivered by the server when the client dies.
    # The Will must be set before establishing a connection to the server
    def set_will(topic, payload, retain = false, qos = 0)
      self.will_topic = topic
      self.will_payload = payload
      self.will_retain = retain
      self.will_qos = qos
    end

    # Connect to the MQTT server
    # If a block is given, then yield to that block and then disconnect again.
    def connect(clientid = nil)
      @client_id = clientid unless clientid.nil?

      if @client_id.nil? || @client_id.empty?
        raise 'Must provide a client_id if clean_session is set to false' unless @clean_session

        # Empty client id is not allowed for version 3.1.0
        @client_id = MQTT::Client.generate_client_id if @version == '3.1.0'
      end

      raise 'No MQTT server host set when attempting to connect' if @host.nil?

      unless connected?
        # Create network socket
        tcp_socket = TCPSocket.new(@host, @port)

        if @ssl
          # Set the protocol version
          ssl_context.ssl_version = @ssl if @ssl.is_a?(Symbol)

          @socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
          @socket.sync_close = true

          # Set hostname on secure socket for Server Name Indication (SNI)
          @socket.hostname = @host if @socket.respond_to?(:hostname=)

          @socket.connect
        else
          @socket = tcp_socket
        end

        # Construct a connect packet
        packet = MQTT::Packet::Connect.new(
          :version => @version,
          :clean_session => @clean_session,
          :keep_alive => @keep_alive,
          :client_id => @client_id,
          :username => @username,
          :password => @password,
          :will_topic => @will_topic,
          :will_payload => @will_payload,
          :will_qos => @will_qos,
          :will_retain => @will_retain
        )

        # Send packet
        send_packet(packet)

        # Receive response
        receive_connack

        # Start packet reading thread
        @read_thread = Thread.new(Thread.current) do |parent|
          Thread.current[:parent] = parent
          receive_packet while connected?
        end
      end

      return unless block_given?

      # If a block is given, then yield and disconnect
      begin
        yield(self)
      ensure
        disconnect
      end
    end

    # Disconnect from the MQTT server.
    # If you don't want to say goodbye to the server, set send_msg to false.
    def disconnect(send_msg = true)
      # Stop reading packets from the socket first
      @read_thread.kill if @read_thread && @read_thread.alive?
      @read_thread = nil

      return unless connected?

      # Close the socket if it is open
      if send_msg
        packet = MQTT::Packet::Disconnect.new
        send_packet(packet)
      end
      @socket.close unless @socket.nil?
      handle_close
      @socket = nil
    end

    # Checks whether the client is connected to the server.
    def connected?
      !@socket.nil? && !@socket.closed?
    end

    # Publish a message on a particular topic to the MQTT server.
    def publish(topic, payload = '', retain = false, qos = 0)
      raise ArgumentError, 'Topic name cannot be nil' if topic.nil?
      raise ArgumentError, 'Topic name cannot be empty' if topic.empty?

      packet = MQTT::Packet::Publish.new(
        :id => next_packet_id,
        :qos => qos,
        :retain => retain,
        :topic => topic,
        :payload => payload
      )

      # Send the packet
      res = send_packet(packet)

      return if qos.zero?

      queue = Queue.new

      wait_for_puback packet.id, queue

      deadline = current_time + @ack_timeout

      loop do
        response = queue.pop
        case response
        when :read_timeout
          return -1 if current_time > deadline
        when :close
          return -1
        else
          @pubacks_semaphore.synchronize do
            @pubacks.delete packet.id
          end
          break
        end
      end

      res
    end

    # Send a subscribe message for one or more topics on the MQTT server.
    # The topics parameter should be one of the following:
    # * String: subscribe to one topic with QoS 0
    # * Array: subscribe to multiple topics with QoS 0
    # * Hash: subscribe to multiple topics where the key is the topic and the value is the QoS level
    #
    # For example:
    #   client.subscribe( 'a/b' )
    #   client.subscribe( 'a/b', 'c/d' )
    #   client.subscribe( ['a/b',0], ['c/d',1] )
    #   client.subscribe( 'a/b' => 0, 'c/d' => 1 )
    #
    def subscribe(*topics)
      packet = MQTT::Packet::Subscribe.new(
        :id => next_packet_id,
        :topics => topics
      )
      send_packet(packet)
    end

    # Return the next message received from the MQTT server.
    # An optional topic can be given to subscribe to.
    #
    # The method either returns the topic and message as an array:
    #   topic,message = client.get
    #
    # Or can be used with a block to keep processing messages:
    #   client.get('test') do |topic,payload|
    #     # Do stuff here
    #   end
    #
    def get(topic = nil, options = {})
      if block_given?
        get_packet(topic) do |packet|
          yield(packet.topic, packet.payload) unless packet.retain && options[:omit_retained]
        end
      else
        loop do
          # Wait for one packet to be available
          packet = get_packet(topic)
          return packet.topic, packet.payload unless packet.retain && options[:omit_retained]
        end
      end
    end

    # Return the next packet object received from the MQTT server.
    # An optional topic can be given to subscribe to.
    #
    # The method either returns a single packet:
    #   packet = client.get_packet
    #   puts packet.topic
    #
    # Or can be used with a block to keep processing messages:
    #   client.get_packet('test') do |packet|
    #     # Do stuff here
    #     puts packet.topic
    #   end
    #
    def get_packet(topic = nil)
      # Subscribe to a topic, if an argument is given
      subscribe(topic) unless topic.nil?

      if block_given?
        # Loop forever!
        loop do
          packet = @read_queue.pop
          yield(packet)
          puback_packet(packet) if packet.qos > 0
        end
      else
        # Wait for one packet to be available
        packet = @read_queue.pop
        puback_packet(packet) if packet.qos > 0
        return packet
      end
    end

    # Returns true if the incoming message queue is empty.
    def queue_empty?
      @read_queue.empty?
    end

    # Returns the length of the incoming message queue.
    def queue_length
      @read_queue.length
    end

    # Clear the incoming message queue.
    def clear_queue
      @read_queue.clear
    end

    # Send a unsubscribe message for one or more topics on the MQTT server
    def unsubscribe(*topics)
      topics = topics.first if topics.is_a?(Enumerable) && topics.count == 1

      packet = MQTT::Packet::Unsubscribe.new(
        :topics => topics,
        :id => next_packet_id
      )
      send_packet(packet)
    end

    private

    # Try to read a packet from the server
    # Also sends keep-alive ping packets.
    def receive_packet
      # Poll socket - is there data waiting?
      result = IO.select([@socket], [], [], SELECT_TIMEOUT)
      handle_timeouts
      unless result.nil?
        # Yes - read in the packet
        packet = MQTT::Packet.read(@socket)
        handle_packet packet
      end
      keep_alive!
      # Pass exceptions up to parent thread
    rescue Exception => exp
      unless @socket.nil?
        @socket.close
        @socket = nil
        handle_close
      end
      Thread.current[:parent].raise(exp)
    end

    def wait_for_puback(id, queue)
      @pubacks_semaphore.synchronize do
        @pubacks[id] = queue
      end
    end

    def handle_packet(packet)
      if packet.class == MQTT::Packet::Publish
        # Add to queue
        @read_queue.push(packet)
      elsif packet.class == MQTT::Packet::Pingresp
        @last_ping_response = current_time
      elsif packet.class == MQTT::Packet::Puback
        @pubacks_semaphore.synchronize do
          @pubacks[packet.id] << packet
        end
      end
      # Ignore all other packets
      # FIXME: implement responses for QoS  2
    end

    def handle_timeouts
      @pubacks_semaphore.synchronize do
        @pubacks.each_value { |q| q << :read_timeout }
      end
    end

    def handle_close
      @pubacks_semaphore.synchronize do
        @pubacks.each_value { |q| q << :close }
      end
    end

    if Process.const_defined? :CLOCK_MONOTONIC
      def current_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    else
      # Support older Ruby
      def current_time
        Time.now.to_f
      end
    end

    def keep_alive!
      return unless @keep_alive > 0 && connected?

      response_timeout = (@keep_alive * 1.5).ceil
      if current_time >= @last_ping_request + @keep_alive
        packet = MQTT::Packet::Pingreq.new
        send_packet(packet)
        @last_ping_request = current_time
      elsif current_time > @last_ping_response + response_timeout
        raise MQTT::ProtocolException, "No Ping Response received for #{response_timeout} seconds"
      end
    end

    def puback_packet(packet)
      send_packet(MQTT::Packet::Puback.new(:id => packet.id))
    end

    # Read and check a connection acknowledgement packet
    def receive_connack
      Timeout.timeout(@ack_timeout) do
        packet = MQTT::Packet.read(@socket)
        if packet.class != MQTT::Packet::Connack
          raise MQTT::ProtocolException, "Response wasn't a connection acknowledgement: #{packet.class}"
        end

        # Check the return code
        if packet.return_code != 0x00
          # 3.2.2.3 If a server sends a CONNACK packet containing a non-zero
          # return code it MUST then close the Network Connection
          @socket.close
          raise MQTT::ProtocolException, packet.return_msg
        end
      end
    end

    # Send a packet to server
    def send_packet(data)
      # Raise exception if we aren't connected
      raise MQTT::NotConnectedException unless connected?

      # Only allow one thread to write to socket at a time
      @write_semaphore.synchronize do
        @socket.write(data.to_s)
      end
    end

    def parse_uri(uri)
      uri = URI.parse(uri) unless uri.is_a?(URI)
      if uri.scheme == 'mqtt'
        ssl = false
      elsif uri.scheme == 'mqtts'
        ssl = true
      else
        raise 'Only the mqtt:// and mqtts:// schemes are supported'
      end

      {
        :host => uri.host,
        :port => uri.port || nil,
        :username => uri.user ? CGI.unescape(uri.user) : nil,
        :password => uri.password ? CGI.unescape(uri.password) : nil,
        :ssl => ssl
      }
    end

    def next_packet_id
      @last_packet_id = (@last_packet_id || 0).next
      @last_packet_id = 1 if @last_packet_id > 0xffff
      @last_packet_id
    end

    # ---- Deprecated attributes and methods  ---- #
    public

    # @deprecated Please use {#host} instead
    def remote_host
      host
    end

    # @deprecated Please use {#host=} instead
    def remote_host=(args)
      self.host = args
    end

    # @deprecated Please use {#port} instead
    def remote_port
      port
    end

    # @deprecated Please use {#port=} instead
    def remote_port=(args)
      self.port = args
    end
  end

  # autoload :Packet,   'mqtt/packet'
  # Class representing a MQTT Packet
  # Performs binary encoding and decoding of headers
  class Packet
    # The version number of the MQTT protocol to use (default 3.1.0)
    attr_accessor :version

    # Identifier to link related control packets together
    attr_accessor :id

    # Array of 4 bits in the fixed header
    attr_accessor :flags

    # The length of the parsed packet body
    attr_reader :body_length

    # Default attribute values
    ATTR_DEFAULTS = {
      :version => '3.1.0',
      :id => 0,
      :body_length => nil
    }

    # Read in a packet from a socket
    def self.read(socket)
      # Read in the packet header and create a new packet object
      packet = create_from_header(
        read_byte(socket)
      )
      packet.validate_flags

      # Read in the packet length
      multiplier = 1
      body_length = 0
      pos = 1

      loop do
        digit = read_byte(socket)
        body_length += ((digit & 0x7F) * multiplier)
        multiplier *= 0x80
        pos += 1
        break if (digit & 0x80).zero? || pos > 4
      end

      # Store the expected body length in the packet
      packet.instance_variable_set('@body_length', body_length)

      # Read in the packet body
      packet.parse_body(socket.read(body_length))

      packet
    end

    # Parse buffer into new packet object
    def self.parse(buffer)
      packet = parse_header(buffer)
      packet.parse_body(buffer)
      packet
    end

    # Parse the header and create a new packet object of the correct type
    # The header is removed from the buffer passed into this function
    def self.parse_header(buffer)
      # Check that the packet is a long as the minimum packet size
      if buffer.bytesize < 2
        raise ProtocolException, 'Invalid packet: less than 2 bytes long'
      end

      # Create a new packet object
      bytes = buffer.unpack('C5')
      packet = create_from_header(bytes.first)
      packet.validate_flags

      # Parse the packet length
      body_length = 0
      multiplier = 1
      pos = 1

      loop do
        if buffer.bytesize <= pos
          raise ProtocolException, 'The packet length header is incomplete'
        end

        digit = bytes[pos]
        body_length += ((digit & 0x7F) * multiplier)
        multiplier *= 0x80
        pos += 1
        break if (digit & 0x80).zero? || pos > 4
      end

      # Store the expected body length in the packet
      packet.instance_variable_set('@body_length', body_length)

      # Delete the fixed header from the raw packet passed in
      buffer.slice!(0...pos)

      packet
    end

    # Create a new packet object from the first byte of a MQTT packet
    def self.create_from_header(byte)
      # Work out the class
      type_id = ((byte & 0xF0) >> 4)
      packet_class = MQTT::PACKET_TYPES[type_id]
      if packet_class.nil?
        raise ProtocolException, "Invalid packet type identifier: #{type_id}"
      end

      # Convert the last 4 bits of byte into array of true/false
      flags = (0..3).map { |i| byte & (2**i) != 0 }

      # Create a new packet object
      packet_class.new(:flags => flags)
    end

    # Create a new empty packet
    def initialize(args = {})
      # We must set flags before the other values
      @flags = [false, false, false, false]
      update_attributes(ATTR_DEFAULTS.merge(args))
    end

    # Set packet attributes from a hash of attribute names and values
    def update_attributes(attr = {})
      attr.each_pair do |k, v|
        if v.is_a?(Array) || v.is_a?(Hash)
          send("#{k}=", v.dup)
        else
          send("#{k}=", v)
        end
      end
    end

    # Get the identifer for this packet type
    def type_id
      index = MQTT::PACKET_TYPES.index(self.class)
      raise "Invalid packet type: #{self.class}" if index.nil?
      index
    end

    # Get the name of the packet type as a string in capitals
    # (like the MQTT specification uses)
    #
    # Example: CONNACK
    def type_name
      self.class.name.split('::').last.upcase
    end

    # Set the protocol version number
    def version=(arg)
      @version = arg.to_s
    end

    # Set the length of the packet body
    def body_length=(arg)
      @body_length = arg.to_i
    end

    # Parse the body (variable header and payload) of a packet
    def parse_body(buffer)
      return if buffer.bytesize == body_length

      raise ProtocolException, "Failed to parse packet - input buffer (#{buffer.bytesize}) is not the same as the body length header (#{body_length})"
    end

    # Get serialisation of packet's body (variable header and payload)
    def encode_body
      '' # No body by default
    end

    # Serialise the packet
    def to_s
      # Encode the fixed header
      header = [
        ((type_id.to_i & 0x0F) << 4) |
          (flags[3] ? 0x8 : 0x0) |
          (flags[2] ? 0x4 : 0x0) |
          (flags[1] ? 0x2 : 0x0) |
          (flags[0] ? 0x1 : 0x0)
      ]

      # Get the packet's variable header and payload
      body = encode_body

      # Check that that packet isn't too big
      body_length = body.bytesize
      if body_length > 268_435_455
        raise 'Error serialising packet: body is more than 256MB'
      end

      # Build up the body length field bytes
      loop do
        digit = (body_length % 128)
        body_length = body_length.div(128)
        # if there are more digits to encode, set the top bit of this digit
        digit |= 0x80 if body_length > 0
        header.push(digit)
        break if body_length <= 0
      end

      # Convert header to binary and add on body
      header.pack('C*') + body
    end

    # Check that fixed header flags are valid for types that don't use the flags
    # @private
    def validate_flags
      return if flags == [false, false, false, false]

      raise ProtocolException, "Invalid flags in #{type_name} packet header"
    end

    # Returns a human readable string
    def inspect
      "\#<#{self.class}>"
    end

    # Read and unpack a single byte from a socket
    def self.read_byte(socket)
      byte = socket.getbyte
      raise ProtocolException, 'Failed to read byte from socket' if byte.nil?

      byte
    end

    protected

    # Encode an array of bytes and return them
    def encode_bytes(*bytes)
      bytes.pack('C*')
    end

    # Encode an array of bits and return them
    def encode_bits(bits)
      [bits.map { |b| b ? '1' : '0' }.join].pack('b*')
    end

    # Encode a 16-bit unsigned integer and return it
    def encode_short(val)
      raise 'Value too big for short' if val > 0xffff
      [val.to_i].pack('n')
    end

    # Encode a UTF-8 string and return it
    # (preceded by the length of the string)
    def encode_string(str)
      str = str.to_s.encode('UTF-8')

      # Force to binary, when assembling the packet
      str.force_encoding('ASCII-8BIT')
      encode_short(str.bytesize) + str
    end

    # Remove a 16-bit unsigned integer from the front of buffer
    def shift_short(buffer)
      bytes = buffer.slice!(0..1)
      bytes.unpack('n').first
    end

    # Remove one byte from the front of the string
    def shift_byte(buffer)
      buffer.slice!(0...1).unpack('C').first
    end

    # Remove 8 bits from the front of buffer
    def shift_bits(buffer)
      buffer.slice!(0...1).unpack('b8').first.split('').map { |b| b == '1' }
    end

    # Remove n bytes from the front of buffer
    def shift_data(buffer, bytes)
      buffer.slice!(0...bytes)
    end

    # Remove string from the front of buffer
    def shift_string(buffer)
      len = shift_short(buffer)
      str = shift_data(buffer, len)
      # Strings in MQTT v3.1 are all UTF-8
      str.force_encoding('UTF-8')
    end

    ## PACKET SUBCLASSES ##

    # Class representing an MQTT Publish message
    class Publish < MQTT::Packet
      # Duplicate delivery flag
      attr_accessor :duplicate

      # Retain flag
      attr_accessor :retain

      # Quality of Service level (0, 1, 2)
      attr_accessor :qos

      # The topic name to publish to
      attr_accessor :topic

      # The data to be published
      attr_accessor :payload

      # Default attribute values
      ATTR_DEFAULTS = {
        :topic => nil,
        :payload => ''
      }

      # Create a new Publish packet
      def initialize(args = {})
        super(ATTR_DEFAULTS.merge(args))
      end

      def duplicate
        @flags[3]
      end

      # Set the DUP flag (true/false)
      def duplicate=(arg)
        @flags[3] = arg.is_a?(Integer) ? (arg == 0x1) : arg
      end

      def retain
        @flags[0]
      end

      # Set the retain flag (true/false)
      def retain=(arg)
        @flags[0] = arg.is_a?(Integer) ? (arg == 0x1) : arg
      end

      def qos
        (@flags[1] ? 0x01 : 0x00) | (@flags[2] ? 0x02 : 0x00)
      end

      # Set the Quality of Service level (0/1/2)
      def qos=(arg)
        @qos = arg.to_i
        raise "Invalid QoS value: #{@qos}" if @qos < 0 || @qos > 2

        @flags[1] = (arg & 0x01 == 0x01)
        @flags[2] = (arg & 0x02 == 0x02)
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''
        if @topic.nil? || @topic.to_s.empty?
          raise 'Invalid topic name when serialising packet'
        end
        body += encode_string(@topic)
        body += encode_short(@id) unless qos.zero?
        body += payload.to_s.dup.force_encoding('ASCII-8BIT')
        body
      end

      # Parse the body (variable header and payload) of a Publish packet
      def parse_body(buffer)
        super(buffer)
        @topic = shift_string(buffer)
        @id = shift_short(buffer) unless qos.zero?
        @payload = buffer
      end

      # Check that fixed header flags are valid for this packet type
      # @private
      def validate_flags
        raise ProtocolException, 'Invalid packet: QoS value of 3 is not allowed' if qos == 3
        raise ProtocolException, 'Invalid packet: DUP cannot be set for QoS 0' if qos.zero? && duplicate
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: " \
          "d#{duplicate ? '1' : '0'}, " \
          "q#{qos}, " \
          "r#{retain ? '1' : '0'}, " \
          "m#{id}, " \
          "'#{topic}', " \
          "#{inspect_payload}>"
      end

      protected

      def inspect_payload
        str = payload.to_s
        if str.bytesize < 16 && str =~ /^[ -~]*$/
          "'#{str}'"
        else
          "... (#{str.bytesize} bytes)"
        end
      end
    end

    # Class representing an MQTT Connect Packet
    class Connect < MQTT::Packet
      # The name of the protocol
      attr_accessor :protocol_name

      # The version number of the protocol
      attr_accessor :protocol_level

      # The client identifier string
      attr_accessor :client_id

      # Set to false to keep a persistent session with the server
      attr_accessor :clean_session

      # Period the server should keep connection open for between pings
      attr_accessor :keep_alive

      # The topic name to send the Will message to
      attr_accessor :will_topic

      # The QoS level to send the Will message as
      attr_accessor :will_qos

      # Set to true to make the Will message retained
      attr_accessor :will_retain

      # The payload of the Will message
      attr_accessor :will_payload

      # The username for authenticating with the server
      attr_accessor :username

      # The password for authenticating with the server
      attr_accessor :password

      # Default attribute values
      ATTR_DEFAULTS = {
        :client_id => nil,
        :clean_session => true,
        :keep_alive => 15,
        :will_topic => nil,
        :will_qos => 0,
        :will_retain => false,
        :will_payload => '',
        :username => nil,
        :password => nil
      }

      # Create a new Client Connect packet
      def initialize(args = {})
        super(ATTR_DEFAULTS.merge(args))

        if version == '3.1.0' || version == '3.1'
          self.protocol_name ||= 'MQIsdp'
          self.protocol_level ||= 0x03
        elsif version == '3.1.1'
          self.protocol_name ||= 'MQTT'
          self.protocol_level ||= 0x04
        else
          raise ArgumentError, "Unsupported protocol version: #{version}"
        end
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''

        if @version == '3.1.0'
          raise 'Client identifier too short while serialising packet' if @client_id.nil? || @client_id.bytesize < 1
          raise 'Client identifier too long when serialising packet' if @client_id.bytesize > 23
        end

        body += encode_string(@protocol_name)
        body += encode_bytes(@protocol_level.to_i)

        if @keep_alive < 0
          raise 'Invalid keep-alive value: cannot be less than 0'
        end

        # Set the Connect flags
        @connect_flags = 0
        @connect_flags |= 0x02 if @clean_session
        @connect_flags |= 0x04 unless @will_topic.nil?
        @connect_flags |= ((@will_qos & 0x03) << 3)
        @connect_flags |= 0x20 if @will_retain
        @connect_flags |= 0x40 unless @password.nil?
        @connect_flags |= 0x80 unless @username.nil?
        body += encode_bytes(@connect_flags)

        body += encode_short(@keep_alive)
        body += encode_string(@client_id)
        unless will_topic.nil?
          body += encode_string(@will_topic)
          # The MQTT v3.1 specification says that the payload is a UTF-8 string
          body += encode_string(@will_payload)
        end
        body += encode_string(@username) unless @username.nil?
        body += encode_string(@password) unless @password.nil?
        body
      end

      # Parse the body (variable header and payload) of a Connect packet
      def parse_body(buffer)
        super(buffer)
        @protocol_name = shift_string(buffer)
        @protocol_level = shift_byte(buffer).to_i
        if @protocol_name == 'MQIsdp' && @protocol_level == 3
          @version = '3.1.0'
        elsif @protocol_name == 'MQTT' && @protocol_level == 4
          @version = '3.1.1'
        else
          raise ProtocolException, "Unsupported protocol: #{@protocol_name}/#{@protocol_level}"
        end

        @connect_flags = shift_byte(buffer)
        @clean_session = ((@connect_flags & 0x02) >> 1) == 0x01
        @keep_alive = shift_short(buffer)
        @client_id = shift_string(buffer)
        if ((@connect_flags & 0x04) >> 2) == 0x01
          # Last Will and Testament
          @will_qos = ((@connect_flags & 0x18) >> 3)
          @will_retain = ((@connect_flags & 0x20) >> 5) == 0x01
          @will_topic = shift_string(buffer)
          # The MQTT v3.1 specification says that the payload is a UTF-8 string
          @will_payload = shift_string(buffer)
        end
        if ((@connect_flags & 0x80) >> 7) == 0x01 && buffer.bytesize > 0
          @username = shift_string(buffer)
        end
        if ((@connect_flags & 0x40) >> 6) == 0x01 && buffer.bytesize > 0 # rubocop: disable Style/GuardClause
          @password = shift_string(buffer)
        end
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        str = "\#<#{self.class}: " \
              "keep_alive=#{keep_alive}"
        str += ', clean' if clean_session
        str += ", client_id='#{client_id}'"
        str += ", username='#{username}'" unless username.nil?
        str += ', password=...' unless password.nil?
        str + '>'
      end

      # ---- Deprecated attributes and methods  ---- #

      # @deprecated Please use {#protocol_level} instead
      def protocol_version
        protocol_level
      end

      # @deprecated Please use {#protocol_level=} instead
      def protocol_version=(args)
        self.protocol_level = args
      end
    end

    # Class representing an MQTT Connect Acknowledgment Packet
    class Connack < MQTT::Packet
      # Session Present flag
      attr_accessor :session_present

      # The return code (defaults to 0 for connection accepted)
      attr_accessor :return_code

      # Default attribute values
      ATTR_DEFAULTS = { :return_code => 0x00 }

      # Create a new Client Connect packet
      def initialize(args = {})
        # We must set flags before other attributes
        @connack_flags = [false, false, false, false, false, false, false, false]
        super(ATTR_DEFAULTS.merge(args))
      end

      # Get the Session Present flag
      def session_present
        @connack_flags[0]
      end

      # Set the Session Present flag
      def session_present=(arg)
        @connack_flags[0] = arg.is_a?(Integer) ? (arg == 0x1) : arg
      end

      # Get a string message corresponding to a return code
      def return_msg
        case return_code
        when 0x00
          'Connection Accepted'
        when 0x01
          'Connection refused: unacceptable protocol version'
        when 0x02
          'Connection refused: client identifier rejected'
        when 0x03
          'Connection refused: server unavailable'
        when 0x04
          'Connection refused: bad user name or password'
        when 0x05
          'Connection refused: not authorised'
        else
          "Connection refused: error code #{return_code}"
        end
      end

      # Get serialisation of packet's body
      def encode_body
        body = ''
        body += encode_bits(@connack_flags)
        body += encode_bytes(@return_code.to_i)
        body
      end

      # Parse the body (variable header and payload) of a Connect Acknowledgment packet
      def parse_body(buffer)
        super(buffer)
        @connack_flags = shift_bits(buffer)
        unless @connack_flags[1, 7] == [false, false, false, false, false, false, false]
          raise ProtocolException, 'Invalid flags in Connack variable header'
        end
        @return_code = shift_byte(buffer)

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Connect Acknowledgment packet'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X>" % return_code
      end
    end

    # Class representing an MQTT Publish Acknowledgment packet
    class Puback < MQTT::Packet
      # Get serialisation of packet's body
      def encode_body
        encode_short(@id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Publish Acknowledgment packet'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X>" % id
      end
    end

    # Class representing an MQTT Publish Received packet
    class Pubrec < MQTT::Packet
      # Get serialisation of packet's body
      def encode_body
        encode_short(@id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Publish Received packet'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X>" % id
      end
    end

    # Class representing an MQTT Publish Release packet
    class Pubrel < MQTT::Packet
      # Default attribute values
      ATTR_DEFAULTS = {
        :flags => [false, true, false, false]
      }

      # Create a new Pubrel packet
      def initialize(args = {})
        super(ATTR_DEFAULTS.merge(args))
      end

      # Get serialisation of packet's body
      def encode_body
        encode_short(@id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Publish Release packet'
      end

      # Check that fixed header flags are valid for this packet type
      # @private
      def validate_flags
        return if @flags == [false, true, false, false]
        raise ProtocolException, 'Invalid flags in PUBREL packet header'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X>" % id
      end
    end

    # Class representing an MQTT Publish Complete packet
    class Pubcomp < MQTT::Packet
      # Get serialisation of packet's body
      def encode_body
        encode_short(@id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Publish Complete packet'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X>" % id
      end
    end

    # Class representing an MQTT Client Subscribe packet
    class Subscribe < MQTT::Packet
      # One or more topic filters to subscribe to
      attr_accessor :topics

      # Default attribute values
      ATTR_DEFAULTS = {
        :topics => [],
        :flags => [false, true, false, false]
      }

      # Create a new Subscribe packet
      def initialize(args = {})
        super(ATTR_DEFAULTS.merge(args))
      end

      # Set one or more topic filters for the Subscribe packet
      # The topics parameter should be one of the following:
      # * String: subscribe to one topic with QoS 0
      # * Array: subscribe to multiple topics with QoS 0
      # * Hash: subscribe to multiple topics where the key is the topic and the value is the QoS level
      #
      # For example:
      #   packet.topics = 'a/b'
      #   packet.topics = ['a/b', 'c/d']
      #   packet.topics = [['a/b',0], ['c/d',1]]
      #   packet.topics = {'a/b' => 0, 'c/d' => 1}
      #
      def topics=(value)
        # Get input into a consistent state
        input = value.is_a?(Array) ? value.flatten : [value]

        @topics = []
        until input.empty?
          item = input.shift
          if item.is_a?(Hash)
            # Convert hash into an ordered array of arrays
            @topics += item.sort
          elsif item.is_a?(String)
            # Peek at the next item in the array, and remove it if it is an integer
            if input.first.is_a?(Integer)
              qos = input.shift
              @topics << [item, qos]
            else
              @topics << [item, 0]
            end
          else
            # Meh?
            raise "Invalid topics input: #{value.inspect}"
          end
        end
        @topics
      end

      # Get serialisation of packet's body
      def encode_body
        raise 'no topics given when serialising packet' if @topics.empty?
        body = encode_short(@id)
        topics.each do |item|
          body += encode_string(item[0])
          body += encode_bytes(item[1])
        end
        body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)
        @topics = []
        while buffer.bytesize > 0
          topic_name = shift_string(buffer)
          topic_qos = shift_byte(buffer)
          @topics << [topic_name, topic_qos]
        end
      end

      # Check that fixed header flags are valid for this packet type
      # @private
      def validate_flags
        return if @flags == [false, true, false, false]
        raise ProtocolException, 'Invalid flags in SUBSCRIBE packet header'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        _str = "\#<#{self.class}: 0x%2.2X, %s>" % [
          id,
          topics.map { |t| "'#{t[0]}':#{t[1]}" }.join(', ')
        ]
      end
    end

    # Class representing an MQTT Subscribe Acknowledgment packet
    class Suback < MQTT::Packet
      # An array of return codes, ordered by the topics that were subscribed to
      attr_accessor :return_codes

      # Default attribute values
      ATTR_DEFAULTS = {
        :return_codes => []
      }

      # Create a new Subscribe Acknowledgment packet
      def initialize(args = {})
        super(ATTR_DEFAULTS.merge(args))
      end

      # Set the granted QoS value for each of the topics that were subscribed to
      # Can either be an integer or an array or integers.
      def return_codes=(value)
        if value.is_a?(Array)
          @return_codes = value
        elsif value.is_a?(Integer)
          @return_codes = [value]
        else
          raise 'return_codes should be an integer or an array of return codes'
        end
      end

      # Get serialisation of packet's body
      def encode_body
        if @return_codes.empty?
          raise 'no granted QoS given when serialising packet'
        end
        body = encode_short(@id)
        return_codes.each { |qos| body += encode_bytes(qos) }
        body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)
        @return_codes << shift_byte(buffer) while buffer.bytesize > 0
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X, rc=%s>" % [id, return_codes.map { |rc| '0x%2.2X' % rc }.join(',')]
      end

      # ---- Deprecated attributes and methods  ---- #

      # @deprecated Please use {#return_codes} instead
      def granted_qos
        return_codes
      end

      # @deprecated Please use {#return_codes=} instead
      def granted_qos=(args)
        self.return_codes = args
      end
    end

    # Class representing an MQTT Client Unsubscribe packet
    class Unsubscribe < MQTT::Packet
      # One or more topic paths to unsubscribe from
      attr_accessor :topics

      # Default attribute values
      ATTR_DEFAULTS = {
        :topics => [],
        :flags => [false, true, false, false]
      }

      # Create a new Unsubscribe packet
      def initialize(args = {})
        super(ATTR_DEFAULTS.merge(args))
      end

      # Set one or more topic paths to unsubscribe from
      def topics=(value)
        @topics = value.is_a?(Array) ? value : [value]
      end

      # Get serialisation of packet's body
      def encode_body
        raise 'no topics given when serialising packet' if @topics.empty?
        body = encode_short(@id)
        topics.each { |topic| body += encode_string(topic) }
        body
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)
        @topics << shift_string(buffer) while buffer.bytesize > 0
      end

      # Check that fixed header flags are valid for this packet type
      # @private
      def validate_flags
        return if @flags == [false, true, false, false]
        raise ProtocolException, 'Invalid flags in UNSUBSCRIBE packet header'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X, %s>" % [
          id,
          topics.map { |t| "'#{t}'" }.join(', ')
        ]
      end
    end

    # Class representing an MQTT Unsubscribe Acknowledgment packet
    class Unsuback < MQTT::Packet
      # Create a new Unsubscribe Acknowledgment packet
      def initialize(args = {})
        super(args)
      end

      # Get serialisation of packet's body
      def encode_body
        encode_short(@id)
      end

      # Parse the body (variable header and payload) of a packet
      def parse_body(buffer)
        super(buffer)
        @id = shift_short(buffer)

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Unsubscribe Acknowledgment packet'
      end

      # Returns a human readable string, summarising the properties of the packet
      def inspect
        "\#<#{self.class}: 0x%2.2X>" % id
      end
    end

    # Class representing an MQTT Ping Request packet
    class Pingreq < MQTT::Packet
      # Create a new Ping Request packet
      def initialize(args = {})
        super(args)
      end

      # Check the body
      def parse_body(buffer)
        super(buffer)

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Ping Request packet'
      end
    end

    # Class representing an MQTT Ping Response packet
    class Pingresp < MQTT::Packet
      # Create a new Ping Response packet
      def initialize(args = {})
        super(args)
      end

      # Check the body
      def parse_body(buffer)
        super(buffer)

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Ping Response packet'
      end
    end

    # Class representing an MQTT Client Disconnect packet
    class Disconnect < MQTT::Packet
      # Create a new Client Disconnect packet
      def initialize(args = {})
        super(args)
      end

      # Check the body
      def parse_body(buffer)
        super(buffer)

        return if buffer.empty?
        raise ProtocolException, 'Extra bytes at end of Disconnect packet'
      end
    end

    # ---- Deprecated attributes and methods  ---- #
    public

    # @deprecated Please use {#id} instead
    def message_id
      id
    end

    # @deprecated Please use {#id=} instead
    def message_id=(args)
      self.id = args
    end
  end

  # An enumeration of the MQTT packet types
  PACKET_TYPES = [
    nil,
    MQTT::Packet::Connect,
    MQTT::Packet::Connack,
    MQTT::Packet::Publish,
    MQTT::Packet::Puback,
    MQTT::Packet::Pubrec,
    MQTT::Packet::Pubrel,
    MQTT::Packet::Pubcomp,
    MQTT::Packet::Subscribe,
    MQTT::Packet::Suback,
    MQTT::Packet::Unsubscribe,
    MQTT::Packet::Unsuback,
    MQTT::Packet::Pingreq,
    MQTT::Packet::Pingresp,
    MQTT::Packet::Disconnect,
    nil
  ]

  # autoload :Proxy,    'mqtt/proxy'
  # Class for implementing a proxy to filter/mangle MQTT packets.
  class Proxy
    # Address to bind listening socket to
    attr_reader :local_host

    # Port to bind listening socket to
    attr_reader :local_port

    # Address of upstream server to send packets upstream to
    attr_reader :server_host

    # Port of upstream server to send packets upstream to.
    attr_reader :server_port

    # Time in seconds before disconnecting an idle connection
    attr_reader :select_timeout

    # Ruby Logger object to send informational messages to
    attr_reader :logger

    # A filter Proc for packets coming from the client (to the server).
    attr_writer :client_filter

    # A filter Proc for packets coming from the server (to the client).
    attr_writer :server_filter

    # Create a new MQTT Proxy instance.
    #
    # Possible argument keys:
    #
    #  :local_host      Address to bind listening socket to.
    #  :local_port      Port to bind listening socket to.
    #  :server_host     Address of upstream server to send packets upstream to.
    #  :server_port     Port of upstream server to send packets upstream to.
    #  :select_timeout  Time in seconds before disconnecting a connection.
    #  :logger          Ruby Logger object to send informational messages to.
    #
    # NOTE: be careful not to connect to yourself!
    def initialize(args = {})
      @local_host = args[:local_host] || '0.0.0.0'
      @local_port = args[:local_port] || MQTT::DEFAULT_PORT
      @server_host = args[:server_host]
      @server_port = args[:server_port] || 18_830
      @select_timeout = args[:select_timeout] || 60

      # Setup a logger
      @logger = args[:logger]
      if @logger.nil?
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::INFO
      end

      # Default is not to have any filters
      @client_filter = nil
      @server_filter = nil

      # Create TCP server socket
      @server = TCPServer.open(@local_host, @local_port)
      @logger.info "MQTT::Proxy listening on #{@local_host}:#{@local_port}"
    end

    # Start accepting connections and processing packets.
    def run
      loop do
        # Wait for a client to connect and then create a thread for it
        Thread.new(@server.accept) do |client_socket|
          logger.info "Accepted client: #{client_socket.peeraddr.join(':')}"
          server_socket = TCPSocket.new(@server_host, @server_port)
          begin
            process_packets(client_socket, server_socket)
          rescue Exception => exp
            logger.error exp.to_s
          end
          logger.info "Disconnected: #{client_socket.peeraddr.join(':')}"
          server_socket.close
          client_socket.close
        end
      end
    end

    private

    def process_packets(client_socket, server_socket)
      loop do
        # Wait for some data on either socket
        selected = IO.select([client_socket, server_socket], nil, nil, @select_timeout)

        # Timeout
        raise 'Timeout in select' if selected.nil?

        # Iterate through each of the sockets with data to read
        if selected[0].include?(client_socket)
          packet = MQTT::Packet.read(client_socket)
          logger.debug "client -> <#{packet.type_name}>"
          packet = @client_filter.call(packet) unless @client_filter.nil?
          unless packet.nil?
            server_socket.write(packet)
            logger.debug "<#{packet.type_name}> -> server"
          end
        elsif selected[0].include?(server_socket)
          packet = MQTT::Packet.read(server_socket)
          logger.debug "server -> <#{packet.type_name}>"
          packet = @server_filter.call(packet) unless @server_filter.nil?
          unless packet.nil?
            client_socket.write(packet)
            logger.debug "<#{packet.type_name}> -> client"
          end
        else
          logger.error 'Problem with select: socket is neither server or client'
        end
      end
    end
  end

  # MQTT-SN
  module SN
    # Default port number for unencrypted connections
    DEFAULT_PORT = 1883

    # A ProtocolException will be raised if there is a
    # problem with data received from a remote host
    class ProtocolException < MQTT::Exception
    end

    autoload :Packet, 'mqtt/sn/packet'
  end
end
