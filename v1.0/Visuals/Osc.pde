// Function to send text prompt to python via osc
void sendTextToPython(String text) {
    OscMessage msg = new OscMessage("/text");
    msg.add(text);
    oscTextSender.send(msg, pythonLocation);
    //for (String key : emotions.keySet()) emotions.put(key, 0f); // resetto emotions
    println("[OSC] Message sent to python: " + text);
}


// Function that runs everytime an osc message is received
void oscEvent(OscMessage theOscMessage) {
  
  String addr = theOscMessage.addrPattern();
  //println(theOscMessage);
  
  if (addr.startsWith("/emotion/")){
    float val = 0;
    if (theOscMessage.checkTypetag("f")) {val = theOscMessage.get(0).floatValue();}
    else {println("valore non float");}
    
    // Estrarre il nome dell'emozione dall'indirizzo.
    // L'indirizzo è "/emotion/gioia". 
    // La stringa "/emotion/" è lunga 9 caratteri.
    // Prendiamo tutto ciò che c'è dopo il 9° carattere.
    String emotionName = addr.substring(9); 
    //println(emotionName);
    
    // Salviamo o aggiorniamo il valore nella HashMap
    emotions.put(emotionName, val);
    // Debug: stampa cosa sta succedendo
    // println("Emozione ricevuta: " + emotionName + " -> " + val);
  }
}
