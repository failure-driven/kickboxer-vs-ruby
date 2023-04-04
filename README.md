# Kickboxer vs Ruby

[![Build Kickboxer vs Ruby](https://github.com/failure-driven/kickboxer-vs-ruby/actions/workflows/build.yml/badge.svg)](
https://github.com/failure-driven/kickboxer-vs-ruby/actions/workflows/build.yml)

## TL;DR

```sh
# sync submodule
git submodule init
git submodule update --recursive
# git submodule sync --recursive

# install and check tools
make
make install
# this source needs to be done manually
source ./vendor/esp-idf/export.sh
make check-tools

# build the mruby actuator code
cd apps/mruby_actuator
idf.py build
# which fails due to an environment setting deep inside the build which cannot
# load the associated ESP32 libraries
# eg
#   cmake -E env \
#       MRUBY_CONFIG=../esp32_build_config.rb CC=$HOME/.espressif/tools/xtensa-esp32-elf/esp-2022r1-11.2.0/xtensa-esp32-elf/bin/xtensa-esp32-elf-gcc \
#       LD=$HOME/.espressif/tools/xtensa-esp32-elf/esp-2022r1-11.2.0/xtensa-esp32-elf/bin/xtensa-esp32-elf-ld \
#       AR=$HOME/.espressif/tools/xtensa-esp32-elf/esp-2022r1-11.2.0/xtensa-esp32-elf/bin/xtensa-esp32-elf-ar \
#       "COMPONENT_INCLUDES=../../../../../vendor/esp-idf/components/esp_wifi/include" \
#       rake
#
# Results in
#
#   GIT CHECKOUT DETACH kickboxer-vs-ruby/apps/mruby_actuator/components/mruby_component/mruby/build/repos/esp32/mruby-esp32-system -> \
#       f2d6c152b6d652f084958cbf903d955e717b3c20
#   HEAD is now at f2d6c15 Merge pull request #1 from vickash/master
#   GIT   https://github.com/mruby-esp32/mruby-esp32-wifi.git -> build/repos/esp32/mruby-esp32-wifi
#   Cloning into 'kickboxer-vs-ruby/apps/mruby_actuator/components/mruby_component/mruby/build/repos/esp32/mruby-esp32-wifi'...
#   fatal: Remote branch HEAD not found in upstream origin
#   rake aborted!
#
# TEMPORARY work around is to run build in vendor/mruby-esp32 which will
# correctly extract the required build repos and manually copy across the
# correctly git cloned repos
# assuming in:
#   apps/mruby_actuator
cd ../../vendor/mruby-esp32
idf.py build
cd - # to jump back to ../../apps/mruby_actuator
cp -r \
    ../../vendor/mruby-esp32/components/mruby_component/mruby/build/repos/* \
    components/mruby_component/mruby/build/repos
# now build should work
idf.py build

# assuming the correct port -p below
idf.py -p /dev/cu.usbserial-0001 flash

# only output to terminal via serial so use screen to connect
screen /dev/tty.usbserial-0001 115200
# to quit screen: CMD-A CMD-\

# run a mosquitto server
cd ./apps/demo_using_mqtt
docker-compose up

# monitor messages sent to mosquitto server
mosquitto_sub -h localhost -t \# -d
```

## Goals

- [ ] long journey of ups and downs
- [ ] Overview current state of Hardware development and using MRuby
- [ ] Mobile development using JRuby
- [ ] tying it all together on the server with CRuby.
- [ ] talk will demonstrate how to get started with MRuby for hardware
- [ ] limitations and benefits of using Ruby for hardware
- [ ] It will touch on what is involved in using JRuby to power Android mobile
  devices
- [ ] it will wrap up with a demonstration of a system composed of MRuby, JRuby
  and CRuby
- [ ] Finally, a demonstration of the sparing robot will be performed live on
  stage

## Progress

- [x] concept demo using sockets [apps/demo_using_sockets](apps/demo_using_sockets)
- [x] switch to MQTT server like https://mosquitto.org/ ✅ OR https://www.hivemq.com/ ⁉️
- [ ] write Arduion/ESP32 code to move a servo
    - BUT CAN IT RUBY? - take a look at mruby on ESP32
- [ ] write a basic frontend for Android to connect to MQTT server
    - BUT CAN IT RUBY?
    - look at http://www.rubymotion.com/ and https://dragonruby.org/ and
      https://github.com/ruboto/ruboto (actual JRuby)

## [Research](REASEARCH.md)

