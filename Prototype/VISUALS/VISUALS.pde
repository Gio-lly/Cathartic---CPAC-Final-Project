ArrayList<Particle> particles = new ArrayList<Particle>();
String typing = ""; 
String savedText = ""; 
PGraphics pg;
float textSizeValue = 120; // Grandezza fissa per entrambi

void setup() {
  size(1000, 500);
  pg = createGraphics(width, height);
  createTextParticles(savedText);
}

void draw() {
  background(0);

  // TESTO IN INPUT: centrato e stessa grandezza del buffer
  fill(255, 50); // Leggermente trasparente per non coprire le particelle
  textSize(textSizeValue);
  textAlign(CENTER, CENTER);
  text(typing, width/2, height/2);

  // AGGIORNAMENTO PARTICELLE
  for (int i = particles.size()-1; i >= 0; i--) {
    Particle p = particles.get(i);
    p.update();
    p.display();
  }
}

void keyPressed() {
  if (key == RETURN || key == ENTER) {
    if (typing.length() > 0) {
      savedText = typing;
      createTextParticles(savedText);
      typing = ""; // Svuota l'input dopo l'invio
    }
  } else if (key == BACKSPACE) {
    if (typing.length() > 0) {
      typing = typing.substring(0, typing.length() - 1);
    }
  } else if (keyCode != SHIFT && keyCode != CONTROL && keyCode != ALT) {
    particles.clear();
    typing += key;
  }
}

void createTextParticles(String t) {
  particles.clear(); 
  
  pg.beginDraw();
  pg.background(0);
  pg.fill(255);
  pg.textSize(textSizeValue);
  pg.textAlign(CENTER, CENTER);
  pg.text(t, width/2, height/2);
  pg.endDraw();

  pg.loadPixels();
  for (int x = 0; x < pg.width; x += 3) {
    for (int y = 0; y < pg.height; y += 3) {
      int index = x + y * pg.width;
      if (brightness(pg.pixels[index]) > 128) {
        particles.add(new Particle(x, y));
      }
    }
  }
}
