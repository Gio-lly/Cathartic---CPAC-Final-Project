// =============================================================
//  CATHARTIC VISUALS
// =============================================================
//  
//  This system works in different states:
//    InputState      — user types a prompt; on ENTER seeds
//                      particles from text pixels and switches state
//    ParticlesState  — runs the Chladni simulation driven by
//                      audio; fades out after a set duration
//    ThanksState     — closing screen, then back to InputState
//
//  Each state is a class that inherits from the BaseState in StateMachine.pde
//  In StateMachine.pde there is also the StateMachine class that
//  describes how the system switch from a state to another and how they behave.
//
//  Managers:
//    AudioManager    — Minim wrapper; mic or file audio,
//                      exposes amplitude, FFT and kick detection
//    ParticleSystem  — Chladni physics + render; reacts to audio
//    InputHandler    — string buffer for the text input
//
//  Utilities:
//    Config.pde: all tunable constants.
//    DevMode.pde: Overlay debug + developers commands
//
//  This Visuals.pde code is used to initialize everything and start the StateMachine.
// =============================================================

// Library for audio analysis
import processing.sound.*;

// Library for communication
import oscP5.*;
import netP5.*;

// utils
import java.util.*;


// ── Riferimenti globali ──────────────────────────────────────
StateMachine  sm;
ParticleSystem ps;
AudioManager  audio;
DevMode       dev;
InputHandler  inputHandler;

// ── Font ─────────────────────────────────────────────────────
PFont fontMain;
PFont fontSmall;

// ── Sound fxs ─────────────────────────────────────────────────────
SoundFile sentEffect;
SoundFile keyEffect;

// ── OSC ─────────────────────────────────────────────────────
OscP5 oscTextSender;
OscP5 oscEmotionsReceiver;
OscP5 audioDataReceiver;
NetAddress pythonLocation;

// ── Hash map to store emotions ──────────────────────────────
HashMap<String, Float> emotions = new HashMap<String, Float>();

// =============================================================
void setup() {
  size(1280, 720, P2D);           // Cambia con fullScreen() per l'installazione
  //fullScreen(2);
  pixelDensity(2);           // Migliore qualità pixels
  
  smooth(8);                 // Draws all geometry with smooth (anti-aliased) edges
  frameRate(60);
  textMode(MODEL);
  colorMode(RGB, 255);
  
  // Font (metti un .ttf nella cartella /data oppure usa createFont)
  fontMain  = createFont("SourceCodePro-Regular", 32, true);
  fontSmall = createFont("SourceCodePro-Regular", 16, true);
  
  // Inizializzazione moduli
  audio        = new AudioManager();
  ps           = new ParticleSystem();
  dev          = new DevMode();
  inputHandler = new InputHandler();
  sm           = new StateMachine();
  
  sm.changeState(Config.STATE_DISCLAIMER);
  
  // sound fxs
  sentEffect = new SoundFile(this, "sound_invio.wav");
  keyEffect  = new SoundFile(this, "key_sound.wav");
  
  // OSC setup
  oscTextSender = new OscP5(this, 12000); // porta locale (ricezione eventuale) 
  oscEmotionsReceiver = new OscP5(this, 9000); //porta di ascolto da python !!

  pythonLocation = new NetAddress("127.0.0.1", 12001); // python
}

// =============================================================
void draw() {

  if (sm.getCurrent() == Config.STATE_PARTICLES) {

    pushStyle();

    colorMode(RGB, 255);
    rectMode(CORNER);
    noStroke();

    fill(0, Config.PARTICLE_PERMANENCE);   // prova 35 invece di 18: scia più corta e meno caos
    rect(0, 0, width, height);

    popStyle();

  } else {

    background(Config.BG_COLOR);

  }

  sm.update();
  sm.render();

  if (Config.DEV_MODE) {
    dev.render();
  }
}

// =============================================================
//  INPUT
// =============================================================
void keyPressed() {
  if (Config.DEV_MODE) {
    dev.handleKey();          // gestisce frecce, 1/2/3, D
  }
  sm.handleKey();             // gestisce input specifici dello stato
}

void keyReleased() {
  sm.handleKeyReleased();
}
