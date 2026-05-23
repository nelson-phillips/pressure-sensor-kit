import processing.serial.*;

Serial myPort;
boolean connected = false;
String[] fileList;
String statusMessage = "Click 'Connect to Arduino' to begin";
String serialBuffer = "";
boolean receivingFiles = false;
boolean receivingFileContent = false;
ArrayList<String> receivedFiles = new ArrayList<String>();
StringBuilder fileContent = new StringBuilder();

// Button properties
Button connectBtn, displayBtn, lookupBtn, retrieveBtn, saveBtn;
int btnWidth = 200, btnHeight = 40;

// New UI elements for file lookup
String selectedFileName = "";
String fileNumberInput = "";
boolean textInputActive = false;
int textInputX, textInputY, textInputWidth, textInputHeight;

// File content display area
int contentBoxX, contentBoxY, contentBoxWidth, contentBoxHeight;
String displayedContent = "";
int contentScrollOffset = 0;

class Button {
  float x, y, w, h;
  String label;
  boolean hovered;
  boolean pressed;
  boolean enabled;
  long lastClickTime;
  long debounceDelay = 200; // 200ms debounce delay
  color normalColor;
  color hoverColor;
  color pressedColor;
  color disabledColor;
  color textColor;
  color disabledTextColor;
  
  Button(float x, float y, float w, float h, String label) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.label = label;
    this.hovered = false;
    this.pressed = false;
    this.enabled = true;
    this.lastClickTime = 0;
    
    // Default color scheme
    this.normalColor = color(60, 70, 100);
    this.hoverColor = color(80, 90, 130);
    this.pressedColor = color(100, 110, 150);
    this.disabledColor = color(40, 40, 50);
    this.textColor = color(220);
    this.disabledTextColor = color(120);
  }
  
  void draw() {
    updateHover();
    
    // Draw button background with appropriate color
    if (!enabled) {
      fill(disabledColor);
    } else if (pressed) {
      fill(pressedColor);
    } else if (hovered) {
      fill(hoverColor);
    } else {
      fill(normalColor);
    }
    
    // Button shadow effect
    if (enabled) {
      fill(0, 0, 0, 30);
      rect(x + 2, y + 2, w, h, 8);
    }
    
    // Main button
    if (!enabled) {
      fill(disabledColor);
    } else if (pressed) {
      fill(pressedColor);
    } else if (hovered) {
      fill(hoverColor);
    } else {
      fill(normalColor);
    }
    
    stroke(enabled ? color(100) : color(70));
    strokeWeight(1);
    rect(x, y, w, h, 8);
    
    // Draw button label
    if (enabled) {
      fill(textColor);
    } else {
      fill(disabledTextColor);
    }
    
    textAlign(CENTER, CENTER);
    textSize(14);
    text(label, x + w/2, y + h/2);
    textAlign(LEFT);
    
    // Draw debounce indicator if recently clicked
    if (millis() - lastClickTime < debounceDelay && enabled) {
      float progress = (float)(millis() - lastClickTime) / debounceDelay;
      fill(255, 200, 0, 100);
      rect(x, y, w * progress, h, 8);
    }
    
    // Reset stroke
    strokeWeight(1);
  }
  
  void updateHover() {
    hovered = (mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h);
  }
  
  boolean isClicked() {
    if (!enabled) return false;
    
    // Check if mouse is over button and pressed
    boolean mouseOver = (mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h);
    boolean mouseDown = mousePressed;
    
    // Check debounce timing
    long currentTime = millis();
    if (mouseOver && mouseDown && (currentTime - lastClickTime > debounceDelay)) {
      lastClickTime = currentTime;
      return true;
    }
    return false;
  }
  
  void setEnabled(boolean enabled) {
    this.enabled = enabled;
  }
  
  boolean isEnabled() {
    return enabled;
  }
  
  long timeSinceLastClick() {
    return millis() - lastClickTime;
  }
}

