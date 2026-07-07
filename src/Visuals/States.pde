// States.pde | Installation state implementations
// Implements the four states of the interactive installation, coordinating user input, visual transitions, audio-reactive
// particle behavior, and progression through the experience.

// STATE 0 — DISCLAIMER 
// Displays the introductory text and waits for user input before transitioning to the Input state.

class DisclaimerState extends BaseState {

  float alpha    = 0;
  float subAlpha = 0;

  static final int FADE_IN = 1500;

  void onEnter() {
    super.onEnter();

    inputHandler.clear();

    alpha    = 0;
    subAlpha = 0;

    println("[DisclaimerState] Entrato");
  }

  void onExit() {
    println("[DisclaimerState] Uscito");
  }

  void update() {
    int e = elapsed();

    if (e < FADE_IN) {
      alpha = map(e, 0, FADE_IN, 0, 255);
    } else {
      alpha = 255;
    }

    if (e >= FADE_IN) {
      int blinkIn  = Config.DISCLAIMER_SUB_BLINK_IN;
      int holdOn   = Config.DISCLAIMER_SUB_HOLD_ON;
      int blinkOut = Config.DISCLAIMER_SUB_BLINK_OUT;
      int holdOff  = Config.DISCLAIMER_SUB_HOLD_OFF;
      int cycle    = blinkIn + holdOn + blinkOut + holdOff;

      int blinkTime = (e - FADE_IN) % cycle;

      if (blinkTime < blinkIn) {
        subAlpha = map(blinkTime, 0, blinkIn, 0, 255);
      } else if (blinkTime < blinkIn + holdOn) {
        subAlpha = 255;
      } else if (blinkTime < blinkIn + holdOn + blinkOut) {
        subAlpha = map(blinkTime, blinkIn + holdOn, blinkIn + holdOn + blinkOut, 255, 0);
      } else {
        subAlpha = 0;
      }
    }
  }

  void render() {
    textFont(fontMain);
    textAlign(CENTER, CENTER);
    fill(Config.DISCLAIMER_TEXT_COLOR, alpha);
    text(Config.DISCLAIMER_TEXT, width / 2.0, height / 2.0);

    textFont(fontSmall);
    fill(
      red(Config.DISCLAIMER_SUB_COLOR),
      green(Config.DISCLAIMER_SUB_COLOR),
      blue(Config.DISCLAIMER_SUB_COLOR),
      subAlpha
      );
    text(Config.DISCLAIMER_TEXT2, width / 2.0, height / 2.0 + Config.DISCLAIMER_SUB_OFFSET_Y);
  }

  void handleKey() {
    if (key != '<' && key != '0' && keyCode != RIGHT && keyCode != LEFT) {

      sm.changeState(Config.STATE_INPUT);

      if (key >= 32 && key < 127) {
        inputHandler.append((char) key);
        keyEffect.play();
      }
    }
  }
}

// STATE 1 — INPUT 
// Collects the user's prompt. Pressing Enter sends the text to Python and uses it to initialise the particle system.
  
  class InputState extends BaseState {

    void onEnter() {
      super.onEnter();
      println("[InputState] Entrato — l'utente può scrivere");
    }

    void onExit() {
      println("[InputState] Uscito — testo: " + inputHandler.getText() );
    }

    void update() {
    }

    void render() {
      String display = inputHandler.getText().length() == 0
        ? Config.INPUT_PLACEHOLDER
        : inputHandler.getText();

      boolean isPlaceholder = inputHandler.getText().length() == 0;

      float maxW = width * Config.PROMPT_BOX_W_FRAC;  
      float maxH = height * Config.PROMPT_BOX_H_FRAC;
      int bufferPromptLenght = display.length();
      textFont(fontMain);
      textAlign(CENTER, CENTER);
      fill(255, isPlaceholder ? 80 : 255);
      rectMode(CENTER);
      text(display, width / 2.0, height / 2.0, maxW, maxH);

      if (bufferPromptLenght > Config.maxCharPrompt/5) {

        textFont(fontSmall);
        textAlign(CENTER, CENTER);
        fill(255, 80);
        rectMode(CENTER);
        text("Remaining characters: " + str(Config.maxCharPrompt - bufferPromptLenght),
          width / 2.0, height / 2.0 + height * Config.REMAINING_CHARS_OFFSET_FRAC, 200*2, 200);
      }
    }

    void handleKey() {
      if (key == ENTER || key == RETURN) {
        if (inputHandler.getText().length() > 0) {

          String savedText = inputHandler.getText();

          // Send prompt to python via osc
          sendTextToPython(savedText);

          // Costruisci le particelle dal testo corrente
          ps.buildFromText(savedText);
          sm.changeState(Config.STATE_PARTICLES);

          // Sound effect (Enter)
          sentEffect.play();
        }
      } else if (key == BACKSPACE) {
        inputHandler.backspace();
      } else if (key == DELETE) {
        inputHandler.clear();
      } else if (key >= 32 && key < 127 && key != '<' && key != '0') {  
        inputHandler.append((char) key);
        keyEffect.play();
      } else if (key != CODED && key >= 32 && key != BACKSPACE && key != DELETE && key != ENTER && key != RETURN && key != '<' && key != '0') {
        inputHandler.append((char) key);
        keyEffect.play();
      }
    }
  }


