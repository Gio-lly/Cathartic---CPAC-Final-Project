// =============================================================
//  ParticleSystem.pde  |  Pool di particelle + force field
// =============================================================

class ParticleSystem {

  float positiveEnergy = 0;
  float negativeEnergy = 0;
  float emotionalEnergy = 0;

  float emotionHue = 0;
  float emotionSat = 0;
  float emotionBri = 100;

  float targetHue = 0;
  float targetSat = 0;
  float targetBri = 60;

  float modalComplexity = 0;

  // ── Particles ──────────────────────────────────────────────
  ChladniParticle[] particles;
  int N;

  // ── Physics ────────────────────────────────────────────────
  float forceGain;
  float forceKickValue = 0;

  float dynamicDamping;
  float dynamicJitter;
  float dynamicForceGain;

  // ── FFT bands ──────────────────────────────────────────────
  float lowEnergy = 0;
  float midEnergy = 0;
  float highEnergy = 0;

  // ── Swirl / rotation ───────────────────────────────────────
  float swirlDirection = 1.0;

  // ── Edge ───────────────────────────────────────────────────
  float edgeWeight = 5.0;
  float edgeMargin = 0.1;
  float edgeTarget = 5.0;

  // ── Kick envelope state ────────────────────────────────────
  float env = 0;
  float baseMean = 0;
  float baseVar = 1e-6;
  float baseAlpha;
  int lastKickMs = -999999;
  int frameFromLastKick = 0;

  // ── Continuous visual state ────────────────────────────────
  float particleW;
  float luminosita;
  float kEnv = 0;

  // ── Alpha (for fade-out) ───────────────────────────────────
  float globalAlpha = 1.0;

  // ── Mode ───────────────────────────────────────────────────
  ModeSet randomSet;

  ParticleSystem() {
    N = Config.PARTICLE_COUNT;
    particles = new ChladniParticle[N];

    forceGain = Config.FORCE_GAIN_BASE;
    baseAlpha = Config.BASE_ALPHA;
    particleW = Config.BASE_STROKE_W;
    luminosita = Config.BASE_LUM;
    randomSet = new ModeSet();

    dynamicForceGain = Config.FORCE_GAIN_BASE;
    dynamicDamping = Config.DAMPING;
    dynamicJitter = Config.JITTER;

    for (int i = 0; i < N; i++) particles[i] = new ChladniParticle();

    resetParticles();
    pickRandomModeSet();

    println("[ParticleSystem] Chladni init — " + N + " particelle");
  }

  float emo(String name) {
    if (emotions.containsKey(name)) return emotions.get(name);
    return 0;
  }

  boolean isPositiveEmotion(String e) {
    return e.equals("joy") || e.equals("love") || e.equals("admiration") ||
           e.equals("amusement") || e.equals("approval") || e.equals("caring") ||
           e.equals("excitement") || e.equals("gratitude") || e.equals("optimism") ||
           e.equals("relief") || e.equals("pride");
  }

  boolean isNegativeEmotion(String e) {
    return e.equals("anger") || e.equals("annoyance") || e.equals("disgust") ||
           e.equals("fear") || e.equals("grief") || e.equals("sadness") ||
           e.equals("remorse") || e.equals("embarrassment") ||
           e.equals("disappointment") || e.equals("disapproval") ||
           e.equals("nervousness");
  }

  float hueForEmotion(String e) {
    if (e.equals("anger")) return 0;
    if (e.equals("annoyance")) return 15;
    if (e.equals("disgust")) return 100;
    if (e.equals("fear")) return 275;
    if (e.equals("grief")) return 245;
    if (e.equals("sadness")) return 230;
    if (e.equals("remorse")) return 260;
    if (e.equals("embarrassment")) return 340;
    if (e.equals("disappointment")) return 215;
    if (e.equals("disapproval")) return 210;
    if (e.equals("nervousness")) return 290;

    if (e.equals("joy")) return 52;
    if (e.equals("love")) return 335;
    if (e.equals("admiration")) return 200;
    if (e.equals("amusement")) return 45;
    if (e.equals("approval")) return 95;
    if (e.equals("caring")) return 330;
    if (e.equals("excitement")) return 32;
    if (e.equals("gratitude")) return 75;
    if (e.equals("optimism")) return 55;
    if (e.equals("relief")) return 190;
    if (e.equals("pride")) return 280;

    if (e.equals("confusion")) return 270;
    if (e.equals("curiosity")) return 185;
    if (e.equals("surprise")) return 300;
    if (e.equals("realization")) return 50;

    return emotionHue;
  }

