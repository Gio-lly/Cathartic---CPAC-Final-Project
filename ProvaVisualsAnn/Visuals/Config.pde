// =============================================================
//  Config.pde  |  Costanti e parametri globali
//  Cambia qui per tweakare l'installazione senza toccare la logica
// =============================================================

static class Config {

  // ── Dev mode ─────────────────────────────────────────────
  static boolean DEV_MODE = true;   // <── metti false in produzione
  static boolean USE_FILE_AUDIO = false; // <── metti false per microfono

  // ── Stati FSM ────────────────────────────────────────────
  static final int STATE_DISCLAIMER = 0;
  static final int STATE_INPUT      = 1;
  static final int STATE_PARTICLES  = 2;
  static final int STATE_THANKS     = 3;
  static final int NUM_STATES       = 4;

  // ── Timing (millisecondi) ─────────────────────────────────
  static int DISCLAIMER_DURATION    = 5000;   // quanto resta il disclaimer
  static int PARTICLES_DURATION     = 30000*100;  // durata fase particelle
  static int THANKS_FADE_IN         = 1500;   // fade-in "Grazie"
  static int THANKS_HOLD            = 2000;   // quanto resta visibile
  static int THANKS_FADE_OUT        = 2000;   // fade-out "Grazie"
  static int PARTICLES_FADEOUT_TIME = 3000;   // fade-out particelle

  // ── Colori ───────────────────────────────────────────────
  static int BG_COLOR               = 5;               // nero
  static int TEXT_COLOR             = 0xFFFFFFFF;       // bianco
  static int PARTICLE_BASE_COLOR    = 0xFFFFFFFF;
  static int DISCLAIMER_TEXT_COLOR  = 0xFFAAAAAA;       // grigio chiaro

  // ── Testo ────────────────────────────────────────────────
  static String DISCLAIMER_TEXT =
    "Everything you write here is private.\nNothing will be saved, used or seen by anyone.\nThere is no judgment and no record.\n You are free to write whatever you want.";
   
  static String DISCLAIMER_TEXT2 = 
    "Start typing to begin...";

  static String THANKS_TEXT     = "Thank you.";

  static String INPUT_PLACEHOLDER = "Start typing...";
  
  static int maxCharPrompt = 400;
  
  // ── Sottotitolo disclaimer: blink ─────────────────────────
  static int    DISCLAIMER_SUB_OFFSET_Y  = 120;    // px sotto il testo principale
  static int    DISCLAIMER_SUB_BLINK_IN  = 800;   // ms fade-in
  static int    DISCLAIMER_SUB_BLINK_OUT = 800;   // ms fade-out
  static int    DISCLAIMER_SUB_HOLD_ON   = 1200;  // ms visibile
  static int    DISCLAIMER_SUB_HOLD_OFF  = 400;   // ms invisibile
  static int    DISCLAIMER_SUB_COLOR     = 0xFF444444;  // grigio scuro
  


  // ── Chladni / ParticleSystem ───────────────────────────────
  // Total number of particles in the simulation
  static int    PARTICLE_COUNT        = 30000;
  
  // ── Field physics ──────────────────────────────────────────────────────────
  // Base strength of the force pushing particles toward field minima
  static float  FORCE_GAIN_BASE       = 10.0; //10
  // Velocity damping per frame (0 = no damping, 1 = instant stop)
  static float  DAMPING               = 0.10;
  // Random noise added to particle velocity each frame (breaks grid artifacts)
  static float  JITTER                = 0.05;
  // Pixel offset used for numerical gradient computation
  static float  EPS                   = 0.001 ; //2.0

  // ── Edge well ──────────────────────────────────────────────────────────────
  // Minimum edge repulsion weight (at low volume)
  static float  EDGE_WEIGHT_MIN       = 0.0;
  // Maximum edge repulsion weight (at high volume)
  static float  EDGE_WEIGHT_MAX       = 10.0;
  // Minimum edge margin — how thin the border repulsion zone can get (0..1)
  static float  EDGE_MARGIN_MIN       = 0.001;
  // Maximum edge margin — how wide the border repulsion zone can get (0..1)
  static float  EDGE_MARGIN_MAX       = 0.90;
  // Exponent controlling how sharply the edge force ramps up (higher = harder wall)
  static float  EDGE_POWER            = 2.0;
  // Smoothing factor for edge weight transitions (0 = instant, 1 = never moves)
  static float  EDGE_SMOOTH           = 0.9;
  
  // ── Volume → edge mapping ──────────────────────────────────────────────────
  // Amplitude level considered silence (lower bound for normalization)
  static float  VOL_MIN               = 0.001*50; // 0.001
  // Amplitude level considered full volume (upper bound for normalization)
  static float  VOL_MAX               = 0.5;
  