void setup() {
  size(1200, 1000);
  surface.setTitle("Arduino SD Card File Viewer & Data Retriever");
  
  // Initialize buttons
  connectBtn = new Button(width/2 - btnWidth/2, 100, btnWidth, btnHeight, "Connect to Arduino");
  displayBtn = new Button(width/2 - btnWidth/2, 160, btnWidth, btnHeight, "Display Files");
  lookupBtn = new Button(width/2 - btnWidth/2, 300, btnWidth, btnHeight, "Lookup File by Number");
  retrieveBtn = new Button(width/2 - btnWidth/2, 400, btnWidth, btnHeight, "Retrieve Data");
  saveBtn = new Button(width/2 - btnWidth/2, 450, btnWidth, btnHeight, "Save to CSV");
  
  displayBtn.setEnabled(false); // Disabled until connected
  lookupBtn.setEnabled(false); // Disabled until files are loaded
  retrieveBtn.setEnabled(false); // Disabled until file is selected
  saveBtn.setEnabled(false); // Disabled until data is retrieved
  
  // Setup text input area for file number
  textInputX = width/2 - btnWidth/2;
  textInputY = 260;
  textInputWidth = btnWidth;
  textInputHeight = 30;
  
  // Setup file content display area (repositioned)
  contentBoxX = 600;
  contentBoxY = 500;
  contentBoxWidth = 560;
  contentBoxHeight = 400;
  
  // List available serial ports
  println("Available serial ports:");
  printArray(Serial.list());
}

void draw() {
  background(40, 40, 160);
  
  // Draw title
  fill(220, 230, 255);
  textSize(24);
  textAlign(CENTER);
  text("Arduino SD Card File Viewer & Data Retriever", width/2, 50);
  
  // Update button pressed state
  connectBtn.pressed = connectBtn.hovered && mousePressed && connectBtn.isEnabled();
  displayBtn.pressed = displayBtn.hovered && mousePressed && displayBtn.isEnabled();
  lookupBtn.pressed = lookupBtn.hovered && mousePressed && lookupBtn.isEnabled();
  retrieveBtn.pressed = retrieveBtn.hovered && mousePressed && retrieveBtn.isEnabled();
  saveBtn.pressed = saveBtn.hovered && mousePressed && saveBtn.isEnabled();
  
  // Draw buttons
  connectBtn.draw();
  displayBtn.draw();
  lookupBtn.draw();
  retrieveBtn.draw();
  saveBtn.draw();
  
  // Draw connection status
  textSize(14);
  if (connected) {
    fill(100, 255, 100);
    text("✓ Connected to Arduino", width-360, 120);
    // Enable display button when connected
    if (!displayBtn.isEnabled()) {
      displayBtn.setEnabled(true);
    }
  } else {
    fill(255, 100, 100);
    text("✗ Not Connected", width-360, 120);
    // Disable display button when not connected
    if (displayBtn.isEnabled()) {
      displayBtn.setEnabled(false);
    }
  }
  
  // Draw status message
  fill(200, 220, 255);
  textAlign(LEFT);
  textSize(12);
  text("Status: " + statusMessage, width - 360, 152);
  
  // Draw file lookup section
  drawFileLookupSection();
  
  // Draw file count if available
  if (fileList != null) {
    fill(180, 220, 255);
    text("Files found on SD Card: " + fileList.length, 500, 230);
    showFileDialog();
  }
  
  // Draw file content display area
  drawFileContentBox();
  
  // Draw debounce indicator
  fill(180, 180, 200, 150);
  textSize(10);
  if (connectBtn.timeSinceLastClick() < connectBtn.debounceDelay) {
    float remaining = (connectBtn.debounceDelay - connectBtn.timeSinceLastClick()) / 1000.0;
    text("Connect button cooldown: " + nf(remaining, 1, 1) + "s", 50, 290);
  } else if (displayBtn.timeSinceLastClick() < displayBtn.debounceDelay) {
    float remaining = (displayBtn.debounceDelay - displayBtn.timeSinceLastClick()) / 1000.0;
    text("Display button cooldown: " + nf(remaining, 1, 1) + "s", 50, 290);
  } else if (lookupBtn.timeSinceLastClick() < lookupBtn.debounceDelay) {
    float remaining = (lookupBtn.debounceDelay - lookupBtn.timeSinceLastClick()) / 1000.0;
    text("Lookup button cooldown: " + nf(remaining, 1, 1) + "s", 50, 290);
  } else if (retrieveBtn.timeSinceLastClick() < retrieveBtn.debounceDelay) {
    float remaining = (retrieveBtn.debounceDelay - retrieveBtn.timeSinceLastClick()) / 1000.0;
    text("Retrieve button cooldown: " + nf(remaining, 1, 1) + "s", 50, 290);
  } else if (saveBtn.timeSinceLastClick() < saveBtn.debounceDelay) {
    float remaining = (saveBtn.debounceDelay - saveBtn.timeSinceLastClick()) / 1000.0;
    text("Save button cooldown: " + nf(remaining, 1, 1) + "s", 50, 290);
  }
  
  // Draw instructions
  fill(180);
  textSize(10);
  text("Instructions:\n1. Click 'Connect to Arduino'\n2. Click 'Display Files' to list files\n3. Enter file number below\n4. Click 'Lookup File by Number'\n5. Click 'Retrieve Data' to get file content\n6. Click 'Save to CSV' to save data locally\n\nShortcuts:\nPress 'C' to connect\nPress 'D' to display files\nPress 'L' to lookup file\nPress 'R' to retrieve data\nPress 'S' to save to CSV\n\nButtons are debounced (200ms)", 30, 100);
}