  String pickEmotionWeighted() {
    float total = 0;

    for (String key : emotions.keySet()) {
      if (key.equals("neutral")) continue;

      float val = emotions.get(key);
      if (val > 0.03) total += val;
    }

    if (total <= 0.001) return "";

    float r = random(total);
    float acc = 0;

    for (String key : emotions.keySet()) {
      if (key.equals("neutral")) continue;

      float val = emotions.get(key);
      if (val <= 0.03) continue;

      acc += val;
      if (r <= acc) return key;
    }

    return "";
  }

  // =============================================================
  //  COLOR GRADIENT
  // =============================================================

  void updateParticleColors() {
    if (emotionalEnergy <= 0.05) return;

    for (int i = 0; i < N; i++) {
      ChladniParticle p = particles[i];

      float targetHue = hueFromSpatialGradient(p.pos);

      // Transizione morbida verso il colore del campo spaziale
      p.hue = lerpHue(p.hue, targetHue, 0.12);
    }
  }

  float hueFromSpatialGradient(PVector pos) {
    ArrayList<Float> hues = new ArrayList<Float>();

    for (String key : emotions.keySet()) {
      if (key.equals("neutral")) continue;

      float val = emotions.get(key);

      if (val > 0.03) {
        hues.add(hueForEmotion(key));
      }
    }

    if (hues.size() == 0) return emotionHue;
    if (hues.size() == 1) return hues.get(0);

    // Più basso = gradienti più larghi e morbidi
    // Più alto = gradienti più fitti e dettagliati
    float scale = 0.002;

    float t = noise(pos.x * scale, pos.y * scale);

    float palettePos = t * (hues.size() - 1);

    int idxA = floor(palettePos);
    int idxB = min(idxA + 1, hues.size() - 1);

    float localT = palettePos - idxA;

    return lerpHue(hues.get(idxA), hues.get(idxB), localT);
  }

  float lerpHue(float a, float b, float t) {
    float d = b - a;

    if (abs(d) > 180) {
      if (d > 0) a += 360;
      else b += 360;
    }

    return (lerp(a, b, t) + 360) % 360;
  }

  float saturationForParticle(ChladniParticle p) {
    if (emotionalEnergy <= 0.05) {
      return lerp(0, emotionSat, 0.0);
    }

    if (isPositiveEmotion(p.emotion)) {
      return lerp(20, 90, positiveEnergy);
    }

    if (isNegativeEmotion(p.emotion)) {
      return lerp(20, 90, negativeEnergy);
    }

    return lerp(10, 60, emotionalEnergy);
  }

  void _processEmotions() {
    float joy = emo("joy");
    float love = emo("love");
    float admiration = emo("admiration");
    float amusement = emo("amusement");
    float approval = emo("approval");
    float caring = emo("caring");
    float excitement = emo("excitement");
    float gratitude = emo("gratitude");
    float optimism = emo("optimism");
    float relief = emo("relief");
    float pride = emo("pride");

    float anger = emo("anger");
    float annoyance = emo("annoyance");
    float disgust = emo("disgust");
    float fear = emo("fear");
    float grief = emo("grief");
    float sadness = emo("sadness");
    float remorse = emo("remorse");
    float embarrassment = emo("embarrassment");
    float disappointment = emo("disappointment");
    float disapproval = emo("disapproval");
    float nervousness = emo("nervousness");

    positiveEnergy = constrain(
      joy + love + admiration + amusement + approval + caring +
      excitement + gratitude + optimism + relief + pride,
      0, 1
    );

    negativeEnergy = constrain(
      anger + annoyance + disgust + fear + grief + sadness + remorse +
      embarrassment + disappointment + disapproval + nervousness,
      0, 1
    );

    emotionalEnergy = constrain(positiveEnergy + negativeEnergy, 0, 1);

    if (emotionalEnergy > 0.05) {
      targetSat = lerp(20, 90, emotionalEnergy);
      targetBri = lerp(55, 100, emotionalEnergy);

      emotionSat = lerp(emotionSat, targetSat, 0.08);
      emotionBri = lerp(emotionBri, targetBri, 0.08);
    } else {
      emotionSat = lerp(emotionSat, 0, 0.05);
      emotionBri = lerp(emotionBri, 60, 0.05);
    }
  }

