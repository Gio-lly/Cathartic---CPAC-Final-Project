class Particle {
  PVector pos, target, driftTarget, vel, acc;
  float maxSpeed = random(2, 5);
  float maxForce = random(0.1, 0.5);
  boolean isReturning = false;

  Particle(float x, float y) {
    // Nasce nella posizione del testo
    pos = new PVector(x, y);
    target = new PVector(x, y);
    
    // Crea un punto casuale molto lontano, fuori dai bordi
    float angle = random(TWO_PI);
    float dist = random(width, width * 1.5);
    driftTarget = new PVector(width/2 + cos(angle) * dist, height/2 + sin(angle) * dist);
    
    vel = PVector.random2D().mult(random(2, 5));
    acc = new PVector(0, 0);
  }

  void update() {
    // Sceglie quale target seguire
    PVector currentTarget = isReturning ? target : driftTarget;
    
    PVector steering = PVector.sub(currentTarget, pos);
    float d = steering.mag();
    
    float speed = maxSpeed;
    if (isReturning && d < 100) {
      speed = map(d, 0, 100, 0, maxSpeed);
    }
    
    steering.setMag(speed);
    PVector steer = PVector.sub(steering, vel);
    steer.limit(maxForce);
    
    acc.add(steer);
    vel.add(acc);
    pos.add(vel);
    acc.mult(0);
  }

  void display() {
    stroke(255, 180);
    strokeWeight(2);
    point(pos.x, pos.y);
  }
}