void drawFileLookupSection() {
  // Draw label for file number input
  fill(200, 220, 255);
  textSize(12);
  textAlign(LEFT);
  text("Enter file number (1 to " + (fileList != null ? fileList.length : "?") + "):", 
       textInputX, textInputY - 10);
  
  // Draw text input box
  if (textInputActive) {
    fill(255, 255, 200); // Yellow when active
  } else {
    fill(255); // White when inactive
  }
  stroke(100);
  strokeWeight(1);
  rect(textInputX, textInputY, textInputWidth, textInputHeight, 5);
  
  // Draw input text
  fill(0);
  textSize(14);
  textAlign(LEFT, CENTER);
  text(fileNumberInput + (textInputActive && frameCount % 60 < 30 ? "|" : ""), 
       textInputX + 10, textInputY + textInputHeight/2);
  textAlign(LEFT);
  
  // Draw lookup result
  if (!selectedFileName.isEmpty()) {
    fill(200, 255, 200);
    textSize(12);
    textAlign(LEFT);
    text("Selected File", textInputX + 220, textInputY + textInputHeight + 85);
    
    fill(220, 255, 220);
    textSize(14);
    stroke(100, 200, 100);
    strokeWeight(1);
    fill(240, 255, 240);
    rect(textInputX, textInputY + textInputHeight + 65, textInputWidth, 40, 5);
    
    fill(0, 100, 0);
    textAlign(CENTER, CENTER);
    textSize(12);
    text(selectedFileName, textInputX + textInputWidth/2, textInputY + textInputHeight + 85);
    textAlign(LEFT);
  }
}

void drawFileContentBox() {
  // Draw content box background
  fill(255); // White background
  stroke(100);
  strokeWeight(2);
  rect(contentBoxX, contentBoxY, contentBoxWidth, contentBoxHeight, 10);
  
  // Draw title
  fill(0, 0, 0);
  textSize(16);
  textAlign(CENTER);
  text("File Content", contentBoxX + contentBoxWidth/2, contentBoxY - 10);
  
  // Draw content
  fill(0); // Black text
  textSize(12);
  textAlign(LEFT, TOP);
  
  // Calculate visible text area
  int padding = 10;
  int textAreaX = contentBoxX + padding;
  int textAreaY = contentBoxY + padding;
  int textAreaWidth = contentBoxWidth - 2 * padding;
  int textAreaHeight = contentBoxHeight - 2 * padding;
  
  // Draw a subtle scroll indicator
  if (displayedContent.length() > 0) {
    // Wrap text and display
    String[] lines = displayedContent.split("\n");
    int lineHeight = 16;
    int startLine = max(0, contentScrollOffset);
    int visibleLines = min(lines.length - startLine, textAreaHeight / lineHeight);
    
    // Draw visible lines
    for (int i = 0; i < visibleLines; i++) {
      int lineNum = startLine + i;
      if (lineNum < lines.length) {
        text(lines[lineNum], textAreaX, textAreaY + i * lineHeight);
      }
    }
    
    // Draw scroll info if needed
    if (lines.length > visibleLines) {
      fill(100);
      textSize(10);
      text("Use mouse wheel to scroll (" + (startLine+1) + "-" + (startLine+visibleLines) + " of " + lines.length + " lines)", 
           contentBoxX + 10, contentBoxY + contentBoxHeight - 20);
    }
  } else {
    fill(150);
    text("No file content loaded.\nSelect a file and click 'Retrieve Data'.", 
         textAreaX, textAreaY);
  }
  
  // Draw file info if content is loaded
  if (!selectedFileName.isEmpty() && displayedContent.length() > 0) {
    fill(250, 100, 0);
    textSize(12);
    textAlign(LEFT);
    text("File: " + selectedFileName + " (" + displayedContent.length() + " chars)", 
         contentBoxX + 360, contentBoxY + contentBoxHeight - 410);
  }
  
  textAlign(LEFT);
}

