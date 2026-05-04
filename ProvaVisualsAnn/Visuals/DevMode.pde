// =============================================================
//  DevMode.pde  |  Overlay debug + comandi sviluppatore
//  Attivo solo se Config.DEV_MODE = true
// =============================================================

class DevMode {

  // Pannello comandi (angolo in alto a sinistra)
  static final int PANEL_X     = 10;
  static final int PANEL_Y     = 10;
  static final int PANEL_W     = 340;
  static final int LINE_HEIGHT = 18;

  // ── Render overlay ───────────────────────────────────────
  void render() {
      if (!Config.DEV_MODE) return;
      if (!overlayVisible) return;
    
      String[] lines = buildLines();
      int panelH = lines.length * LINE_HEIGHT + 16;
    
      noStroke();
      fill(0, 0, 0, 180);
      rect(PANEL_X, PANEL_Y, PANEL_W, panelH, 4);
    
      textFont(fontSmall);
      textAlign(LEFT, TOP);
    
      for (int i = 0; i < lines.length; i++) {
        String line = lines[i];
        if (line.startsWith("§GRAY§")) {
          fill(120);
          line = line.substring(6);
        } else {
          fill(255);
        }
        text(line, PANEL_X + 8, PANEL_Y + 8 + i * LINE_HEIGHT);
      }
    
      drawStatusBar();
    }
    
   String[] buildLines() {
      String stateName = sm.stateLabel(sm.getCurrent());
      String audioInfo = audio.active ? nf(audio.getAmplitude(), 1, 3) : "N/A";
    
      ArrayList<String> lines = new ArrayList<String>();
    
      lines.add("── DEV MODE ──────────────────");
      lines.add("Stato corrente: " + stateName + " [" + sm.getCurrent() + "]");
      lines.add("Particelle: "     + ps.count());
      lines.add("Audio amp: "      + audioInfo);
      lines.add("FPS: "            + nf(frameRate, 1, 1));
      lines.add("─────────────────────────────");
      lines.add("← → : cambia stato");
      lines.add("1-5  : carica testo preset");
      lines.add("<    : toggle DEV overlay");
      lines.add("SPAZIO: skip disclaimer/thanks");
      lines.add("─────────────────────────────");
      lines.add("Testo attuale:");
      lines.add("  " + (inputHandler.length() > 0
                 ? inputHandler.getText().substring(0, min(30, inputHandler.length())) + "…"
                 : "(vuoto)"));
      lines.add("─────────────────────────────");
      lines.add("Emotions:");
    
      ArrayList<String> keys = new ArrayList<String>(emotions.keySet());
      Collections.sort(keys, new Comparator<String>() {
        public int compare(String a, String b) {
          return Float.compare(emotions.get(b), emotions.get(a));
        }
      });
    
      for (String key : keys) {
        float val = emotions.get(key);
        String prefix = (val == 0f) ? "§GRAY§" : "";
        lines.add(prefix + "  " + String.format("%-14s %5.2f", key, val));
      }
    
      return lines.toArray(new String[0]);
    }

  // ── Barra di stato in basso ───────────────────────────────
  void drawStatusBar() {
    int bx = 10;
    int by = height - 30;

    noStroke();
    fill(0, 0, 0, 160);
    rect(bx, by, 400, 22, 3);

    textFont(fontSmall);
    textAlign(LEFT, CENTER);
    fill(180, 180, 180);
    String label = sm.stateLabel(sm.getCurrent());
    text("● " + label + "  |  frame " + frameCount + "  |  " + nf(frameRate, 1, 0) + " fps",
         bx + 8, by + 11);
  }

  // ── Gestione tasti dev ────────────────────────────────────
  void handleKey() {
    if (!Config.DEV_MODE) return;

    // Frecce: cambia stato
    if (keyCode == RIGHT) {
      sm.nextState();
      return;
    }
    if (keyCode == LEFT) {
      sm.prevState();
      return;
    }

    // Tasti 1–5: carica preset
    if (key >= '1' && key <= '9') {
      int idx = key - '1';
      if (idx < Config.DEV_PROMPTS.length) {
        inputHandler.setText(Config.DEV_PROMPTS[idx]);
        println("[DevMode] Preset " + (idx + 1) + " caricato: " + Config.DEV_PROMPTS[idx]);

        // Se siamo in INPUT, il testo appare subito
        // Se siamo altrove, va in INPUT
        if (sm.getCurrent() != Config.STATE_INPUT) {
          sm.changeState(Config.STATE_INPUT);
        }
      }
      return;
    }

    // D: toggle overlay (disabilita il rendering del pannello)
    if (key == '<') {
      // Toglie solo il rendering ma lascia il DEV_MODE attivo
      // (usiamo una flag locale)
      overlayVisible = !overlayVisible;
      println("[DevMode] Overlay " + (overlayVisible ? "visibile" : "nascosto"));
      return;
    }
  }

  boolean overlayVisible = true;

  // Override render per rispettare la flag
  // (render() chiama questa invece di disegnare direttamente)
  // → già gestita: il render esterno controlla Config.DEV_MODE
  // Se vuoi nascondere solo il pannello ma lasciare la status bar,
  // puoi aggiungere qui la logica.
}
