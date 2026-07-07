// Visuals.pde | main entry point for the installation
// It initializes the shared modules, assets, and OSC communication, then delegates application flow to the finite-state machine: 
// DISCLAIMER -> INPUT -> PARTICLES -> THANKS -> INPUT
// State implementations are defined in States.pde and coordinated by the StateMachine class in StateMachine.pde.

// Libraries
  import processing.sound.*;
  
  import oscP5.*;
  import netP5.*;
  
  import java.util.*;

// Global References
  StateMachine  sm;
  ParticleSystem ps;
  AudioManager  audio;
  DevMode       dev;
  InputHandler  inputHandler;
  
  // Fonts
  PFont fontMain;
  PFont fontSmall;
  
  // Sound Effects
  SoundFile sentEffect;
  SoundFile keyEffect;
  
  // OSC
  OscP5 oscTextSender;
  OscP5 oscEmotionsReceiver;
  NetAddress pythonLocation;
  
  // Hash map to store emotions
  HashMap<String, Float> emotions = new HashMap<String, Float>();

// Application SETUP
  void setup() {
    fullScreen(P2D, 1);
    pixelDensity(displayDensity());
    noCursor();

    smooth(8);
    frameRate(30);
    textMode(MODEL);
    colorMode(RGB, 255);
  
    fontMain  = createFont("SourceCodePro-Regular", 32, true);
    fontSmall = createFont("SourceCodePro-Regular", 16, true);
    
    // Initialize shared modules
    audio        = new AudioManager();
    ps           = new ParticleSystem();
    dev          = new DevMode();
    inputHandler = new InputHandler();
    sm           = new StateMachine();
    
    sm.changeState(Config.STATE_DISCLAIMER);
    
    // Sound effects
    sentEffect = new SoundFile(this, "sound_invio.wav");
    keyEffect  = new SoundFile(this, "key_sound.wav");
    
    // OSC setup
    oscTextSender = new OscP5(this, 12000); // porta locale (ricezione eventuale) 
    oscEmotionsReceiver = new OscP5(this, 9000); //porta di ascolto da python !!
  
    pythonLocation = new NetAddress("127.0.0.1", 12001); // python
  }

// Main draw loop
  void draw() {
  
    if (sm.getCurrent() == Config.STATE_PARTICLES) {
  
      pushStyle();
  
      colorMode(RGB, 255);
      rectMode(CORNER);
      noStroke();
  
      fill(Config.BG_COLOR, Config.PARTICLE_PERMANENCE);   // prova 35 invece di 18: scia più corta e meno caos
      rect(0, 0, width, height);
      
  
      popStyle();
  
    } else {
  
      background(Config.BG_COLOR);
  
    }
  
    sm.update();
    sm.render();
  
    if (Config.DEV_MODE && dev.showChladniField) {
      ps.renderChladniField();
    }
  
    if (Config.DEV_MODE) {
      dev.render();
    }
  }

// Keyboard events
  void keyPressed() {
    if (Config.DEV_MODE) {
      dev.handleKey();
    }
    sm.handleKey();
  }
  
  void keyReleased() {
    sm.handleKeyReleased();
  }