void mousePressed() {
  // Handle button clicks with debounce
  connectBtn.updateHover();
  displayBtn.updateHover();
  lookupBtn.updateHover();
  retrieveBtn.updateHover();
  saveBtn.updateHover();
  
  // Check if clicking on text input box
  boolean clickedOnInput = mouseX >= textInputX && mouseX <= textInputX + textInputWidth &&
                          mouseY >= textInputY && mouseY <= textInputY + textInputHeight;
  
  if (clickedOnInput) {
    textInputActive = true;
  } else {
    textInputActive = false;
  }
  
  // Check for button clicks with visual feedback
  if (connectBtn.isClicked()) {
    connectBtn.pressed = true;
    connectToArduino();
  } else if (displayBtn.isClicked()) {
    displayBtn.pressed = true;
    displayFiles();
  } else if (lookupBtn.isClicked()) {
    lookupBtn.pressed = true;
    lookupFileByNumber();
  } else if (retrieveBtn.isClicked()) {
    retrieveBtn.pressed = true;
    retrieveFileData();
  } else if (saveBtn.isClicked()) {
    saveBtn.pressed = true;
    saveToCSV();
  }
}

void mouseReleased() {
  // Reset button pressed state
  connectBtn.pressed = false;
  displayBtn.pressed = false;
  lookupBtn.pressed = false;
  retrieveBtn.pressed = false;
  saveBtn.pressed = false;
}

void connectToArduino() {
  // Disconnect if already connected
  if (connected && myPort != null) {
    myPort.stop();
    connected = false;
    statusMessage = "Disconnected from Arduino";
    displayBtn.setEnabled(false);
    lookupBtn.setEnabled(false);
    retrieveBtn.setEnabled(false);
    saveBtn.setEnabled(false);
    return;
  }
  
  // Try to connect to Arduino
  String portName = "";
  String[] ports = Serial.list();
  
  if (ports.length == 0) {
    statusMessage = "No serial ports found!";
    return;
  }
  
  // Look for common Arduino ports
  for (String port : ports) {
    if (port.contains("usbmodem") || port.contains("COM") || port.contains("ttyUSB") || port.contains("ttyACM")) {
      portName = port;
      break;
    }
  }
  
  if (portName.isEmpty()) {
    portName = ports[0];  // Use first available port
  }
  
  try {
    myPort = new Serial(this, portName, 9600);
    myPort.bufferUntil('\n');
    statusMessage = "Connecting to " + portName + "...";
    connected = true;
    
    // Clear any old data
    delay(500);
    myPort.clear();
    
  } catch (Exception e) {
    statusMessage = "Connection failed: " + e.getMessage();
    connected = false;
  }
}

void displayFiles() {
  if (!connected || myPort == null) {
    statusMessage = "Not connected to Arduino!";
    return;
  }
  
  // Disable buttons temporarily during operation
  displayBtn.setEnabled(false);
  lookupBtn.setEnabled(false);
  retrieveBtn.setEnabled(false);
  saveBtn.setEnabled(false);
  
  // Initialize SD card first
  statusMessage = "Initializing SD card...";
  myPort.write("CONNECT\n");
  
  // Wait a moment then request file list
  delay(1500);
  statusMessage = "Requesting file list...";
  myPort.write("LIST\n");
  receivingFiles = true;
  receivedFiles.clear();
}

