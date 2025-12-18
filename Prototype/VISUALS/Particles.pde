enum ParticleState {
  TEXT,       // ferma nel testo
  RELEASED,   // si stacca
  VORTEX,     // vaga libera
  REEMERGING  // torna a formare testo
}
class Particle {
  PVector pos, target, vel, acc;
  float maxSpeed = random(0.5, 1.3); 
  float maxForce = random(0.05, 0.15);
  boolean isReturning = true; 

  color col;
  float dissolveCounter = 0;
  float dissolveRate = random(0.02, 0.05); 
  
  PVector home;          // posizione del testo
  ParticleState pState;

  float reemergeTimer = random(300, 1200);


  Particle(float x, float y) {
    pos = new PVector(x, y);
    target = new PVector(x, y);
    vel = PVector.random2D().mult(random(0.5, 1)); 
    acc = new PVector(0, 0);
    col = textColor; 
    home = new PVector(x, y);
    pState = ParticleState.TEXT;
  }

 void update() {

  switch (pState) {

    case TEXT:
      pos.lerp(home, 0.2);
      vel.mult(0);
      break;

    case RELEASED:
      applyVortexForces();
      pState = ParticleState.VORTEX;
      break;

    case VORTEX:
      applyVortexForces();
      //reemergeTimer--;
      //if (reemergeTimer <= 0) {
        //pState = ParticleState.REEMERGING;
      //}
      break;

    case REEMERGING:
      PVector arrive = PVector.sub(home, pos);
      arrive.setMag(0.8);
      vel.lerp(arrive, 0.08);
      pos.add(vel);

      if (pos.dist(home) < 2) {
        pState = ParticleState.TEXT;
        reemergeTimer = random(600, 1600);
      }
      break;
  }
}

  void applyVortexForces() {

  PVector toCenter = PVector.sub(vortexCenter, pos);
  float d = toCenter.mag() + 0.001;
  toCenter.normalize();

  PVector tangent = new PVector(-toCenter.y, toCenter.x);

  float n = noise(pos.x * 0.003, pos.y * 0.003, frameCount * 0.003);
  PVector noiseForce = PVector.fromAngle(n * TWO_PI).mult(0.9);

  float audioEnergy = constrain(audioLevel / 80.0, 0, 1);

  acc.add(tangent.mult(1.1 + audioEnergy));
  acc.add(toCenter.mult(0.2));
  acc.add(noiseForce);

  vel.add(acc);
  vel.limit(2.5 + audioEnergy * 2);
  pos.add(vel);
  vel.mult(0.985);
  acc.mult(0);
}



void display() {

  // alpha basso per evitare saturazione ADD
  float alpha = 25;

  stroke(col, alpha);

  float size = map(audioLevel, 0, 127, 4, 8);
  strokeWeight(size);

  point(pos.x, pos.y);
}
}
