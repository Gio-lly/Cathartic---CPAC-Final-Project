
class Particle {
  PVector pos, target, vel, acc;
  float maxSpeed = 5;
  float maxForce = 0.3;

Particle(float x, float y) {
  pos = new PVector(mouseX, mouseY); 
  target = new PVector(x, y);
  vel = PVector.random2D();
  acc = new PVector(0, 0);
}

  void update() {
    PVector arrive = PVector.sub(target, pos);
    float d = arrive.mag();
    float speed = maxSpeed;
    if (d < 100) speed = map(d, 0, 100, 0, maxSpeed);
    arrive.setMag(speed);
    
    PVector steer = PVector.sub(arrive, vel);
    steer.limit(maxForce);
    
    acc.add(steer);
    vel.add(acc);
    pos.add(vel);
    acc.mult(0);
  }

  void display() {
    stroke(255);
    strokeWeight(2);
    point(pos.x, pos.y);
  }
}
