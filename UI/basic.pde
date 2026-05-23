
import processing.serial.*;

Serial arduinoPort;
String[] dataList = new String[0];
int scrollOffset = 0;
boolean connected = false;

void setup() {
  size(1200, 800);
  textFont(createFont("Arial", 14));
  
  // Attempt to connect to COM3 (adjust for your system)
  try {
    arduinoPort = new Serial(this, "COM3", 9600);//!!!_alter "COM3" if port is diiferent it likely is different!!
    connected = true;
    arduinoPort.bufferUntil('\n');
  } 
  catch (Exception e) {
    println("  Error connecting to port:", e.getMessage());
    connected = false;
  }
}

void draw() {
  background(240);
  
  // Draw control panel
  fill(200);
  rect(0, 0, 300, height);
  
  // Draw buttons
  drawButton(50, 100, 200, 40, "Record to EEPROM");
  drawButton(50, 160, 200, 40, "Fetch Data");
  drawButton(50, 220, 200, 40, "Save to CSV");
  
  // Draw data display
  if (connected) {
    drawDataWindow(320, 20, width-340, height-40);
  } else {
    fill(255, 0, 0);
    text("Not connected to Arduino", 150, 300);
    text("_CHECK COM PORT NUMBER!_", 150, 350);
  }
}

void drawButton(int x, int y, int w, int h, String label) {
  fill(mouseOver(x, y, w, h) ? 150 : 180);
  rect(x, y, w, h, 5);
  fill(0);
  textAlign(CENTER, CENTER);
  text(label, x + w/2, y + h/2);
}

void drawDataWindow(int x, int y, int w, int h) {
  fill(255);
  rect(x, y, w, h);
  
  // Calculate visible items
  int itemsVisible = h / 20;
  int start = max(0, scrollOffset);
  int end = min(dataList.length, start + itemsVisible);
  
  // Draw visible items
  fill(0);
  textAlign(LEFT, TOP);
  for (int i = start; i < end; i++) {
    if (i < dataList.length) {
      text(dataList[i], x + 10, y + 10 + (i - start) * 20);
    }
  }
  
  // Draw scrollbar
  if (dataList.length > itemsVisible) {
    float scrollHeight = h * (float)itemsVisible/dataList.length;
    float scrollPos = map(scrollOffset, 0, dataList.length - itemsVisible, 0, h - scrollHeight);
    fill(200);
    rect(x + w - 20, y + scrollPos, 20, scrollHeight);
  }
}

void mousePressed() {
  if (mouseOver(50, 100, 200, 40)) {
    arduinoPort.write("w");
  } else if (mouseOver(50, 160, 200, 40)) {
    arduinoPort.write("r");
    dataList = new String[0]; // Clear previous data
  } else if (mouseOver(50, 220, 200, 40)) {
    String filename = getUniqueFilename();
    saveStrings(filename, dataList);
    println("Saved: " + filename);
  }
}

void mouseWheel(MouseEvent event) {
  scrollOffset -= event.getCount();
  scrollOffset = constrain(scrollOffset, 0, max(0, dataList.length - (height-60)/20));
}

void serialEvent(Serial p) {
  String incoming = p.readStringUntil('\n').trim();
  if (incoming == null) return;
  
  // Filter out status messages
  if (incoming.startsWith("CSV") || incoming.startsWith("Data")) {
    println("Status:", incoming);
    return;
  }
  
  // Add valid data lines to list
  if (!incoming.equals("")) {
    dataList = append(dataList, incoming);
    scrollOffset = max(0, dataList.length - (height-60)/20);
  }
}

boolean mouseOver(int x, int y, int w, int h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}

String getUniqueFilename() {
  String base = "sensor_data";
  String extension = ".csv";
  int counter = 0;
  String filename = base + extension;
  
  while (new File(sketchPath(filename)).exists()) {
    filename = base + "_" + counter + extension;
    counter++;
  }
  return filename;
}