  void _processEmotionPhysics() {
    float tension = negativeEnergy;
    float openness = positiveEnergy;

    float targetForceGain = Config.FORCE_GAIN_BASE * lerp(1.1, 1.5, tension);
    float targetDamping = lerp(0.05, 0.13, openness);
    float targetJitter = lerp(0.12, 0.75, emotionalEnergy);

    dynamicForceGain = lerp(dynamicForceGain, targetForceGain, 0.06);
    dynamicDamping   = lerp(dynamicDamping, targetDamping, 0.06);
    dynamicJitter    = lerp(dynamicJitter, targetJitter, 0.06);

    float targetModalComplexity = constrain(
      0.65 * negativeEnergy + 0.35 * emotionalEnergy - 0.25 * positiveEnergy,
      0, 1
    );

    modalComplexity = lerp(modalComplexity, targetModalComplexity, 0.05);
  }

  void buildFromText(String txt) {
    float maxW = width * 0.5;
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

    ArrayList<PVector> candidates = new ArrayList<PVector>();
    int step = Config.DEV_MODE ? 4 : 2;

    for (int y = 0; y < pg.pixelHeight; y += step) {
      for (int x = 0; x < pg.pixelWidth; x += step) {
        int idx = y * pg.pixelWidth + x;

        if (brightness(pg.pixels[idx]) > 128) {
          float px = map(x, 0, pg.pixelWidth, 0, width);
          float py = map(y, 0, pg.pixelHeight, 0, height);
          candidates.add(new PVector(px, py));
        }
      }
    }

    int total = candidates.size();

    if (total == 0) {
      println("[ParticleSystem] buildFromText: nessun pixel trovato");
      return;
    }

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

  void update(float amplitude, float[] fftBands) {
    _processEmotions();
    _processEmotionPhysics();
    updateParticleColors();

    _processAudio(amplitude);
    _processFFT(fftBands);

    _stepParticles();
  }

  void render() {
    pushMatrix();

    colorMode(HSB, 360, 100, 100);

    float bri = ((emotionBri + luminosita) * 0.5) * globalAlpha;

    strokeWeight(particleW * 2.5);

    for (int i = 0; i < N; i++) {
      float sat = saturationForParticle(particles[i]);
      stroke(particles[i].hue, sat, bri);
      point(particles[i].pos.x, particles[i].pos.y);
    }

    colorMode(RGB, 255);
    popMatrix();
  }

  void clear() {
    resetParticles();
  }

  int count() {
    return N;
  }

  void setGlobalAlpha(float a) {
    globalAlpha = constrain(a, 0, 1);
  }

  void _processAudio(float amplitude) {
    float e = amplitude;

    if (e > env) env = lerp(env, e, Config.ENV_ATK);
    else env = lerp(env, e, Config.ENV_REL);

    float diff = env - baseMean;
    baseMean += baseAlpha * diff;
    baseVar += baseAlpha * (diff * diff - baseVar);

    float sigma = sqrt(max(1e-9, baseVar));
    float z = (env - baseMean) / sigma;

    kEnv = constrain((z - Config.Z_FOLLOW_FLOOR) / max(1e-6, Config.Z_FOLLOW_RANGE), 0, 1);
    kEnv = _smooth01(kEnv);

    boolean canFire = (millis() - lastKickMs) > Config.REFRACTORY_MS;

    if (canFire && z > Config.Z_THRESH) {
      lastKickMs = millis();
      frameFromLastKick = 0;

      swirlDirection *= -1.0;

      pickRandomModeSet();

      if (Config.RESET_ON_MODE_CHANGE) resetParticles();

      if (Config.FORCE_KICK_BOOST > 0) {
        float add = Config.FORCE_KICK_BOOST * kEnv;
        float maxExtra = Config.FORCE_GAIN_BASE * (Config.FORCE_KICK_MAX_MULT - 1.0);
        forceKickValue = min(maxExtra, forceKickValue + add);
      }
    }

    frameFromLastKick++;

    float secFromKick = frameFromLastKick / frameRate;

    if (secFromKick > 3.0) baseAlpha = lerp(baseAlpha, 0.03, 0.02);
    else baseAlpha = lerp(baseAlpha, 0.01, 0.02);

    particleW = lerp(
      particleW,
      lerp(Config.BASE_STROKE_W, Config.KICK_STROKE_W, kEnv),
      Config.W_FOLLOW
    );

    luminosita = lerp(
      luminosita,
      lerp(Config.BASE_LUM, Config.KICK_LUM, kEnv),
      Config.L_FOLLOW
    );

    forceKickValue = lerp(forceKickValue, 0, Config.FORCE_DECAY);
    forceGain = Config.FORCE_GAIN_BASE + forceKickValue;

    float t = constrain(
      (amplitude - Config.VOL_MIN) / max(1e-6, Config.VOL_MAX - Config.VOL_MIN),
      0, 1
    );

    edgeTarget = lerp(Config.EDGE_WEIGHT_MAX, Config.EDGE_WEIGHT_MIN, t);
    edgeWeight = lerp(edgeWeight, edgeTarget, Config.EDGE_SMOOTH);

    edgeMargin = constrain(
      (edgeWeight / Config.EDGE_WEIGHT_MAX) *
      (edgeWeight / Config.EDGE_WEIGHT_MAX - random(0.001, 0.01)),
      Config.EDGE_MARGIN_MIN,
      Config.EDGE_MARGIN_MAX
    );
  }

  float bandEnergy(float[] fftBands, int startBin, int endBin) {
    if (fftBands == null || fftBands.length == 0) return 0;

    startBin = constrain(startBin, 0, fftBands.length - 1);
    endBin   = constrain(endBin, startBin + 1, fftBands.length);

    float sum = 0;

    for (int i = startBin; i < endBin; i++) {
      sum += fftBands[i];
    }

    return sum / max(1, endBin - startBin);
  }

  void _processFFT(float[] fftBands) {
    if (fftBands == null || fftBands.length < 232) return;

    float targetLow  = constrain(bandEnergy(fftBands, 1, 6), 0, 1);
    float targetMid  = constrain(bandEnergy(fftBands, 6, 58), 0, 1);
    float targetHigh = constrain(bandEnergy(fftBands, 58, 232), 0, 1);

    lowEnergy  = lerp(lowEnergy, targetLow, 0.08);
    midEnergy  = lerp(midEnergy, targetMid, 0.08);
    highEnergy = lerp(highEnergy, targetHigh, 0.08);
  }

  void _stepParticles() {
    float audioJitter = highEnergy * 0.35;
    float lowPush = lowEnergy * 0.01;
    float swirl = midEnergy * 0.25;

    PVector center = new PVector(width / 2.0, height / 2.0);

    for (int i = 0; i < N; i++) {
      ChladniParticle p = particles[i];

      PVector g = _gradV(p.pos.x, p.pos.y);

      float finalForceGain = dynamicForceGain + forceKickValue;

      p.vel.x += -g.x * finalForceGain;
      p.vel.y += -g.y * finalForceGain;

      float totalJitter = dynamicJitter + audioJitter;

      p.vel.x += random(-totalJitter, totalJitter);
      p.vel.y += random(-totalJitter, totalJitter);

      PVector radial = PVector.sub(p.pos, center);

      if (radial.mag() > 0.0001) {
        radial.normalize();

        p.vel.add(PVector.mult(radial, lowPush));

        PVector tangent = new PVector(-radial.y, radial.x);
        p.vel.add(PVector.mult(tangent, swirl * swirlDirection));
      }

      p.vel.mult(1.0 - dynamicDamping);
      p.pos.add(p.vel);

      if (p.pos.x < 0 || p.pos.x > width - 1 || p.pos.y < 0 || p.pos.y > height - 1) {
        float ang = random(TWO_PI);
        float rad = sqrt(random(1)) * min(width, height) * 0.15;

        p.pos.set(width / 2 + cos(ang) * rad, height / 2 + sin(ang) * rad);
        p.vel.set(random(-0.5, 0.5), random(-0.5, 0.5));
      }
    }
  }

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
    float cx = x - 0.5;
    float cy = y - 0.5;
    float r = min(sqrt(cx * cx + cy * cy) / 0.5, 1.0);

    return sin(n * PI * r) * cos(m * atan2(cy, cx));
  }