// STATE 2 — PARTICLES 
// Runs the audio-reactive particle simulation. The state ends automatically after a timeout or early after a key press.
  class ParticlesState extends BaseState {
    boolean fadingOut    = false;
    int     fadeStartTime;

    void onEnter() {
      super.onEnter();
      fadingOut = false;

      if (Config.USE_FILE_AUDIO) {
        audio.startFile();
      } else {
        audio.startMic();
      }

      println("[ParticlesState] Entrato — modalità: " + (Config.USE_FILE_AUDIO ? "file audio" : "microfono"));
      println("[ParticlesState] Particelle attive: " + ps.count());
    }

    void onExit() {
      audio.stop();
      ps.clear();
      println("[ParticlesState] Uscito");
    }

    void update() {
      if (!fadingOut && elapsed() >= Config.PARTICLES_DURATION) {
        startFadeOut();
      }

      ps.update(audio.getAmplitude(), audio.getFFT());

      if (fadingOut) {
        int   fadeElapsed  = millis() - fadeStartTime;
        float fadeProgress = (float) fadeElapsed / Config.PARTICLES_FADEOUT_TIME;
        ps.setGlobalAlpha(1.0 - fadeProgress);
        if (fadeProgress >= 1.0) {
          sm.changeState(Config.STATE_THANKS);
        }
      }
    }

    void render() {
      ps.render();
    }

    void handleKey() {
      if (Config.USE_FILE_AUDIO && key == ' ') {
        audio.togglePause();
        return;
      }
  
      if (!fadingOut && key != '<' && key != '0') startFadeOut();
    }

    void startFadeOut() {
      fadingOut     = true;
      fadeStartTime = millis();
      println("[ParticlesState] Fade-out avviato");
    }
  }


// STATE 3 — THANKS 
// Displays the closing message with a fade-in, hold and fade-out sequence, then restarts the installation.

  class ThanksState extends BaseState {

    float alpha;

    void onEnter() {
      super.onEnter();
      alpha = 0;
      println("[ThanksState] Entrato");
    }

    void onExit() {
      println("[ThanksState] Uscito — ritorno al DISCLAIMER");
    }

    void update() {
      int e       = elapsed();
      int fadeIn  = Config.THANKS_FADE_IN;
      int hold    = Config.THANKS_HOLD;
      int fadeOut = Config.THANKS_FADE_OUT;
      int total   = fadeIn + hold + fadeOut;

      if (e < fadeIn) {
        alpha = map(e, 0, fadeIn, 0, 255);
      } else if (e < fadeIn + hold) {
        alpha = 255;
      } else if (e < total) {
        alpha = map(e, fadeIn + hold, total, 255, 0);
      } else {
        sm.changeState(Config.STATE_DISCLAIMER);
      }
    }

    void render() {
      textFont(fontMain);
      textAlign(CENTER, CENTER);
      fill(255, alpha);
      text(Config.THANKS_TEXT, width / 2.0, height / 2.0);
    }
  }
