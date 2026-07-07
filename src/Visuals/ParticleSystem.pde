//  ParticleSystem.pde  |  Particle pool + Chladni force field
// Manages the initialization, motion and rendering of the particle field. Particles are initially arranged from the pixels of the user's text,
// then attracted toward the nodal lines of a rectangular Chladni field. Audio transients generate new modal patterns and temporary force boosts,
// while low-, mid- and high-frequency energy respectively control radial motion, rotational motion and local particle jitter.
// Emotion scores influence the field strength, damping, modal complexity, brightness, saturation and the spatial distribution of the colour palette.
// The system also handles short-range particle repulsion and cohesion, edge containment, fade-out opacity and developer-mode field visualization.

class ParticleSystem {
  //  SYSTEM STATE
  // Emotion state
  float positiveEnergy = 0;
  float negativeEnergy = 0;
  float emotionalEnergy = 0;

  float emotionBri = 100;
  float modalComplexity = 0;

  // Color palette
  ArrayList<String> paletteEmotions = new ArrayList<String>();
  static final int MAX_PALETTE_COLORS = 3;
  int paletteDominantIdx = 0;

  PVector gradientOffset = new PVector();
  float gradientDriftT = 0;

  // Particles
  ChladniParticle[] particles;
  int N;

  // Dynamic particle physics
  float forceKickValue = 0;
  float dynamicDamping;
  float dynamicJitter;
  float dynamicForceGain;

  // Particle repulsion (spatial hash grid)
  IntList[] repulsionGrid;
  int repulsionCols, repulsionRows;
  float repulsionCellSize;

  // Particle cohesion (spatial hash grid) 
  IntList[] cohesionGrid;
  int cohesionCols, cohesionRows;
  float cohesionCellSize;

  // FFT bands
  float lowEnergy = 0;
  float midEnergy = 0;
  float highEnergy = 0;

  // Swirl / rotation
  float swirlDirection = 1.0;

  // Edge 
  float edgeWeight = 5.0;
  float edgeMargin = 0.1;

  // Kick envelope state 
  float env = 0;
  float baseMean = 0;
  float baseVar = 1e-6;
  float baseAlpha;
  int lastKickMs = -999999;
  int frameFromLastKick = 0;

  // Alpha (for fade-out)
  float globalAlpha = 1.0;

  // Mode 
  ModeSet randomSet;

// INITIALIZATION
  ParticleSystem() {
    N = Config.PARTICLE_COUNT;
    particles = new ChladniParticle[N];

    baseAlpha = Config.BASE_ALPHA;
    randomSet = new ModeSet();

    dynamicForceGain = Config.FORCE_GAIN_BASE;
    dynamicDamping = Config.DAMPING;
    dynamicJitter = Config.JITTER;

    for (int i = 0; i < N; i++) particles[i] = new ChladniParticle();

    repulsionCellSize = max(1.0, Config.REPULSION_RADIUS);
    repulsionCols = ceil(width / repulsionCellSize) + 1;
    repulsionRows = ceil(height / repulsionCellSize) + 1;

    repulsionGrid = new IntList[repulsionCols * repulsionRows];
    for (int i = 0; i < repulsionGrid.length; i++) repulsionGrid[i] = new IntList();

    cohesionCellSize = max(1.0, Config.COHESION_RADIUS);
    cohesionCols = ceil(width / cohesionCellSize) + 1;
    cohesionRows = ceil(height / cohesionCellSize) + 1;

    cohesionGrid = new IntList[cohesionCols * cohesionRows];
    for (int i = 0; i < cohesionGrid.length; i++) cohesionGrid[i] = new IntList();

    resetParticles();
    pickRandomModeSet();

    println("[ParticleSystem] Chladni init — " + N + " particles");
  }

//  EMOTION LOOKUP
  //  Small helpers that read the global `emotions` map (name -> 0..1 score) 
  //  and classify/map emotions to colors and energy levels.

  float emo(String name) {
    if (emotions.containsKey(name)) return emotions.get(name);
    return 0;
  }

  // Fixed hue per emotion, used both for the palette and as a fallback
  // when no emotion data is available yet (returns neutral hue 0).
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