void lookupFileByNumber() {
  if (fileList == null || fileList.length == 0) {
    selectedFileName = "No files loaded!";
    retrieveBtn.setEnabled(false);
    saveBtn.setEnabled(false);
    return;
  }
  
  if (fileNumberInput.isEmpty()) {
    selectedFileName = "Please enter a file number";
    retrieveBtn.setEnabled(false);
    saveBtn.setEnabled(false);
    return;
  }
  
  try {
    int fileNumber = Integer.parseInt(fileNumberInput);
    if (fileNumber < 1 || fileNumber > fileList.length) {
      selectedFileName = "Invalid number! (1-" + fileList.length + ")";
      retrieveBtn.setEnabled(false);
      saveBtn.setEnabled(false);
    } else {
      // Extract just the file name from the list entry
      String fileEntry = fileList[fileNumber - 1];
      if (fileEntry.startsWith("FILE: ")) {
        // Extract just the filename (before the space before size)
        String temp = fileEntry.substring(6); // Remove "FILE: "
        // Remove anything after the file size info
        int sizeIndex = temp.lastIndexOf(" (");
        if (sizeIndex > 0) {
          selectedFileName = temp.substring(0, sizeIndex).trim();
        } else {
          selectedFileName = temp.trim();
        }
      } else if (fileEntry.startsWith("DIR: ")) {
        selectedFileName = "DIR: " + fileEntry.substring(5);
        retrieveBtn.setEnabled(false);
        saveBtn.setEnabled(false);
      } else {
        selectedFileName = fileEntry;
      }
      
      statusMessage = "Selected file #" + fileNumber;
      
      // Only enable retrieve button if it's a file (not a directory)
      if (!selectedFileName.startsWith("DIR: ")) {
        retrieveBtn.setEnabled(true);
      }
      
      println("Selected file #" + fileNumber + ": " + selectedFileName);
      // Clear previous content
      displayedContent = "";
      saveBtn.setEnabled(false); // Disable save until data is retrieved
    }
  } catch (NumberFormatException e) {
    selectedFileName = "Please enter a valid number";
    retrieveBtn.setEnabled(false);
    saveBtn.setEnabled(false);
  }
}

void retrieveFileData() {
  if (!connected || myPort == null) {
    statusMessage = "Not connected to Arduino!";
    return;
  }
  
  if (selectedFileName.isEmpty() || selectedFileName.startsWith("DIR: ")) {
    statusMessage = "Please select a valid file (not a directory)";
    return;
  }
  
  // Clear previous content
  displayedContent = "";
  fileContent = new StringBuilder();
  receivingFileContent = true;
  
  // Send READ command to Arduino
  statusMessage = "Reading file: " + selectedFileName;
  myPort.write("READ " + selectedFileName + "\n");
  
  // Disable retrieve and save buttons while reading
  retrieveBtn.setEnabled(false);
  saveBtn.setEnabled(false);
}

void saveToCSV() {
  if (displayedContent.isEmpty()) {
    statusMessage = "No data to save!";
    return;
  }
  
  if (selectedFileName.isEmpty()) {
    statusMessage = "No file selected!";
    return;
  }
  
  // Create CSV filename based on selected file name
  String csvFilename = "";
  if (selectedFileName.contains(".")) {
    // Replace existing extension with .csv
    int dotIndex = selectedFileName.lastIndexOf('.');
    csvFilename = selectedFileName.substring(0, dotIndex) + ".csv";
  } else {
    // No extension, just append .csv
    csvFilename = selectedFileName + ".csv";
  }
  
  // Split the content into lines
  String[] lines = displayedContent.split("\n");
  
  // Save to CSV file
  try {
    saveStrings(csvFilename, lines);
    statusMessage = "Data saved to: " + csvFilename;
    println("Data saved to: " + csvFilename + " (" + lines.length + " lines)");
  } catch (Exception e) {
    statusMessage = "Error saving file: " + e.getMessage();
    println("Error saving file: " + e.getMessage());
  }
}

