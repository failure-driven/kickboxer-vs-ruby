#include <ESP32Servo.h>
#include <analogWrite.h>
//#include <tone.h>         // seemed to be missing but was auto added
#include <ESP32Tone.h>
#include <ESP32PWM.h>

//#include <Arduino.h>
#include <U8x8lib.h>

#define SWEEP_PERIOD 500    // 0.5 second sweep period for servo demo

// Not exactly sure which is needed here ¯\_(ツ)_/¯
#ifdef U8X8_HAVE_HW_SPI
#include <SPI.h>
#endif
#ifdef U8X8_HAVE_HW_I2C
#include <Wire.h>
#endif

// not sure what this is
U8X8_SSD1306_128X64_NONAME_HW_I2C u8x8(/* reset=*/ U8X8_PIN_NONE);

const int servoPin = 4;     // SWEEP servo
Servo myservo;

void sweepServo() {
  int millisPosition = millis() % SWEEP_PERIOD;
  double floatPosition = TWO_PI * (((float) millisPosition ) / SWEEP_PERIOD);
  int servoPosition = (70 * sin(floatPosition)) + 90;
  Serial.println(servoPosition);
  myservo.write(servoPosition);
}

void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  Serial.print("Kickboxer Client");

  myservo.attach(servoPin);
  myservo.attach(servoPin);

  u8x8.begin();
  //  u8x8.setFlipMode(1); // Allow the display to be flipped
  u8x8.clear();
  u8x8.setFont(u8x8_font_amstrad_cpc_extended_f);
  u8x8.print("Kickboxer");
  u8x8.setCursor(0, 1);
  u8x8.print("Actuator");
}

// some hints on other things that can be done with the display from
// https://tronixstuff.com/2019/08/29/ssd1306-arduino-tutorial/
//  u8x8.inverse();
//  u8x8.print(" U8x8 Library ");
//  u8x8.setFont(u8x8_font_chroma48medium8_r);
//  u8x8.noInverse();
//  draw_bar example with printing " " in rows
//  can use  u8x8.getCols() and  u8x8.getRows() for width and heigh
//  u8x8.write(a); to write a 0..255 ASCII character
//  u8x8.draw2x2String(0, 5, "Scale Up");
//  u8x8.setFont(u8x8_font_px437wyse700b_2x2_r);
//  u8x8.setFont(u8x8_font_inb33_3x6_n);
//  u8x8.drawString(0, 2, u8x8_u16toa(i, 5)); // U8g2 Build-In functions
//  u8x8.setFont(u8x8_font_open_iconic_weather_4x4);
//  u8x8.drawGlyph(0, 4, '@' + c); // C 0..6

void loop() {
  // put your main codel here, to run repeatedly:
  sweepServo();
  u8x8.setFont(u8x8_font_inb33_3x6_n);
  u8x8.setCursor(0, 2);
  u8x8.print(millis());
  //  delay(1000);
  delay(20);
}