  float _V(float x, float y) {
    float v = _A(x, y);
    v = v * v;

    float cx = x - 0.5;
    float cy = y - 0.5;
    float r = min(sqrt(cx * cx + cy * cy) / 0.5, 1.0);

    if (r > 1.0 - edgeMargin) {
      float t = (r - (1.0 - edgeMargin)) / max(1e-6, edgeMargin);
      v += edgeWeight * pow(t, Config.EDGE_POWER);
    }

    return v;
  }

  PVector _gradV(float px, float py) {
    float x = px / width;
    float y = py / height;
    float ex = Config.EPS / width;
    float ey = Config.EPS / height;

    float dVdx = (_V(_c01(x + ex), y) - _V(_c01(x - ex), y)) / (2.0 * ex) / width;
    float dVdy = (_V(x, _c01(y + ey)) - _V(x, _c01(y - ey))) / (2.0 * ey) / height;

    return new PVector(dVdx, dVdy);
  }

  void pickRandomModeSet() {
    randomSet.isCircular = (random(1) < Config.CIRCULAR_PROBABILITY);

    int lowMax = int(lerp(3, 6, 1.0 - modalComplexity));
    int highMax = int(lerp(5, 14, modalComplexity));

    if (!randomSet.isCircular) {
      randomSet.m1 = _ri(2, lowMax);
      randomSet.n1 = _ri(2, lowMax);

      randomSet.m2 = _ri(2, highMax);
      randomSet.n2 = _ri(2, highMax);

      randomSet.m3 = _ri(2, highMax + 2);
      randomSet.n3 = _ri(2, highMax + 2);
    } else {
      randomSet.m1 = _ri(0, lowMax);
      randomSet.n1 = _ri(1, lowMax);

      randomSet.m2 = _ri(0, highMax);
      randomSet.n2 = _ri(1, highMax);

      randomSet.m3 = _ri(0, highMax + 2);
      randomSet.n3 = _ri(1, highMax + 2);
    }

    randomSet.w1 = 1.0;
    randomSet.w2 = random(0.35, 0.95);
    randomSet.w3 = random(0.20, 0.70);
  }

  void resetParticles() {
    for (int i = 0; i < N; i++) {
      particles[i].pos.set(random(width), random(height));
      particles[i].vel.set(random(-0.5, 0.5), random(-0.5, 0.5));
      particles[i].emotion = "";
      particles[i].hue = 0;
      particles[i].nextHue = 0;
    }
  }

  float _tanh(float x) {
    float e = exp(2 * x);
    return (e - 1) / (e + 1);
  }

  float _smooth01(float t) {
    t = constrain(t, 0, 1);
    return t * t * (3 - 2 * t);
  }

  float _c01(float t) {
    return max(0, min(1, t));
  }

  int _ri(int lo, int hi) {
    return (int) random(lo, hi + 1);
  }
}

class ChladniParticle {
  PVector pos = new PVector();
  PVector vel = new PVector();
  float hue = 0;
  float nextHue = 0;
  String emotion = "";
}

class ModeSet {
  boolean isCircular;
  int m1, n1, m2, n2, m3, n3;
  float w1, w2, w3;
}