    return 0;
  }

//  EMOTION -> PHYSICS / COLOR MAPPING

  // Aggregates the raw per-emotion scores into positive/negative/total energy, 
  // and smooths the global saturation/brightness targets used when rendering particles.
  void processEmotions() {
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
      float targetBrightness = lerp(55, 100, emotionalEnergy);
      emotionBri = lerp(emotionBri, targetBrightness, 0.08);
    } else {
      emotionBri = lerp(emotionBri, 60, 0.05);
    }
  }

  // Maps emotional energy onto the physics parameters: negative emotions
  // make the field pull harder and the pattern more complex, positive
  // emotions make particles settle (more damping).
  void processEmotionPhysics() {
    float tension = negativeEnergy;
    float openness = positiveEnergy;

    float targetForceGain = Config.FORCE_GAIN_BASE * lerp(1.1, 1.5, tension);
    float targetDamping = lerp(0.05, 0.13, openness);
    float targetJitter = lerp(0.05, 0.3, emotionalEnergy);

    dynamicForceGain = lerp(dynamicForceGain, targetForceGain, 0.06);
    dynamicDamping   = lerp(dynamicDamping, targetDamping, 0.06);
    dynamicJitter    = lerp(dynamicJitter, targetJitter, 0.06);

    float targetModalComplexity = constrain(
      Config.MODAL_COMPLEXITY_BASE +
      0.65 * negativeEnergy + 0.35 * emotionalEnergy - 0.25 * positiveEnergy,
      0, 1
    );

    modalComplexity = lerp(modalComplexity, targetModalComplexity, 0.05);
  }

  // Global saturation increases with emotional intensity,
  // while neutral energy shifts the palette toward white.
  float currentSaturation() {
    float baseSaturation = lerp(10, 60, emotionalEnergy);
    float neutralEnergy = emo("neutral");

    return baseSaturation * (1.0 - neutralEnergy);
  }

//  COLOR PALETTE & SPATIAL GRADIENT

  //  Particles don't all share one color: the canvas is covered by a slowly drifting noise field 
  //  that assigns each spot one of up to MAX_PALETTE_COLORS emotion hues, with the dominant emotion
  //  covering the largest share of space.

  void updateParticleColors() {
    if (emotionalEnergy <= 0.05) return;

    for (int i = 0; i < N; i++) {
      ChladniParticle p = particles[i];
      float targetHue = hueFromSpatialGradient(p.pos);

      // Smooth transition toward the spatial field's target color
      p.hue = lerpHue(p.hue, targetHue, Config.HUE_TRANSITION_SPEED);
    }
  }

  // Adds emotions that cross the threshold to the palette, never removing
  // any (the palette only resets at the end of a state, see clear()).
  void updatePalette() {
    if (paletteEmotions.size() < MAX_PALETTE_COLORS) {
      for (String key : emotions.keySet()) {
        if (key.equals("neutral")) continue;
        if (paletteEmotions.contains(key)) continue;

        if (emotions.get(key) > 0.03) {
          paletteEmotions.add(key);
          if (paletteEmotions.size() >= MAX_PALETTE_COLORS) break;
        }
      }
    }

    // Track which palette entry corresponds to the currently strongest emotion
    paletteDominantIdx = 0;
    float bestVal = -1;

    for (int i = 0; i < paletteEmotions.size(); i++) {
      float val = emo(paletteEmotions.get(i));
      if (val > bestVal) {
        bestVal = val;
        paletteDominantIdx = i;
      }
    }
  }

  // Drifts the spatial color gradient over time: 
  // direction changes organically (noise), speed follows emotionalEnergy.
  void updateGradientDrift() {
    gradientDriftT += 0.002;

    float angle = noise(gradientDriftT) * TWO_PI;
    float speed = lerp(Config.GRADIENT_DRIFT_MIN_SPEED, Config.GRADIENT_DRIFT_MAX_SPEED, emotionalEnergy);

    gradientOffset.x += cos(angle) * speed;
    gradientOffset.y += sin(angle) * speed;
  }

  void resetPalette() {
    paletteEmotions.clear();
    gradientOffset.set(0, 0);
  }

  // Picks the palette hue for a given position based on a noise field,
  // not interpolated: each zone uses one of the palette colors outright,
  // and the dominant emotion occupies a larger share of the space.
  float hueFromSpatialGradient(PVector pos) {
    int numColors = paletteEmotions.size();

    if (numColors == 0) return 0;
    if (numColors == 1) return hueForEmotion(paletteEmotions.get(0));

    // Lower = wider, softer gradient zones; higher = denser, more detailed
    float scale = 0.002;

    float t = noise((pos.x + gradientOffset.x) * scale, (pos.y + gradientOffset.y) * scale);

    float dominantShare = Config.DOMINANT_EMOTION_SHARE;
    float otherShare = (1.0 - dominantShare) / (numColors - 1);

    float acc = 0;

    for (int i = 0; i < numColors; i++) {
      acc += (i == paletteDominantIdx) ? dominantShare : otherShare;

      if (t < acc || i == numColors - 1) {
        return hueForEmotion(paletteEmotions.get(i));
      }
    }

    return hueForEmotion(paletteEmotions.get(paletteDominantIdx));
  }

  // Interpolates hue along the shortest path around the color wheel.
  float lerpHue(float a, float b, float t) {
    float d = b - a;

    if (abs(d) > 180) {
      if (d > 0) a += 360;
      else b += 360;
    }

    return (lerp(a, b, t) + 360) % 360;
  }