void serialEvent(Serial p) {
  try {
    String incoming = p.readStringUntil('\n');
    if (incoming == null) return;
    
    incoming = incoming.trim();
    
    // Debug output
    println("Received: " + incoming);
    
    // Update status based on Arduino messages
    if (incoming.startsWith("Initializing SD card")) {
      statusMessage = "SD Card: " + incoming.substring(21);
    } 
    else if (incoming.startsWith("Card type:")) {
      statusMessage = incoming;
    }
    else if (incoming.startsWith("SD Card Size:")) {
      statusMessage = incoming;
    }
    else if (incoming.equals("PONG")) {
      statusMessage = "Arduino is responding!";
    }
    else if (incoming.startsWith("ERROR:")) {
      statusMessage = incoming.substring(7);
      // Re-enable display button on error
      if (connected) {
        displayBtn.setEnabled(true);
      }
    }
    else if (incoming.equals("START_FILE_LIST")) {
      receivedFiles.clear();
      statusMessage = "Receiving file list...";
    }
    else if (incoming.equals("END_FILE_LIST")) {
      receivingFiles = false;
      statusMessage = "File list received!";
      
      // Convert ArrayList to array
      fileList = new String[receivedFiles.size()];
      for (int i = 0; i < receivedFiles.size(); i++) {
        fileList[i] = receivedFiles.get(i);
      }
      
      // Show file list in console dialog
      showFileDialog();
      
      // Re-enable buttons
      if (connected) {
        displayBtn.setEnabled(true);
        lookupBtn.setEnabled(true);
      }
    }
    else if (incoming.equals("START_FILE_CONTENT")) {
      receivingFileContent = true;
      fileContent = new StringBuilder();
      statusMessage = "Receiving file content...";
    }
    else if (incoming.equals("END_FILE_CONTENT")) {
      receivingFileContent = false;
      displayedContent = fileContent.toString();
      statusMessage = "File content received!";
      
      // Re-enable retrieve and save buttons
      if (!selectedFileName.isEmpty() && !selectedFileName.startsWith("DIR: ")) {
        retrieveBtn.setEnabled(true);
        saveBtn.setEnabled(true);
      }
    }
    else if (incoming.startsWith("READ_ERROR:")) {
      statusMessage = "Error reading file: " + incoming.substring(11);
      receivingFileContent = false;
      if (!selectedFileName.isEmpty() && !selectedFileName.startsWith("DIR: ")) {
        retrieveBtn.setEnabled(true);
      }
      saveBtn.setEnabled(false);
    }
    else if (receivingFileContent) {
      // Append ALL incoming lines during content reception (raw file content)
      fileContent.append(incoming).append("\n");
    }
    else if (receivingFiles && (incoming.startsWith("FILE:") || incoming.startsWith("DIR:"))) {
      receivedFiles.add(incoming);
    }
    else if (incoming.startsWith("Total files found:")) {
      statusMessage = incoming;
    }
    else if (!incoming.isEmpty()) {
      // Keep last message as status
      if (!incoming.startsWith("Arduino SD Card")) { // Filter out initial greeting
        statusMessage = incoming;
      }
    }
  } catch (Exception e) {
    println("Error reading serial: " + e.getMessage());
    // Re-enable buttons on error
    if (connected) {
      displayBtn.setEnabled(true);
      lookupBtn.setEnabled(true);
      if (!selectedFileName.isEmpty() && !selectedFileName.startsWith("DIR: ")) {
        retrieveBtn.setEnabled(true);
        if (!displayedContent.isEmpty()) {
          saveBtn.setEnabled(true);
        }
      }
    }
  }
}

