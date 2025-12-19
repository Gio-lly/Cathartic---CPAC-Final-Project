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

  float releaseTimer= 40;


  Particle(float x, float y,color c) {
    pos = new PVector(x, y);
    target = new PVector(x, y);
    vel = PVector.random2D().mult(random(0.5, 1)); 
    acc = new PVector(0, 0);
    col = c; 
    home = new PVector(x, y);
    pState = ParticleState.TEXT;
  }

 void update() {
 
  col = color(currentR, currentG,currentB);
  //println(col);
   
  switch (pState) {

    case TEXT:
      pos.lerp(home, 0.2);
      vel.mult(0);
      break;

    case RELEASED:
      releaseTimer--;
      if(releaseTimer<=0){
        applyVortexForces();
        pState = ParticleState.VORTEX;
      }
      
      break;

    case VORTEX:
      applyVortexForces();
      //reemergeTimer--;
      //if (reemergeTimer <= 0) {
        //pState = ParticleState.REEMERGING;
      //}
      break;

    
  }
}

  void applyVortexForces() {
  float audioEnergy = constrain(audioLevel / 80.0, 0, 1);
  PVector toCenter = PVector.sub(vortexCenter, pos);
  float d = toCenter.mag() + 0.001;
  toCenter.normalize();

  PVector tangent = new PVector(-toCenter.y, toCenter.x);

  float n = noise(pos.x * 0.003, pos.y * 0.003, frameCount * 0.02);
  PVector noiseForce = PVector.fromAngle(n * TWO_PI).mult(1.2);

  

  acc.add(tangent.mult(1.5 + audioEnergy));
  acc.add(toCenter.mult(0.2*audioEnergy));
  acc.add(noiseForce);

  vel.add(acc);
  vel.limit(0.5 + audioEnergy * 3);
  pos.add(vel);
  vel.mult(0.985);
  acc.mult(0);
}



void display() {

  // alpha basso per evitare saturazione ADD
  float alpha = 80;

  stroke(col, alpha);

  float size = map(audioLevel, 0, 127, 4, 8);
  strokeWeight(size);

  point(pos.x, pos.y);
}
}