//  TEXT -> PARTICLES
  //  Renders the given text offscreen and seeds particle positions
  //  from its bright pixels, so the pattern starts out spelling the text.

  void buildFromText(String txt) {
    float maxW = width * Config.PROMPT_BOX_W_FRAC;
    float maxH = height * Config.PROMPT_BOX_H_FRAC;

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
      println("[ParticleSystem] buildFromText: no pixels found");
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

    println("[ParticleSystem] buildFromText — candidates: " + total + ", particles: " + N);
  }


//  MAIN LOOP (called once per frame by the owning state)
  void update(float amplitude, float[] fftBands) {
    processEmotions();
    processEmotionPhysics();
    updatePalette();
    updateGradientDrift();
    updateParticleColors();

    processAudio(amplitude);
    processFFT(fftBands);

    stepParticles();
  }

  void render() {
    pushMatrix();

    colorMode(HSB, 360, 100, 100, 255);

    float bri =
        ((emotionBri + Config.BASE_LUM) * 0.5) *
        globalAlpha;

    float saturation = currentSaturation();

    strokeWeight(Config.BASE_STROKE_W * 2.5);
  
  for (int i = 0; i < N; i++) {
    ChladniParticle p = particles[i];
  
    stroke(p.hue, saturation, bri, Config.PARTICLE_TRASP);
    point(p.pos.x, p.pos.y);
  }

    colorMode(RGB, 255);
    popMatrix();
  }

  // Debug overlay (DEV_MODE): draws the Chladni nodal lines (where the
  // field amplitude ≈ 0), i.e. the figure the particles converge toward.
  void renderChladniField() {
    pushStyle();
    colorMode(RGB, 255);
    noStroke();
    fill(255, 0, 80, 200);

    int step = 4;
    float threshold = 0.04;

    for (int py = 0; py < height; py += step) {
      for (int px = 0; px < width; px += step) {
        float x = px / (float) width;
        float y = py / (float) height;

        if (abs(chladniAmplitude(x, y)) < threshold) {
          rect(px, py, step, step);
        }
      }
    }

    popStyle();
  }

  void clear() {
    resetParticles();
    resetPalette();
  }

  int count() {
    return N;
  }

  void setGlobalAlpha(float a) {
    globalAlpha = constrain(a, 0, 1);
  }


