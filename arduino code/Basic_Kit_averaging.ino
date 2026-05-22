#include <Adafruit_ADS1X15.h>
#include <EEPROM.h>
#include <Wire.h>
#include "SparkFunBME280.h"

// Adafruit_ADS1115 ads;  /* Use this for the 16-bit version */
Adafruit_ADS1015 ads;   // not used atm  /* Use this for the 12-bit version */
BME280 mySensor; // Uses default I2C address 0x77
int sensorBaro0;
const int SWITCH_PIN = 4;          // Digital button pin (internal pull-up)
const int ANALOG_PINS[] = {A0, A1, A2, A3}; // Analog input pins
const int NUM_READINGS = 20;        // Number of samples per average
const int DELAY_TIME = 50;          // Delay between samples (ms)
const int MAX_TRIGGERS = 10;        // Max number of trigger cycles
const int No_Sensors = 5;
const int No_Analog_Sensors = 4;

int triggerCount = 0;               // Count of completed triggers

// Debouncing variables
unsigned long lastDebounceTime = 0;
const int debounceDelay = 50;        // Debounce time in ms
int lastButtonState = HIGH;          // Previous raw reading
int buttonState = HIGH;              // Debounced current state
int lastDebouncedState = HIGH;       // Previous debounced state (for edge detection)

void setup() {
  Serial.begin(9600); while (!Serial);
  pinMode(SWITCH_PIN, INPUT_PULLUP); // Enable internal pull-up resistor
  delay(500);
  
  Wire.begin();
  Wire.setClock(400000);

  mySensor.setI2CAddress(0x76); // changes to BME280 sensor address 0x76
  if (mySensor.beginI2C() == false) { Serial.println("Sensor A connect failed"); }
  mySensor.setReferencePressure(101200);
  
  Serial.println(" hello "); // just checking if this is alive
  initialisation_BME_sensor(); // needed due to the barometric sensor requiring a cycle
}

void loop() {
  // Debounce the button
  int reading = digitalRead(SWITCH_PIN);

  if (reading != lastButtonState) {
    lastDebounceTime = millis();    // reset the debouncing timer
    lastButtonState = reading;
  }

  if ((millis() - lastDebounceTime) > debounceDelay) {
    // whatever the reading is at, it's been there for longer than the debounce delay,
    // so take it as the actual current state
    buttonState = reading;
  }

  // Detect a falling edge (press) – button goes from HIGH to LOW
  if (lastDebouncedState == HIGH && buttonState == LOW) {
    if (triggerCount < MAX_TRIGGERS) {
      readAndStoreAnalog();
      triggerCount++;
      Serial.print("triggerCount ");
      Serial.println(triggerCount);
    }
  }
  lastDebouncedState = buttonState; // save for next loop

  // Serial commands (unchanged)
  if (Serial.available() > 0) {
    int inByte = Serial.read();
    switch (inByte) {
      case 'w':
        Serial.println("write");
        readAndStoreAnalog();
        triggerCount++;
        Serial.print("triggerCount ");
        Serial.println(triggerCount);
        break;
      case 'r':
        Serial.println("reading");
        printStoredData();
        break;
      // other cases commented out
    }
  }
}

void readAndStoreAnalog() {
  unsigned long sums[] = {0, 0, 0, 0, 0}; // Sum buffers for each channel
  Serial.println(" writing1 ");
  
  for (int i = 0; i < NUM_READINGS; i++) {
    for (int ch = 0; ch < 4; ch++) {
      sums[ch] += analogRead(ANALOG_PINS[ch]);
    }
    unsigned long valuebb = mySensor.readFloatPressure();
    valuebb = valuebb / 100;
    int valueB = (int)valuebb;
    sums[4] += valueB;
    delay(DELAY_TIME);
  }

  int baseAddress = triggerCount * 10; // 10 bytes per trigger (5 values × 2 bytes)
  
  for (int ch = 0; ch < 5; ch++) {
    int average = sums[ch] / NUM_READINGS;
    int address = baseAddress + (ch * 2);
    
    EEPROM.write(address, highByte(average));
    EEPROM.write(address + 1, lowByte(average));
  }
}

void printStoredData() {
  for (int t = 0; t < MAX_TRIGGERS; t++) {
    Serial.print("Trigger ");
    Serial.print(t);
    Serial.println(":");
    
    for (int ch = 0; ch < 5; ch++) {
      int address = (t * 10) + (ch * 2);
      byte high = EEPROM.read(address);
      byte low = EEPROM.read(address + 1);
      int value = (high << 8) | low;
      
      Serial.print("  CH");
      Serial.print(ch);
      Serial.print(": ");
      Serial.println(value);
    }
  }
  for (int i = 0 ; i < EEPROM.length() ; i++) {
    EEPROM.write(i, 0);
  }
  triggerCount = 0;
}

void initialisation_BME_sensor() {
  mySensor.readFloatHumidity();
  mySensor.readFloatPressure();
  mySensor.readFloatAltitudeMeters();
  mySensor.readTempC();
  Serial.print("Humidity: ");
  Serial.print(mySensor.readFloatHumidity(), 0);
  Serial.print(" Pressure: ");
  Serial.print(mySensor.readFloatPressure());
  Serial.print(" Locally Adjusted Altitude: ");
  Serial.print(mySensor.readFloatAltitudeMeters(), 1);
  Serial.print(" Temp: ");
  Serial.print(mySensor.readTempC(), 2);
  Serial.println();
}