void showFileDialog() {
  if (fileList == null || fileList.length == 0) {
    println("\n=== NO FILES FOUND ===");
    statusMessage = "No files found on SD card";
    lookupBtn.setEnabled(false);
    retrieveBtn.setEnabled(false);
    saveBtn.setEnabled(false);
    return;
  }
  
  // Draw file list box
  fill(255);
  stroke(0);
  strokeWeight(2);
  rect(50, 320, 500, 400, 10);
  
  // Draw title in the box
  fill(0, 0, 100);
  textSize(14);
  textAlign(CENTER);
  text("Files on SD Card (" + fileList.length + " found)", 250, 350);
  
  // Draw files in the box
  fill(0);
  textSize(12);
  textAlign(LEFT);
  int startY = 380;
  int lineHeight = 16;
  
  for (int i = 0; i < min(fileList.length, 22); i++) { // Show max 22 files
    text((i+1) + ". " + fileList[i], 110, startY + i * lineHeight);
  }
  
  if (fileList.length > 22) {
    fill(100, 0, 0);
    text("... and " + (fileList.length - 22) + " more files", 110, startY + 22 * lineHeight);
  }
  
  // Draw scroll indicator
  fill(200);
  textSize(10);
  textAlign(CENTER);
  text("↑↓ Use scroll wheel if more files", 250, 755);
  
  // Also print to console
  println("\n" + "═".repeat(50));
  println("    FILES ON ARDUINO SD CARD");
  println("═".repeat(50));
  println("Total files and directories: " + fileList.length);
  println("-".repeat(50));
  
  for (int i = 0; i < fileList.length; i++) {
    println((i+1) + ". " + fileList[i]);
  }
  
  println("═".repeat(50));
  println("Note: Files are shown in the Processing console.");
  println("═".repeat(50) + "\n");
  
  statusMessage = "File list loaded (" + fileList.length + " items)";
}

void keyPressed() {
  // Handle text input
  if (textInputActive) {
    if (key == BACKSPACE || key == DELETE) {
      if (fileNumberInput.length() > 0) {
        fileNumberInput = fileNumberInput.substring(0, fileNumberInput.length() - 1);
      }
    } else if (key == ENTER || key == RETURN) {
      lookupFileByNumber();
    } else if (key == ESC) {
      textInputActive = false;
    } else if (key >= '0' && key <= '9') {
      // Only allow numbers
      if (fileNumberInput.length() < 4) { // Limit to 4 digits
        fileNumberInput += key;
      }
    }
  } else {
    // Keyboard shortcuts with debounce
    long currentTime = millis();
    
    if ((key == 'c' || key == 'C') && currentTime - connectBtn.lastClickTime > connectBtn.debounceDelay) {
      connectBtn.lastClickTime = currentTime;
      connectToArduino();
    } else if ((key == 'd' || key == 'D') && currentTime - displayBtn.lastClickTime > displayBtn.debounceDelay) {
      displayBtn.lastClickTime = currentTime;
      displayFiles();
    } else if ((key == 'l' || key == 'L') && currentTime - lookupBtn.lastClickTime > lookupBtn.debounceDelay) {
      lookupBtn.lastClickTime = currentTime;
      lookupFileByNumber();
    } else if ((key == 'r' || key == 'R') && currentTime - retrieveBtn.lastClickTime > retrieveBtn.debounceDelay) {
      retrieveBtn.lastClickTime = currentTime;
      retrieveFileData();
    } else if ((key == 's' || key == 'S') && currentTime - saveBtn.lastClickTime > saveBtn.debounceDelay) {
      saveBtn.lastClickTime = currentTime;
      saveToCSV();
    } else if (key == ' ') {
      // Space toggles connection with debounce
      if (currentTime - connectBtn.lastClickTime > connectBtn.debounceDelay) {
        connectBtn.lastClickTime = currentTime;
        if (connected) {
          if (myPort != null) {
            myPort.stop();
          }
          connected = false;
          statusMessage = "Disconnected";
          displayBtn.setEnabled(false);
          lookupBtn.setEnabled(false);
          retrieveBtn.setEnabled(false);
          saveBtn.setEnabled(false);
        } else {
          connectToArduino();
        }
      }
    }
  }
}

void mouseWheel(MouseEvent event) {
  // Scroll file content
  float e = event.getCount();
  contentScrollOffset += e * 3; // Scroll 3 lines per wheel click
  contentScrollOffset = max(0, contentScrollOffset);
  
  // Also limit maximum scroll
  String[] lines = displayedContent.split("\n");
  int maxScroll = max(0, lines.length - (contentBoxHeight - 20) / 16);
  contentScrollOffset = min(contentScrollOffset, maxScroll);
  
  println("Scrolled to line: " + contentScrollOffset);
}