//  AUDIO REACTIVITY
  //  Tracks the amplitude envelope against its own running mean/variance
  //  (an adaptive z-score) to detect "kicks" — sudden loud moments —
  //  which trigger a new Chladni mode set and a temporary force boost.

  void processAudio(float amplitude) {
    float e = amplitude;

    if (e > env) env = lerp(env, e, Config.ENV_ATK);
    else env = lerp(env, e, Config.ENV_REL);

    float diff = env - baseMean;
    baseMean += baseAlpha * diff;
    baseVar += baseAlpha * (diff * diff - baseVar);

    float sigma = sqrt(max(1e-9, baseVar));
    float z = (env - baseMean) / sigma;

    float kickEnvelope = constrain(
      (z - Config.Z_FOLLOW_FLOOR) /
      max(1e-6, Config.Z_FOLLOW_RANGE),
      0,
      1
    );

kickEnvelope = smoothstep01(kickEnvelope);

    boolean canFire = (millis() - lastKickMs) > Config.REFRACTORY_MS;

    if (canFire && z > Config.Z_THRESH) {
      lastKickMs = millis();
      frameFromLastKick = 0;

      swirlDirection *= -1.0;

      pickRandomModeSet();

      if (Config.RESET_ON_MODE_CHANGE) resetParticles();

      if (Config.FORCE_KICK_BOOST > 0) {
        float add = Config.FORCE_KICK_BOOST * kickEnvelope;
        float maxExtra = Config.FORCE_GAIN_BASE * (Config.FORCE_KICK_MAX_MULT - 1.0);
        forceKickValue = min(maxExtra, forceKickValue + add);
      }
    }

    frameFromLastKick++;

    float secFromKick = frameFromLastKick / frameRate;

    if (secFromKick > 3.0) baseAlpha = lerp(baseAlpha, 0.03, 0.02);
    else baseAlpha = lerp(baseAlpha, 0.01, 0.02);

    forceKickValue = lerp(forceKickValue, 0, Config.FORCE_DECAY);

    float t = constrain(
      (amplitude - Config.VOL_MIN) / max(1e-6, Config.VOL_MAX - Config.VOL_MIN),
      0, 1
    );

    float targetEdgeWeight = lerp(
      Config.EDGE_WEIGHT_MAX,
      Config.EDGE_WEIGHT_MIN,
      t
    );
    
    edgeWeight = lerp(
      edgeWeight,
      targetEdgeWeight,
      Config.EDGE_SMOOTH
    );

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

  void processFFT(float[] fftBands) {
    if (fftBands == null || fftBands.length < 232) return;

    float targetLow  = constrain(bandEnergy(fftBands, 1, 6), 0, 1);
    float targetMid  = constrain(bandEnergy(fftBands, 6, 58), 0, 1);
    float targetHigh = constrain(bandEnergy(fftBands, 58, 232), 0, 1);

    lowEnergy  = lerp(lowEnergy, targetLow, 0.08);
    midEnergy  = lerp(midEnergy, targetMid, 0.08);
    highEnergy = lerp(highEnergy, targetHigh, 0.08);
  }


//  PARTICLE PHYSICS STEP
  //  Each frame: follow the Chladni field gradient, add audio-driven
  //  jitter/push/swirl, apply repulsion + cohesion between neighbors,
  //  integrate velocity into position, and wrap particles that leave
  //  the canvas back toward the center.

  void stepParticles() {
    float audioJitter = highEnergy * 0.35;
    float lowPush = lowEnergy * 0.01;
    float swirl = midEnergy * 0.25;

    PVector center = new PVector(width / 2.0, height / 2.0);

    if (Config.ENABLE_REPULSION) buildRepulsionGrid();
    if (Config.ENABLE_COHESION) buildCohesionGrid();

    for (int i = 0; i < N; i++) {
      ChladniParticle p = particles[i];

      PVector g = gradV(p.pos.x, p.pos.y);

      float finalForceGain = dynamicForceGain + forceKickValue;

      p.vel.x += -g.x * finalForceGain;
      p.vel.y += -g.y * finalForceGain;

      float totalJitter = dynamicJitter + audioJitter;

      p.vel.x += random(-totalJitter, totalJitter);
      p.vel.y += random(-totalJitter, totalJitter);

      if (Config.ENABLE_REPULSION) applyRepulsion(p, i);
      if (Config.ENABLE_COHESION) applyCohesion(p, i);

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

  // Buckets particles into the spatial grid (cells sized REPULSION_RADIUS),
  // used to quickly find neighbors for repulsion.
  void buildRepulsionGrid() {
    for (IntList cell : repulsionGrid) cell.clear();

    for (int i = 0; i < N; i++) {
      int cx = (int) constrain(particles[i].pos.x / repulsionCellSize, 0, repulsionCols - 1);
      int cy = (int) constrain(particles[i].pos.y / repulsionCellSize, 0, repulsionRows - 1);
      repulsionGrid[cy * repulsionCols + cx].append(i);
    }
  }

  // Light mutual repulsion between nearby particles: keeps them from
  // collapsing onto the same point and gives the pattern's lines some width.
  void applyRepulsion(ChladniParticle p, int idx) {
    float radius = Config.REPULSION_RADIUS;
    if (radius <= 0 || Config.REPULSION_STRENGTH == 0) return;

    float radiusSq = radius * radius;

    int cx = (int) constrain(p.pos.x / repulsionCellSize, 0, repulsionCols - 1);
    int cy = (int) constrain(p.pos.y / repulsionCellSize, 0, repulsionRows - 1);

    int gx0 = max(0, cx - 1), gx1 = min(repulsionCols - 1, cx + 1);
    int gy0 = max(0, cy - 1), gy1 = min(repulsionRows - 1, cy + 1);

    for (int gy = gy0; gy <= gy1; gy++) {
      for (int gx = gx0; gx <= gx1; gx++) {
        IntList cell = repulsionGrid[gy * repulsionCols + gx];

        for (int k = 0; k < cell.size(); k++) {
          int j = cell.get(k);
          if (j == idx) continue;

          float dx = p.pos.x - particles[j].pos.x;
          float dy = p.pos.y - particles[j].pos.y;
          float distSq = dx * dx + dy * dy;

          if (distSq < radiusSq && distSq > 1e-6) {
            float dist = sqrt(distSq);
            float falloff = 1.0 - dist / radius;

            p.vel.x += (dx / dist) * Config.REPULSION_STRENGTH * falloff;
            p.vel.y += (dy / dist) * Config.REPULSION_STRENGTH * falloff;
          }
        }
      }
    }
  }

  // Buckets particles into the spatial grid (cells sized COHESION_RADIUS),
  // used to quickly find neighbors for cohesion.
  void buildCohesionGrid() {
    for (IntList cell : cohesionGrid) cell.clear();

    for (int i = 0; i < N; i++) {
      int cx = (int) constrain(particles[i].pos.x / cohesionCellSize, 0, cohesionCols - 1);
      int cy = (int) constrain(particles[i].pos.y / cohesionCellSize, 0, cohesionRows - 1);
      cohesionGrid[cy * cohesionCols + cx].append(i);
    }
  }

  // Light mutual attraction between nearby particles: keeps clusters
  // together, giving the pattern's lines more body without collapsing them.
  void applyCohesion(ChladniParticle p, int idx) {
    float radius = Config.COHESION_RADIUS;
    if (radius <= 0 || Config.COHESION_STRENGTH == 0) return;

    float radiusSq = radius * radius;

    int cx = (int) constrain(p.pos.x / cohesionCellSize, 0, cohesionCols - 1);
    int cy = (int) constrain(p.pos.y / cohesionCellSize, 0, cohesionRows - 1);

    int gx0 = max(0, cx - 1), gx1 = min(cohesionCols - 1, cx + 1);
    int gy0 = max(0, cy - 1), gy1 = min(cohesionRows - 1, cy + 1);

    for (int gy = gy0; gy <= gy1; gy++) {
      for (int gx = gx0; gx <= gx1; gx++) {
        IntList cell = cohesionGrid[gy * cohesionCols + gx];

        for (int k = 0; k < cell.size(); k++) {
          int j = cell.get(k);
          if (j == idx) continue;

          float dx = particles[j].pos.x - p.pos.x;
          float dy = particles[j].pos.y - p.pos.y;
          float distSq = dx * dx + dy * dy;

          if (distSq < radiusSq && distSq > 1e-6) {
            float dist = sqrt(distSq);
            float falloff = dist / radius;

            p.vel.x += (dx / dist) * Config.COHESION_STRENGTH * falloff;
            p.vel.y += (dy / dist) * Config.COHESION_STRENGTH * falloff;
          }
        }
      }
    }
  }

//  CHLADNI FIELD MATH
  //  The field is a sum of 2-3 weighted vibration modes (rectangular
  //  or circular plate), chosen randomly and re-rolled on each audio
  //  kick. Particles are pushed downhill on V = A², the squared field
  //  amplitude, so they settle on its nodal lines (A ≈ 0).

  float chladniAmplitude(float x, float y) {
    // Zoom in on the pattern center: same modes span a smaller portion of
    // [0,1], so their nodal lines appear larger on screen.
    float zx = 0.5 + (x - 0.5) / Config.CHLADNI_SCALE;
    float zy = 0.5 + (y - 0.5) / Config.CHLADNI_SCALE;

    float a = 0;

    a += randomSet.w1 *
     chladniModeRect(zx, zy, randomSet.m1, randomSet.n1);

    a += randomSet.w2 *
         chladniModeRect(zx, zy, randomSet.m2, randomSet.n2);
    
    a += randomSet.w3 *
         chladniModeRect(zx, zy, randomSet.m3, randomSet.n3);

    return fastTanh(a * 1.2);
  }

  float chladniModeRect(float x, float y, int m, int n) {
    return sin(m * PI * x) * sin(n * PI * y);
  }

  // Potential particles descend: squared field amplitude, with an extra
  // wall added near the canvas edge to keep particles from drifting off.
  float potentialV(float x, float y) {
    float v = chladniAmplitude(x, y);
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

  // Numeric gradient of the potential at a pixel position, used to push
  // particles downhill toward the nodal lines.
  PVector gradV(float px, float py) {
    float x = px / width;
    float y = py / height;
    float ex = Config.EPS / width;
    float ey = Config.EPS / height;

    float dVdx = (potentialV(clamp01(x + ex), y) - potentialV(clamp01(x - ex), y)) / (2.0 * ex) / width;
    float dVdy = (potentialV(x, clamp01(y + ey)) - potentialV(x, clamp01(y - ey))) / (2.0 * ey) / height;

    return new PVector(dVdx, dVdy);
  }

  // Rolls a new random combination of Chladni modes. Modal complexity
  // (driven by emotion) widens the range of mode numbers used.
  void pickRandomModeSet() {
    int lowMax = int(lerp(3, 6, 1.0 - modalComplexity));
    int highMax = int(lerp(5, 14, modalComplexity));

      randomSet.m1 = randomInt(2, lowMax);
      randomSet.n1 = randomInt(2, lowMax);

      randomSet.m2 = randomInt(2, highMax);
      randomSet.n2 = randomInt(2, highMax);

      randomSet.m3 = randomInt(0, highMax + 2);
      randomSet.n3 = randomInt(1, highMax + 2);
  
    randomSet.w1 = 1.0;
    randomSet.w2 = random(0.35, 0.95);
    randomSet.w3 = random(0.20, 0.70);
  }


//  RESET AND MATH UTILITIES

  void resetParticles() {
    for (int i = 0; i < N; i++) {
      particles[i].pos.set(random(width), random(height));
      particles[i].vel.set(random(-0.5, 0.5), random(-0.5, 0.5));
      particles[i].hue = 0;
    }
  }

  float fastTanh(float x) {
    float e = exp(2 * x);
    return (e - 1) / (e + 1);
  }

  float smoothstep01(float t) {
    t = constrain(t, 0, 1);
    return t * t * (3 - 2 * t);
  }

  float clamp01(float t) {
    return max(0, min(1, t));
  }

  int randomInt(int lo, int hi) {
    return (int) random(lo, hi + 1);
  }
}


//  SUPPORTING DATA CLASSES

class ChladniParticle {
  PVector pos = new PVector();
  PVector vel = new PVector();
  float hue = 0;
}

class ModeSet {
  int m1, n1, m2, n2, m3, n3;
  float w1, w2, w3;
}
