#include <ESP32Servo.h>
#include <analogWrite.h>
//#include <tone.h>         // seemed to be missing but was auto added
#include <ESP32Tone.h>
#include <ESP32PWM.h>

#define SWEEP_PERIOD 500    // 0.5 second sweep period for servo demo

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
}

void loop() {
  // put your main code here, to run repeatedly:
  sweepServo();
  delay(20);
}
