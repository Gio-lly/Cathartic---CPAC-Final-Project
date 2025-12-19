import oscP5.*;
import netP5.*;
import java.util.Map; // Importante per iterare la mappa se serve
OscP5 oscTextSender;
OscP5 audioDataReceiver;
OscP5 emiotionsReceiver;
NetAddress pythonLocation;

//hash map to store emotions
HashMap<String, Float> emotions = new HashMap<String, Float>();
// Mappa che associa il nome dell'emozione a un colore Processing
HashMap<String, Integer> emotionColors = new HashMap<String, Integer>();
// Variabili per il colore corrente (Normalizzati tra 0.0 e 1.0 per PixelFlow)
float currentR = 255f;
float currentG = 255f; // Default Ciano/Blu
float currentB = 255f;

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

PFont sourceCodePro;
float textSizeValue = 50;

PVector vortexCenter;
color liquidColor = color(141, 200, 255);
color textColor = color(255);
boolean showRestart = false;
float restartAlpha = 0;
float pulsePhase = 0;

float audioLevel = 0;

boolean intro_text = true;
float introAlpha = 0;        // fade-in disclaimer
float hintAlpha = 0;         // alpha testo secondario
float hintPhase = 0;         // per pulsazione
float fadeSpeed = 1.5;       // velocità fade-in


void setup() {
  size(1430, 800, P2D);
  // pixelDensity(2); per aumentare risoluzione, ma buggato per colpa di pg. Da fixare.
  frameRate(60);
  
  sourceCodePro = createFont("SourceCodePro-Regular.ttf", textSizeValue, true);
  textFont(sourceCodePro);

  // 1. Inizializziamo lo sfondo nero
  background(0);

  pg = createGraphics(width, height, P2D);

  vortexCenter = new PVector(width/2, height/2);

  //OSC SETUP
  oscTextSender = new OscP5(this, 12000); // porta locale (ricezione eventuale) 

  audioDataReceiver = new OscP5(this, 12003); //porta di ascolto da max !!!

  emiotionsReceiver = new OscP5(this, 12002); //porta di ascolto da python !!

  pythonLocation = new NetAddress("127.0.0.1", 12001); // python
  
  // --- CONFIGURAZIONE COLORI EMOZIONI ---
  // Definiamo i colori base (R, G, B)
  emotionColors.put("anger",   color(255, 0, 0));     // Rosso
  emotionColors.put("joy",     color(255, 255, 0));   // Giallo
  emotionColors.put("disgust", color(0, 255, 0));     // Verde
  emotionColors.put("fear",    color(128, 0, 128));   // Viola
  emotionColors.put("sadness", color(0, 0, 255));     // Blu scuro
  emotionColors.put("realization",color(255, 165, 0));   // Arancione
  emotionColors.put("neutral", color(255, 255, 255)); // Grigio/Bianco
  emotionColors.put("realization",color());
  emotionColors.put("annoyance",color());
  emotionColors.put("grief",color());
  emotionColors.put("remorse",color());
  emotionColors.put("nervousness",color());
  emotionColors.put("gratitude",color());
  //realization
  //annoyance
  //grief
  //remorse
  //nervousness
  //ggratitude
  
}

void draw() {
  // --- FASE 1: GESTIONE SFONDO E SCIE (Modalità BLEND) ---
  blendMode(BLEND); // Reset del blend mode globale
  noStroke();

  background(5);
  
  if (intro_text) {
    // --- Fade-in disclaimer ---
    introAlpha = min(255, introAlpha + fadeSpeed);
    fill(255, introAlpha);
    textAlign(CENTER, CENTER);
    textSize(32);

    text(
      "Everything you write here is private.\n" +
      "Nothing will be saved, used or seen by anyone.\n" +
      "There is no judgment and no record.\n" +
      "You are free to write whatever you want.",
      width / 2,
      height / 2 - 60
    );

    // --- Testo secondario pulsante ---
    hintPhase += 0.03;
    hintAlpha = 80 + 60 * sin(hintPhase); // grigio che appare/scompare

    fill(160, hintAlpha);
    textSize(20);
    text("start typing to begin", width / 2, height / 2 + 120);
  }
  updateFluidColorFromEmotions();
  for (Particle p : particles ) {
    p.update();
  }



  // --- FASE 2: TESTO PREVIEW ---
  fill(250);
  textSize(textSizeValue);
  textAlign(CENTER, height/3);
  //rectMode(CENTER);
  text(typing,0,height/2,width, height);

  // --- FASE 3: PARTICELLE (Modalità ADD per effetto glow) ---
  blendMode(ADD);
  for (Particle p : particles) {
    p.display();
  }
}

