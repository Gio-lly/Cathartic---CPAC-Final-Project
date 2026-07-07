// Osc.pde | OSC communication between Processing and Python
// Sends user prompts to Python and receives emotion values and configuration parameters used by the visualization.

    // Sends the user text prompt to Python via OSC
    void sendTextToPython(String text) {
        OscMessage msg = new OscMessage("/text");
        msg.add(text);
        oscTextSender.send(msg, pythonLocation);
        println("[OSC] Message sent to python: " + text);
    }

    // Handles incoming OSC messages from Python
    void oscEvent(OscMessage theOscMessage) {
      
      String addr = theOscMessage.addrPattern();
  
  if (addr.equals("/config/particles_duration")) {
       // Synchronizes the Processing duration with the emotion envelope timings configured in Python
    if (theOscMessage.checkTypetag("f")) {
      Config.PARTICLES_DURATION = (int) theOscMessage.get(0).floatValue();
      println("[OSC] PARTICLES_DURATION set from Python: " + Config.PARTICLES_DURATION + "ms");
    }
  } else if (addr.startsWith("/emotion/")){
    float val = 0;
    if (theOscMessage.checkTypetag("f")) {val = theOscMessage.get(0).floatValue();}
    else {println("valore non float");}
    
    // Extracts the emotion name from the "/emotion/<name>" address
    String emotionName = addr.substring(9); 
    
    // Stores the received value or updates the existing emotion
    emotions.put(emotionName, val);
  }
}
