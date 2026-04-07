// =============================================================
//  ParticleSystem.pde  |  Pool di particelle + force field
// =============================================================

class ParticleSystem {

  // ── Particles ──────────────────────────────────────────────
  ChladniParticle[] particles;
  int               N;

  // ── Physics ────────────────────────────────────────────────
  float forceGain;
  float forceKickValue = 0;

  // ── Edge ───────────────────────────────────────────────────
  float edgeWeight = 5.0;
  float edgeMargin = 0.1;
  float edgeTarget = 5.0;

  // ── Kick envelope state ────────────────────────────────────
  float env      = 0;
  float baseMean = 0;
  float baseVar  = 1e-6;
  float baseAlpha;
  int   lastKickMs = -999999;
  int   frameFromLastKick = 0;

  // ── Continuous visual state ────────────────────────────────
  float particleW;
  float luminosita;
  float kEnv = 0;

  // ── Alpha (for fade-out) ───────────────────────────────────
  float globalAlpha = 1.0;

  // ── Mode ───────────────────────────────────────────────────
  ModeSet randomSet;

  // ── Constructor ────────────────────────────────────────────
  ParticleSystem() {
    N           = Config.PARTICLE_COUNT;
    particles   = new ChladniParticle[N];
    forceGain   = Config.FORCE_GAIN_BASE;
    baseAlpha   = Config.BASE_ALPHA;
    particleW   = Config.BASE_STROKE_W;
    luminosita  = Config.BASE_LUM;
    randomSet   = new ModeSet();

    for (int i = 0; i < N; i++) particles[i] = new ChladniParticle();

    resetParticles();
    pickRandomModeSet();
    println("[ParticleSystem] Chladni init — " + N + " particelle");
  }

  // ── Public API ─────────────────────────────────────────────

  void buildFromText(String txt) {
    float maxW = width  * 0.5;
    float maxH = height * 0.5;

    PGraphics pg = createGraphics(width, height);
    pg.beginDraw();
    pg.background(0);
    pg.fill(255);
    pg.textFont(fontMain);
    pg.textAlign(CENTER, CENTER);
    pg.rectMode(CENTER);
    pg.text(txt, width / 2.0, height / 2.0, maxW, maxH);
    pg.endDraw();
    pg.loadPixels();

    // Raccoglie posizioni candidate
    ArrayList<PVector> candidates = new ArrayList<PVector>();
    int step = Config.DEV_MODE ? 4 : 2;
    for (int y = 0; y < pg.pixelHeight; y += step) {
      for (int x = 0; x < pg.pixelWidth; x += step) {
        int idx = y * pg.pixelWidth + x;
        if (brightness(pg.pixels[idx]) > 128) {
          float px = map(x, 0, pg.pixelWidth,  0, width);
          float py = map(y, 0, pg.pixelHeight, 0, height);
          candidates.add(new PVector(px, py));
        }
      }
    }

    // Posiziona le particelle sui pixel del testo (con wrap se N > candidati)
    int total = candidates.size();
    if (total == 0) { println("[ParticleSystem] buildFromText: nessun pixel trovato"); return; }

    for (int i = 0; i < N; i++) {
      PVector src = candidates.get(i % total);
      particles[i].pos.set(
        src.x + random(-step / 2.0, step / 2.0),
        src.y + random(-step / 2.0, step / 2.0)
      );
      particles[i].vel.set(random(-0.5, 0.5), random(-0.5, 0.5));
    }

    globalAlpha = 1.0;
    println("[ParticleSystem] buildFromText — candidati: " + total + ", particelle: " + N);
  }

  // Chiamato ogni frame da ParticlesState
  void update(float amplitude, float[] fftBands) {
    _processAudio(amplitude, fftBands);
    _stepParticles();
  }

  void render() {
    pushMatrix();
    colorMode(HSB, 360, 100, 100);
    stroke(
      Config.PARTICLE_HUE,
      Config.PARTICLE_SAT,
      luminosita * globalAlpha
    );
    strokeWeight(particleW);
    beginShape(POINTS);
    for (int i = 0; i < N; i++) {
      vertex(particles[i].pos.x, particles[i].pos.y);
    }
    endShape();
    colorMode(RGB, 255);
    popMatrix();
  }

