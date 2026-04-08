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

import ddf.minim.*;
import ddf.minim.analysis.*;


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
Minim minim;
AudioSample sentEffect;
AudioSample keyEffect;

// =============================================================
void setup() {
  size(1280, 720);           // Cambia con fullScreen() per l'installazione
  //fullScreen();
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
  minim = new Minim(this);
  sentEffect = minim.loadSample("sound_invio.wav", 512);
  keyEffect  = minim.loadSample("key_sound.wav", 512);
}

// =============================================================
void draw() {
  background(Config.BG_COLOR);
  
  // Aggiorna e disegna lo stato corrente
  sm.update();
  sm.render();
  
  // Overlay dev mode sopra tutto
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
