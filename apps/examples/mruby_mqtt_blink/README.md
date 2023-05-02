# mruby MQTT blink

## setup

not sure how to reduce this as yet

```
mkdir mruby_mqtt_blink
cd mruby_mqtt_blink

cp ../../mruby_actuator/.gitignore .
cp ../../mruby_actuator/CMakeLists.txt .
cp ../../mruby_actuator/partitions.csv .
cp ../../mruby_actuator/sdkconfig .
cp -r ../../mruby_actuator/main .
cp -r ../../mruby_actuator/components .
rm -rf components/mruby_component/mruby

git submodule add --force git@github.com:mruby/mruby.git components/mruby_component/mruby

# will fail
idf.py build

cp -r \
  ../../../vendor/mruby-esp32/components/mruby_component/mruby/build/repos/* \
  components/mruby_component/mruby/build/repos

# will succeed
idf.py build

# flash to device
idf.py -p /dev/cu.usbserial-0001 flash
```