  void clear()                      { resetParticles(); }
  int  count()                      { return N; }
  void setGlobalAlpha(float a)      { globalAlpha = constrain(a, 0, 1); }

  // ── Audio processing ───────────────────────────────────────

  void _processAudio(float amplitude, float[] fftBands) {
    // Kick envelope dal livello RMS (usiamo amplitude come proxy)
    float e = amplitude;
    if (e > env) env = lerp(env, e, Config.ENV_ATK);
    else         env = lerp(env, e, Config.ENV_REL);

    float diff = env - baseMean;
    baseMean += baseAlpha * diff;
    baseVar  += baseAlpha * (diff * diff - baseVar);
    float sigma = sqrt(max(1e-9, baseVar));
    float z = (env - baseMean) / sigma;

    kEnv = constrain((z - Config.Z_FOLLOW_FLOOR) / max(1e-6, Config.Z_FOLLOW_RANGE), 0, 1);
    kEnv = _smooth01(kEnv);

    // Kick discreto → cambio mode
    boolean canFire = (millis() - lastKickMs) > Config.REFRACTORY_MS;
    if (canFire && z > Config.Z_THRESH) {
      lastKickMs = millis();
      pickRandomModeSet();
      if (Config.RESET_ON_MODE_CHANGE) resetParticles();

      if (Config.FORCE_KICK_BOOST > 0) {
        float add      = Config.FORCE_KICK_BOOST * kEnv;
        float maxExtra = Config.FORCE_GAIN_BASE * (Config.FORCE_KICK_MAX_MULT - 1.0);
        forceKickValue = min(maxExtra, forceKickValue + add);
      }
    }

    // Gestione no-kick (detector adattivo)
    frameFromLastKick++;
    float secFromKick = frameFromLastKick / frameRate;
    if (secFromKick > 3.0) baseAlpha = lerp(baseAlpha, 0.03, 0.02);
    else                   baseAlpha = lerp(baseAlpha, 0.01, 0.02);

    // Visuals continui guidati da kEnv
    particleW  = lerp(particleW,  lerp(Config.BASE_STROKE_W, Config.KICK_STROKE_W, kEnv), Config.W_FOLLOW);
    luminosita = lerp(luminosita, lerp(Config.BASE_LUM,      Config.KICK_LUM,      kEnv), Config.L_FOLLOW);

    // Force composition
    forceKickValue = lerp(forceKickValue, 0, Config.FORCE_DECAY);
    forceGain      = Config.FORCE_GAIN_BASE + forceKickValue;

    // Edge ← ampiezza
    float t = constrain((amplitude - Config.VOL_MIN) / max(1e-6, Config.VOL_MAX - Config.VOL_MIN), 0, 1);
    edgeTarget = lerp(Config.EDGE_WEIGHT_MAX, Config.EDGE_WEIGHT_MIN, t);
    edgeWeight = lerp(edgeWeight, edgeTarget, Config.EDGE_SMOOTH);
    edgeMargin = constrain(
      (edgeWeight / Config.EDGE_WEIGHT_MAX) * (edgeWeight / Config.EDGE_WEIGHT_MAX - random(0.001, 0.01)),
      Config.EDGE_MARGIN_MIN, Config.EDGE_MARGIN_MAX
    );
  }

  // ── Particle step ──────────────────────────────────────────

  void _stepParticles() {
    for (int i = 0; i < N; i++) {
      ChladniParticle p = particles[i];

      PVector g = _gradV(p.pos.x, p.pos.y);
      p.vel.x += -g.x * forceGain;
      p.vel.y += -g.y * forceGain;
      p.vel.x += random(-Config.JITTER, Config.JITTER);
      p.vel.y += random(-Config.JITTER, Config.JITTER);
      p.vel.mult(1.0 - Config.DAMPING);
      p.pos.add(p.vel);

      // Respawn fuori canvas
      if (p.pos.x < 0 || p.pos.x > width-1 || p.pos.y < 0 || p.pos.y > height-1) {
        float ang = random(TWO_PI);
        float rad = sqrt(random(1)) * min(width, height) * 0.15;
        p.pos.set(width/2 + cos(ang)*rad, height/2 + sin(ang)*rad);
        p.vel.set(random(-0.5,0.5), random(-0.5,0.5));
      }
    }
  }

