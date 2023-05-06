# RasPi Mobile Client

## Log

### setup screen

```
$ git clone https://github.com/goodtft/LCD-show
$ cd LCD-show
$ sudo ./LCD28-show
# failed as maybe my first install using 
#   git clone https://github.com/waveshare/LCD-show.git
# may have misconfigured something?
```

### RBENV

- what about `RBENV`
    - via https://dev.to/konyu/installing-the-latest-version-of-ruby-on-raspberry-pi-3ofk

```sh
# on RasPi
$ sudo apt-get install rbenv
$ export PATH=/home/pi/.rbenv/shims:$PATH

$ rbenv install --list

$ rbenv install jruby-9.2.11.1

# took too long?
$ rbenv install 2.7.1

$ ruby -v

$ jgem install mqtt
$ ruby client.rb
# seems to work

```

### Ruby via ASDF and JRuby

- an existing RasPi connected to the network
- no java

```sh
# took first best guess
$ sudo apt install default-jdk

# gave us error
$ java -version
Error occurred during initialization of VM
Server VM is only supported on ARMv7+ VFP

# as per
$ uname -a
Linux raspberrypi 5.15.32+ #1538 Thu Mar 31 19:37:58 BST 2022 armv6l GNU/Linux

# attempted to install a JDK with ARMv6
$ sudo apt-get install openjdk-8-jre

# but still ARMVv7+ issue

# found this
$ sudo update-alternatives --config java
    There are 2 choices for the alternative java (providing /usr/bin/java).

      Selection    Path                                            Priority   Status
    ------------------------------------------------------------
    * 0            /usr/lib/jvm/java-11-openjdk-armhf/bin/java      1111      auto mode
      1            /usr/lib/jvm/java-11-openjdk-armhf/bin/java      1111      manual mode
      2            /usr/lib/jvm/java-8-openjdk-armhf/jre/bin/java   1081      manual mode

    Press <enter> to keep the current choice[*], or type selection number: 2
    update-alternatives: using /usr/lib/jvm/java-8-openjdk-armhf/jre/bin/java to
        provide /usr/bin/java (java) in manual mode

# and now
$ java -version
openjdk version "1.8.0_312"
OpenJDK Runtime Environment (build 1.8.0_312-8u312-b07-1+rpi1-b07)
OpenJDK Client VM (build 25.312-b07, mixed mode)

✅
```

- no ruby

```sh
# as per instructions for ASDF
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.11.3

# and fix up ~/.bashrc
    . "$HOME/.asdf/asdf.sh"
    . "$HOME/.asdf/completions/asdf.bash" 

$ asdf plugin add ruby
$ adsf install ruby 3.2.1
$ asdf install ruby jruby-9.4.2.0
$ asdf install ruby mruby-3.2.0
$ asdf install ruby picoruby-3.0.0

# all failed with
BUILD FAILED (Raspbian 11 using ruby-build 20230428)

# just download jruby
# via https://www.jruby.org/download

$ wget https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.4.2.0/jruby-dist-9.4.2.0-bin.tar.gz
$ tar -zxvf jruby-dist-9.4.2.0-bin.tar.gz
$ export PATH=/home/pi/jruby-9.4.2.0/bin:$PATH
$ jruby -v
    jruby 9.4.2.0 (3.1.0) 2023-03-08 90d2913fda OpenJDK Client VM 25.312-b07 on 1.8.0_312-8u312-b07-1+rpi1-b07 +jit [arm-linux]

# but
$ bundle
$ jgem install mqtt
$ jruby client.rb
# all returned

    #
    # A fatal error has been detected by the Java Runtime Environment:
    #
    #  SIGILL (0x4) at pc=0xab732060, pid=13383, tid=0xb4fad440
    #
    # JRE version: OpenJDK Runtime Environment (8.0_312-b07)
    #       (build 1.8.0_312-8u312-b07-1+rpi1-b07)
    # Java VM: OpenJDK Client VM (25.312-b07 mixed mode linux-aarch32 )
    # Problematic frame:
    # C  [libjffi-1.2.so+0x6060]
    #
    # Failed to write core dump. Core dumps have been disabled. To enable core
    # dumping, try "ulimit -c unlimited" before starting Java again
    #
    # An error report file with more information is saved as:
    # /home/pi/Projects/kickboxer-vs-ruby/apps/demo_using_mqtt/hs_err_pid13383.log
    #
    # If you would like to submit a bug report, please visit:
    #   http://bugreport.java.com/bugreport/crash.jsp
    # The crash happened outside the Java Virtual Machine in native code.
    # See problematic frame for where to report the bug.
    #
    Aborted
```

## RasPi Setup

- debug over UART
    - via https://www.ibeyonde.com/raspberry-pi-serial-ports.html
    - and [Raspberry Pi Serial Connect to USB via FTDI - Intermation](https://www.youtube.com/watch?v=ONvNtz2w-qE)
    - mount SD card with RasPi OS
    - edit boot -> config.txt
    - add the following line

```
    [all]
    enable_uart=1
```

    - eject and re-load
- find UART on mac

```
    ls /dev | ag usb
        cu.usbserial-AL00J9IS
        tty.usbserial-AL00J9IS
```

- wire up and connect via screen?

```
    -------------------------------------------
   |                              3.3V  1* * 2 | 5V
   |----                                 * * 4 | 5V
   |POW |                                * * 6 | GND
   |----                                 * * 8 | GPIO14 (UART_TXD0)
   |                                     * *10 | GPIO15 (UART_RXD0)
   |                                     * *   | GPIO18 (GPIO_GEN1)
   |--                                   * *   | GND
   | H |                                 * *   | GPIO23 (SPI_GEN4)
   | D |                                 * *   | GPIO24 (SPI_GEN$)
   | M |      RasPi GPIO10 (SPIO_MOSI) 19* *   | GND
   | I |                                 * *   | GPIO25 (SPI_GEN6)
   |--                                   * *   | GPIO8 (SPI_CE0_N)
   |                                     * *   | GPIO7 (SPI_CE1_N)
   |                                     * *   | ID_SC (I2C EEPROM)
   | SOUND                               * *   | GND
   |                                     * *   | GPIO12
   |                                     * *   | GND
   |                                     * *   | GPIO16
   |                                     * *   | GPIO20
   |                                   39* *40 | GPIO21
   |   ---                                     |
   |  |   |        ___   ___                   |
   |  |ETH|       |USB| |USB|                  |
    -------------------------------------------
```
    - connect UART

```
   3.3V  1* * 2 | 5V
         3* * 4 | 5V -----------------> VCC - RED ------|
         5* * 6 | GND ----------------> GND - BLACK ----|-- FTDI/UART via USB
         7* * 8 | GPIO14 (UART_TXD0) -> RX -- YELLOW ---|
         9* *10 | GPIO15 (UART_RXD0) -> TX -- ORANGE ---|
```

    - connect via screen

```
screen /dev/tty.usbserial-AL00J9IS 115200

# to terminate screen
# CTR A - CTR \
```