void keyPressed() {
  intro_text = false;
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
  color c = color(currentR,currentG,currentB);
  for (int x = 0; x < pg.width; x += step) {
    for (int y = 0; y < pg.height; y += step) {
      int index = x + y * pg.width;
      if (index < pg.pixels.length && brightness(pg.pixels[index]) > 128) {
        particles.add(new Particle(x, y,c));
      }
    }
  }
}

/* Questo metodo viene chiamato automaticamente ogni volta che arriva un messaggio */
void oscEvent(OscMessage theOscMessage) {
  String addr = theOscMessage.addrPattern();
  if (addr.equals("/audiodata/level")) {

    // 2. Controlla se il messaggio contiene un valore float ("f")
    if (theOscMessage.checkTypetag("f")) {
      audioLevel = theOscMessage.get(0).floatValue();
      println(audioLevel);
    }
    // Opzionale: se il valore fosse un intero ("i")
    else if (theOscMessage.checkTypetag("i")) {
      audioLevel = (float)theOscMessage.get(0).intValue();
    }
  }else if (addr.startsWith("/emotion/")){
    float val = 0;
    if (theOscMessage.checkTypetag("f")) {
      val = theOscMessage.get(0).floatValue();
    } else if (theOscMessage.checkTypetag("i")) {
      val = (float)theOscMessage.get(0).intValue();
    }
    // Estrarre il nome dell'emozione dall'indirizzo.
    // L'indirizzo è "/emotion/gioia". 
    // La stringa "/emotion/" è lunga 9 caratteri.
    // Prendiamo tutto ciò che c'è dopo il 9° carattere.
    String emotionName = addr.substring(9); 
    // Salviamo o aggiorniamo il valore nella HashMap
    emotions.put(emotionName, val);
    // Debug: stampa cosa sta succedendo
    //println("Emozione ricevuta: " + emotionName + " -> " + val);
  }
}

//funzione che calcola il colore in base alle emozioni
void updateFluidColorFromEmotions() {
  float sumR = 0;
  float sumG = 0;
  float sumB = 0;
  float totalWeight = 0;

  // Itera su tutte le emozioni ricevute via OSC
  for (String emotionName : emotions.keySet()) {
    
    // Prendi l'intensità (0.0 - 1.0)
    float intensity = emotions.get(emotionName);
    
    // Se l'emozione ha un'intensità rilevante e abbiamo un colore associato
    if (intensity > 0.05 && emotionColors.containsKey(emotionName)) {
      int c = emotionColors.get(emotionName);
      
      // Somma i canali colore pesati per l'intensità
      sumR += red(c) * intensity;
      sumG += green(c) * intensity;
      sumB += blue(c) * intensity;
      
      totalWeight += intensity;
    }
  }

  // Se abbiamo rilevato emozioni, calcoliamo la media
  if (totalWeight > 0) {
    // CORREZIONE: NON dividere per 255.0f. Vogliamo valori 0-255.
    currentR = (sumR / totalWeight);
    currentG = (sumG / totalWeight);
    currentB = (sumB / totalWeight);
  } else {
    // FALLBACK: Se non ci sono emozioni torna al Ciano "Sci-Fi"
    // CORREZIONE: Il terzo parametro di lerp deve essere 0.0-1.0 (es. 0.05 per animazione fluida)
    // Inoltre i target devono essere 0-255
    currentR = lerp(currentR, 255f, 0.05f);   // Rosso a 0
    currentG = lerp(currentG, 255f, 0.05f); // Verde alto
    currentB = lerp(currentB, 255.0f, 0.05f); // Blu massimo
  }
}

void resetSketch() {
  // stato generale
  state = SystemState.TEXT_INPUT;

  typing = "";
  savedText = "";

  activeQuestions.clear();
  particles.clear();

  // intro
  intro_text = true;
  introAlpha = 0;
  hintAlpha = 0;
  hintPhase = 0;

  showRestart = false;
  restartAlpha = 0;
  pulsePhase = 0;

  audioLevel = 0;

  // grafica
  background(0);
  pg.beginDraw();
  pg.clear();
  pg.endDraw();

  vortexCenter.set(width / 2, height / 2);
}


void mousePressed() {
  resetSketch();
}
