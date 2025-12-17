

class Particle {
  PVector pos, target, vel, acc;
  float maxSpeed = random(0.5, 1.3); 
  float maxForce = random(0.05, 0.15);
  boolean isReturning = true; 

  color col;
  float dissolveCounter = 0;
  float dissolveRate = random(0.002, 0.005); 

  Particle(float x, float y) {
    pos = new PVector(x, y);
    target = new PVector(x, y);
    vel = PVector.random2D().mult(random(0.5, 1)); 
    acc = new PVector(0, 0);
    col = textColor; 
  }

  void update() {
    if (isReturning) {
      PVector arrive = PVector.sub(target, pos);
      float d = arrive.mag();
      float speed = maxSpeed;
      if (d < 100) speed = map(d, 0, 100, 0, maxSpeed);
      arrive.setMag(speed);
      PVector steer = PVector.sub(arrive, vel);
      steer.limit(maxForce);
      acc.add(steer);
      
    } else {
      // COMPORTAMENTO FLUIDO
      PVector toCenter = PVector.sub(vortexCenter, pos);
      toCenter.normalize();
      PVector tangent = new PVector(-toCenter.y, toCenter.x);
      
      float noiseAngle = noise(pos.x * 0.005, pos.y * 0.005, frameCount * 0.002) * TWO_PI * 4;
      PVector turbulence = PVector.fromAngle(noiseAngle);
      turbulence.mult(0.93); 

      PVector fluidForce = tangent.copy().mult(0.92);
      fluidForce.add(turbulence);
      fluidForce.add(toCenter.mult(0.15)); 
      
      fluidForce.setMag(maxSpeed);
      PVector steer = PVector.sub(fluidForce, vel);
      steer.limit(maxForce); 
      acc.add(steer);

      dissolveCounter += dissolveRate;
      col = lerpColor(textColor, liquidColor, constrain(dissolveCounter*10, 0, 1));
    }

    vel.add(acc);
    vel.limit(maxSpeed * 1.5); 
    pos.add(vel);
    acc.mult(0);
    vel.mult(0.97); 
  }

  void paintBackground(PGraphics layer) {
    if (!isReturning) {
      float r = red(liquidColor) + random(-50, 50);
      float g = green(liquidColor) + random(-50, 50);
      float b = blue(liquidColor) + random(-50, 50);
      
      // Qui definiamo l'effetto "Tempera"
      // Alpha più alto (50) per coprire di più. 
      // Se vuoi un effetto più "solido", aumenta 50 a 100 o 255.
      layer.stroke(r, g, b, 255); 
      layer.strokeWeight(random(2, 12)); // Pennellata variabile
      layer.point(pos.x, pos.y);
    }
  }

  void display() {
    // La particella scompare visivamente (alpha va a 0) mentre diventa background
    float alpha = map(dissolveCounter, 0, 1, 170, 0);
    stroke(col, alpha);
    // Dimensione che cambia
    float size = map(dissolveCounter, 0, 1, 4,2 );
    strokeWeight(size);
    point(pos.x, pos.y);
  }
}