  // ── Kick → force impulse ───────────────────────────────────────────────────
  // Extra force added to particles on each detected kick (scales with kick strength)
  static float  FORCE_KICK_BOOST      = 50.0; // 1500
  // Safety ceiling: max force multiplier relative to FORCE_GAIN_BASE
  static float  FORCE_KICK_MAX_MULT   = 6.0*1000; // 6
  // How quickly the kick force impulse decays back to baseline each frame (0..1)
  static float  FORCE_DECAY           = 0.10;
  
  // ── Kick envelope detector ─────────────────────────────────────────────────
  // High-pass cutoff for kick band isolation (Hz) — filters out DC / sub rumble
  static float  KICK_HP               = 20.0;
  // Low-pass cutoff for kick band isolation (Hz) — keeps only bass transients
  static float  KICK_LP               = 140.0;
  // Envelope attack speed: how fast the follower rises on a transient (0..1)
  static float  ENV_ATK               = 0.55;
  // Envelope release speed: how fast the follower falls after a transient (0..1)
  static float  ENV_REL               = 0.08;
  // EWMA smoothing for adaptive baseline mean/variance (lower = slower adaptation)
  static float  BASE_ALPHA            = 0.01;
  // Z-score threshold above which a discrete kick event is fired
  static float  Z_THRESH              = 0.8;
  // Lockout period after a kick fires — prevents double-triggers (milliseconds)
  static int    REFRACTORY_MS         = 1000 * 1; // 100
  // Z-score floor below which continuous kEnv is treated as zero (dead zone)
  static float  Z_FOLLOW_FLOOR        = 0.2;
  // Z-score range mapped to kEnv 0→1 (higher = less sensitive continuous follow)
  static float  Z_FOLLOW_RANGE        = 3.0;
  
  // ── Visuals ────────────────────────────────────────────────────────────────
  // Particle stroke weight at rest (no kick)
  static float  BASE_STROKE_W         = 0.8;
  // Particle stroke weight target during a strong kick envelope
  static float  KICK_STROKE_W         = 1.2;
  // Smoothing speed for stroke weight transitions (0..1)
  static float  W_FOLLOW              = 0.18;
  // Particle brightness at rest, HSB scale 0→100
  static float  BASE_LUM              = 100.0;
  // Particle brightness target during a strong kick envelope, HSB scale 0→100
  static float  KICK_LUM              = 100.0;
  // Smoothing speed for brightness transitions (0..1)
  static float  L_FOLLOW              = 0.10;
  // Particle hue, HSB scale 0→360 (0 = white/grey when saturation is 0)
  static float  PARTICLE_HUE          = 0.0;
  // Particle saturation, HSB scale 0→100 (0 = greyscale)
  static float  PARTICLE_SAT          = 0.0;
  // Particle trasparancy
  static float  PARTICLE_TRASP        = 5.0;
  
  static float  PARTICLE_PERMANENCE   = 15.0;

  // ── Color gradient drift ──────────────────────────────────────────────────
  // Speed (px/frame) at which the spatial color gradient drifts when emotionalEnergy = 0
  static float  GRADIENT_DRIFT_MIN_SPEED = 0.1;
  // Speed (px/frame) at which the spatial color gradient drifts when emotionalEnergy = 1
  static float  GRADIENT_DRIFT_MAX_SPEED = 1.5;
  // Fraction of the spatial gradient occupied by the dominant emotion's color (0..1);
  // the rest is split evenly among the other palette colors
  static float  DOMINANT_EMOTION_SHARE   = 0.6;
  // Smoothing speed for each particle's hue transitioning toward its target gradient color (0..1, lower = smoother/slower)
  static float  HUE_TRANSITION_SPEED     = 0.01;

  // ── Modes ──────────────────────────────────────────────────────────────────
  // Probability of picking a circular Chladni mode vs rectangular (0 = always rect, 1 = always circular)
  static float   CIRCULAR_PROBABILITY  = 0.0;
  // If true, particles are scattered randomly whenever the mode changes on a kick
  static boolean RESET_ON_MODE_CHANGE  = false;

  // ── Dev: testi preset ────────────────────────────────────
  static String[] DEV_PROMPTS = {
    "I hate my children.",
    "I feel sad.",
    "vghjilkhgftyuijkbhgvfcftyuhjbgvftyguhjbgvfygtuhjbgftyghjbvgftyguhjbvgcftyguhvcftyghvcfgtyghvftgghvcfgtghv"
  };
}
