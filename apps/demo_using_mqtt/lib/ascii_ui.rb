# frozen_string_literal: true

require "io/console" # visual input

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

  def paint_actuator
    puts "\e[H\e[2J"

    paint_in_a_box("actuator", ["🥊"], nil)
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
    when "\u0003", "q" # CTRL-C ^C
      exit
    else
      puts "WTF #{action.inspect}"
    end
    paint
  end

  def hit
    (5..0).step(-1).each do |offset|
      sleep(0.05)
      printf "%#{offset}s\e[E\e[U", "🥊"
    end
    6.times do |offset|
      printf "%#{offset}s\e[E\e[U", "🥊"
      sleep(0.05)
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

