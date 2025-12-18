class VisualQuestion {
  String text;
  float x, y;
  float alpha; // trasparenza corrente
  float targetAlpha; // alpha massima (fade-in)
  float fadeSpeed; // velocità di dissolvenza
  boolean fadingOut; // stato fade

  VisualQuestion(String t) {
    text = t;
    x = random(50, width - 50);
    y = random(50, height - 50);
    alpha = 0; // parte invisibile
    targetAlpha = 180; // massimo livello di visibilità
    fadeSpeed = 2; // velocità dissolvenza
    fadingOut = false; // inizialmente fade-in
  }

  void update() {
    if (!fadingOut) {
      alpha += fadeSpeed; // fade-in
      if (alpha > targetAlpha) alpha = targetAlpha;
    } else {
      alpha -= fadeSpeed; // fade-out
    }
  }

  void display() {
    fill(80, alpha);
    textSize(24);
    textAlign(CENTER, CENTER);
    text(text, x, y);
  }

  void startFadeOut() {
    fadingOut = true;
  }

  boolean isDead() {
    return fadingOut && alpha <= 0;
  }
}


void resetInterface() {
  typing = "";
  savedText = "";
  particles.clear();
  lastTypingTime = millis(); // resetta anche il timer di inattività
  // fai iniziare fade-out alle domande esistenti
  for (VisualQuestion q : activeQuestions) {
    q.startFadeOut();
  }
}


void drawRestartSymbol() {
  pulsePhase += 0.03;
  restartAlpha = 120 + sin(pulsePhase) * 40;

  pushStyle();
  noFill();
  stroke(80, restartAlpha);
  strokeWeight(1.5);
  float r = 60 + sin(pulsePhase) * 5;
  ellipse(width/2, height/2, r*2, r*2);

  fill(80, restartAlpha);
  textAlign(CENTER, CENTER);
  textSize(14);
  text("press any key to restart", width/2, height/2 + 90);
  popStyle();
}
