// =============================================================
//  CATHARTIC VISUALS
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
  // fullScreen();
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