  // ── Chladni field ──────────────────────────────────────────

  float _A(float x, float y) {
    float a = 0;
    if (!randomSet.isCircular) {
      a += randomSet.w1 * _modeRect(x, y, randomSet.m1, randomSet.n1);
      a += randomSet.w2 * _modeRect(x, y, randomSet.m2, randomSet.n2);
      a += randomSet.w3 * _modeRect(x, y, randomSet.m3, randomSet.n3);
    } else {
      a += randomSet.w1 * _modeCirc(x, y, randomSet.m1, randomSet.n1);
      a += randomSet.w2 * _modeCirc(x, y, randomSet.m2, randomSet.n2);
      a += randomSet.w3 * _modeCirc(x, y, randomSet.m3, randomSet.n3);
    }
    return _tanh(a * 1.2);
  }

  float _modeRect(float x, float y, int m, int n) {
    return sin(m * PI * x) * sin(n * PI * y);
  }

  float _modeCirc(float x, float y, int m, int n) {
    float cx = x - 0.5, cy = y - 0.5;
    float r  = min(sqrt(cx*cx + cy*cy) / 0.5, 1.0);
    return sin(n * PI * r) * cos(m * atan2(cy, cx));
  }

  float _V(float x, float y) {
    float v = _A(x, y);
    v = v * v;
    float cx = x - 0.5, cy = y - 0.5;
    float r  = min(sqrt(cx*cx + cy*cy) / 0.5, 1.0);
    if (r > 1.0 - edgeMargin) {
      float t = (r - (1.0 - edgeMargin)) / max(1e-6, edgeMargin);
      v += edgeWeight * pow(t, Config.EDGE_POWER);
    }
    return v;
  }

  PVector _gradV(float px, float py) {
    float x  = px / width;
    float y  = py / height;
    float ex = Config.EPS / width;
    float ey = Config.EPS / height;

    float dVdx = (_V(_c01(x+ex), y) - _V(_c01(x-ex), y)) / (2.0*ex) / width;
    float dVdy = (_V(x, _c01(y+ey)) - _V(x, _c01(y-ey))) / (2.0*ey) / height;

    return new PVector(dVdx, dVdy);
  }

  // ── Mode picking ───────────────────────────────────────────

  void pickRandomModeSet() {
    randomSet.isCircular = (random(1) < Config.CIRCULAR_PROBABILITY);
    if (!randomSet.isCircular) {
      randomSet.m1 = _ri(2,4);  randomSet.n1 = _ri(2,4);
      randomSet.m2 = _ri(2,8);  randomSet.n2 = _ri(2,8);
      randomSet.m3 = _ri(2,10); randomSet.n3 = _ri(2,10);
    } else {
      randomSet.m1 = _ri(0,8);  randomSet.n1 = _ri(1,8);
      randomSet.m2 = _ri(0,10); randomSet.n2 = _ri(1,10);
      randomSet.m3 = _ri(0,12); randomSet.n3 = _ri(1,12);
    }
    randomSet.w1 = 1.0;
    randomSet.w2 = random(0.35, 0.95);
    randomSet.w3 = random(0.20, 0.70);
  }

  // ── Helpers ────────────────────────────────────────────────

  void resetParticles() {
    for (int i = 0; i < N; i++) {
      particles[i].pos.set(random(width), random(height));
      particles[i].vel.set(random(-0.5,0.5), random(-0.5,0.5));
    }
  }

  float _tanh(float x) { float e = exp(2*x); return (e-1)/(e+1); }
  float _smooth01(float t) { t=constrain(t,0,1); return t*t*(3-2*t); }
  float _c01(float t) { return max(0, min(1, t)); }
  int   _ri(int lo, int hi) { return (int) random(lo, hi+1); }
}

// ── Particle e ModeSet (classi di supporto) ──────────────────

class ChladniParticle {
  PVector pos = new PVector();
  PVector vel = new PVector();
}

class ModeSet {
  boolean isCircular;
  int m1, n1, m2, n2, m3, n3;
  float w1, w2, w3;
}
