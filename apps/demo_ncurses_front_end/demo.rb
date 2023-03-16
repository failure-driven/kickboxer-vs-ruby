# frozen_string_literal: true

require "curses"

include Curses # rubocop:disable Style/MixinUsage

# start with
# connection status
# devices:
#     ... waiting for devices
#     - device 1
#     - device 2 # clicking ENTER should write "hit" at the bottom
# quit
#

@index = 0

init_screen
start_color

init_pair(1, 1, 0)
curs_set(0)
noecho

devices = ["device a", "device b", "device c"]

begin
  win = Curses::Window.new(0, 0, 1, 2)

  loop do
    win.setpos(0, 0)

    devices.each.with_index(0) do |name, index|
      if index == @index
        win.attron(color_pair(1)) { win << name }
      else
        win << name
      end
      clrtoeol
      win << "\n"
    end
    win.refresh

    str = win.getch.to_s
    case str
    when "j"
      @index = (@index >= (devices.length - 1)) ? (devices.length - 1) : @index + 1
    when "k"
      @index = (@index <= 0) ? 0 : @index - 1
    when "10" # enter key
      @selected = devices[@index]
      exit 0
    when "q" then exit 0
    end
  end
ensure
  close_screen
end
