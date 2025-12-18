import oscP5.*;
import netP5.*;
OscP5 oscTextSender;
OscP5 audioDataReceiver;
NetAddress pythonLocation;

enum SystemState {
  TEXT_INPUT,     // scrivi
  MORPH_TO_VORTEX,// il testo si rompe
  VORTEX          // memoria liquida persistente
}

SystemState state = SystemState.TEXT_INPUT;
String[] questions =
  { "What are you afraid of?",
  "What do you wish you had said?",
  "What are you holding back?",
  "What do you want to forget?",
  "What stays with you?",
  "Luca" };
ArrayList<VisualQuestion> activeQuestions = new
ArrayList<VisualQuestion>();
int lastTypingTime; // timestamp ultimo tasto premuto
int idleDelay = 10000; // 10 secondi
ArrayList<Particle> particles = new ArrayList<Particle>();
String typing = "";
String savedText = "";
PGraphics pg;


float textSizeValue = 120;

PVector vortexCenter;
color liquidColor = color(141, 200, 255);
color textColor = color(255);
boolean showRestart = false;
float restartAlpha = 0;
float pulsePhase = 0;

float audioLevel = 0;

void setup() {
  size(1000, 1000, P2D);

  // 1. Inizializziamo lo sfondo nero
  background(0);

  pg = createGraphics(width, height, P2D);


  vortexCenter = new PVector(width/2, height/2);

  //OSC SETUP
  oscTextSender = new OscP5(this, 12000); // porta locale (ricezione eventuale)

  audioDataReceiver = new OscP5(this, 12003); //porta di ascolto da max !!!


  pythonLocation = new NetAddress("127.0.0.1", 12001); // python
}

void draw() {
  // --- FASE 1: GESTIONE SFONDO E SCIE (Modalità BLEND) ---
  blendMode(BLEND); // Reset del blend mode globale
  noStroke();

  background(0);
  fill(0,10);
  rect(0, 0, width, height);
  
  for (Particle p : particles ) {
    p.update();
  }



  // --- FASE 2: TESTO PREVIEW ---
  fill(255);
  textSize(textSizeValue);
  textAlign(CENTER, height/3);
  text(typing, width/2, height/2);

  // --- FASE 3: PARTICELLE (Modalità ADD per effetto glow) ---
  blendMode(ADD);
  for (Particle p : particles) {
    p.display();
  }
}

void keyPressed() {
  if (key == RETURN || key == ENTER) {
    if (typing.length() > 0) {

      savedText = typing;

      OscMessage msg = new OscMessage("/text");
      msg.add(savedText);
      oscTextSender.send(msg, pythonLocation);

     // 2. Aggiungiamo nuove particelle (nuova memoria)
      createTextParticles(savedText);
      // 1. Le particelle esistenti restano dov’erano
      for (Particle p : particles) {
        if (p.pState == ParticleState.TEXT) {
          p.pState = ParticleState.RELEASED;
        }
      }

      

      // 3. Cambiamo stato globale
      state = SystemState.MORPH_TO_VORTEX;

      typing = "";
    }
  } else if (key == BACKSPACE) {
    if (typing.length() > 0) {
      typing = typing.substring(0, typing.length() - 1);
    }
  } else if (keyCode != SHIFT && keyCode != CONTROL && keyCode != ALT) {
    typing += key;
  }
}

void createTextParticles(String t) {
  pg.beginDraw();
  pg.background(0);
  pg.fill(255);
  pg.textSize(textSizeValue);
  pg.textAlign(CENTER, CENTER);
  pg.text(t, width/2, height/2);
  pg.endDraw();

  pg.loadPixels();

  int step = 3;

  for (int x = 0; x < pg.width; x += step) {
    for (int y = 0; y < pg.height; y += step) {
      int index = x + y * pg.width;
      if (index < pg.pixels.length && brightness(pg.pixels[index]) > 128) {
        particles.add(new Particle(x, y));
      }
    }
  }
}

/* Questo metodo viene chiamato automaticamente ogni volta che arriva un messaggio */
void oscEvent(OscMessage theOscMessage) {

  if (theOscMessage.checkAddrPattern("/audiodata/level")) {

    // 2. Controlla se il messaggio contiene un valore float ("f")
    if (theOscMessage.checkTypetag("f")) {
      audioLevel = theOscMessage.get(0).floatValue();
      println(audioLevel);
    }
    // Opzionale: se il valore fosse un intero ("i")
    else if (theOscMessage.checkTypetag("i")) {
      audioLevel = (float)theOscMessage.get(0).intValue();
    }
  }
}
