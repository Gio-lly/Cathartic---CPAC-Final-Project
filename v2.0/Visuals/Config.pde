// Config.pde  |  global configuration parameters for the interactive installation
// Centralizes the global parameters that control the application's behavior, timing, visuals, audio response, and development settings.

static class Config {

  static boolean DEV_MODE = true;
  static boolean USE_FILE_AUDIO = false; // true = prerecorded audio file, false = live or virtual audio input

  // Finite-State Machine
  static final int STATE_DISCLAIMER = 0;
  static final int STATE_INPUT      = 1;
  static final int STATE_PARTICLES  = 2;
  static final int STATE_THANKS     = 3;
  static final int NUM_STATES       = 4;

  // Timing (ms)
  static int DISCLAIMER_DURATION    = 5000;   // disclaimer duration
  static int PARTICLES_DURATION     = 60000*2;  // particles duration (from Python via OSC)
  static int THANKS_FADE_IN         = 1500*2; // fade-in "Thank you."
  static int THANKS_HOLD            = 2000*2; // "Thank you." duration
  static int THANKS_FADE_OUT        = 2000*2; // fade-out "Thank you."
  static int PARTICLES_FADEOUT_TIME = 3000;   // particles fade-out 

  // Colors
  static int BG_COLOR               = 0;               // black
  static int TEXT_COLOR             = 0xFFFFFFFF;      // white
  static int PARTICLE_BASE_COLOR    = 0xFFFFFFFF;
  static int DISCLAIMER_TEXT_COLOR  = 0xFFAAAAAA;      // light grey

  // Text
  static String DISCLAIMER_TEXT =
    "Everything you write here is private.\nNothing will be saved, recorded or seen by anyone.\n You are free to write whatever you want.";
   
  static String DISCLAIMER_TEXT2 = 
    "Start typing to begin...";

  static String THANKS_TEXT     = "Thank you.";

  static String INPUT_PLACEHOLDER = "Start typing...";
  
  static int maxCharPrompt = 1000;

  // Prompt layout
  // Relative dimensions of the text area shared by input rendering 
  // and particle initialization in buildFromText().
  static float PROMPT_BOX_W_FRAC = 0.75;
  static float PROMPT_BOX_H_FRAC = 1.0;

  // Vertical position of the remaining-character counter, expressed 
  // as a fraction of the screen height relative to its center.
  static float REMAINING_CHARS_OFFSET_FRAC = 0.4;

  // Disclaimer subtitle animation
  static int    DISCLAIMER_SUB_OFFSET_Y  = 120;  // Vertical offset below the main text, in pixels
  static int    DISCLAIMER_SUB_BLINK_IN  = 800;  // Fade-in duration, in ms
  static int    DISCLAIMER_SUB_BLINK_OUT = 800;  // Fade-out duration, in ms
  static int    DISCLAIMER_SUB_HOLD_ON   = 1200; // Visible duration, in ms
  static int    DISCLAIMER_SUB_HOLD_OFF  = 400;  // Invisibile duration, in ms
  static int    DISCLAIMER_SUB_COLOR     = 0xFF444444;  // dark grey
  
  // Chladni ParticleSystem 
  static int    PARTICLE_COUNT        = 30000; // Total number of particles in the simulation
  
  // Field physics
  // Base attraction strength toward the minima of the Chladni field
  static float  FORCE_GAIN_BASE       = 5.0 *5; //10
  // Velocity damping per frame (0 = no damping, 1 = instant stop)
  static float  DAMPING               = 0.10;
  // Random noise added to particle velocity each frame (breaks grid artifacts)
  static float  JITTER                = 0.05;
  // Pixel offset used for numerical gradient computation
  static float  EPS                   = 0.001 ; //2.0

  // Particle repulsion
  // Enable or disable short-range repulsion between particles
  static boolean ENABLE_REPULSION     = true;
  // Distance (px) within which two particles push each other apart
  static float  REPULSION_RADIUS      = 6.0 / 2;
  // Strength of the repulsion at zero distance, fading linearly to 0 at REPULSION_RADIUS
  static float  REPULSION_STRENGTH    = 0.04*10;

  // Particle cohesion
  // Enable/disable the cohesion force computation entirely
  static boolean ENABLE_COHESION      = true;
  // Distance (px) within which two particles attract each other
  static float  COHESION_RADIUS       = 8.0 / 4;
  // Strength of the attraction at COHESION_RADIUS, fading linearly to 0 at distance 0
  static float  COHESION_STRENGTH     = 0.005*4;

  // Edge well
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
  
  // Audio amplitude to edge mapping 
  // Amplitude level considered silence (lower bound for normalization)
  static float  VOL_MIN               = 0.01; // 0.001
  // Amplitude level considered full volume (upper bound for normalization)
  static float  VOL_MAX               = 0.1;
  
  // Transient-driven force impulse
  // Extra force added to particles on each detected kick (scales with kick strength)
  static float  FORCE_KICK_BOOST      = 20.0/15; // 50
  // Safety ceiling: max force multiplier relative to FORCE_GAIN_BASE
  static float  FORCE_KICK_MAX_MULT   = 6.0*1000; // 6
  // How quickly the kick force impulse decays back to baseline each frame (0..1)
  static float  FORCE_DECAY           = 0.10;
  
  // Adaptive amplitude-transient detector
  // Envelope attack speed: how fast the follower rises on a transient (0..1)
  static float  ENV_ATK               = 0.55;
  // Envelope release speed: how fast the follower falls after a transient (0..1)
  static float  ENV_REL               = 0.08;
  // EWMA smoothing for adaptive baseline mean/variance (lower = slower adaptation)
  static float  BASE_ALPHA            = 0.01;
  // Z-score threshold above which a transient event is triggered
  static float  Z_THRESH              = 0.8;
  // Lockout period after a transient is triggered — prevents double-triggers (milliseconds)
  static int    REFRACTORY_MS         = 500; // 100
  // Z-score floor below which continuous kEnv is treated as zero (dead zone)
  static float  Z_FOLLOW_FLOOR        = 0.2;
  // Z-score range mapped to kEnv 0→1 (higher = less sensitive continuous follow)
  static float  Z_FOLLOW_RANGE        = 3.0;
  
  // Visuals
  // Particle stroke weight at rest (no kick)
  static float  BASE_STROKE_W         = 0.8/4; // 0.8
  // Particle stroke weight target during a strong kick envelope
  static float  KICK_STROKE_W         = BASE_STROKE_W; 
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
  static float  PARTICLE_TRASP        = 160.0;
  // Particle smooth transitions vs not black background
  static float  PARTICLE_PERMANENCE   = 30.0;

  // Color gradient drift
  // Speed (px/frame) at which the spatial color gradient drifts when emotionalEnergy = 0
  static float  GRADIENT_DRIFT_MIN_SPEED = 0.1/2;
  // Speed (px/frame) at which the spatial color gradient drifts when emotionalEnergy = 1
  static float  GRADIENT_DRIFT_MAX_SPEED = 1.5/2;
  // Fraction of the spatial gradient occupied by the dominant emotion's color (0..1);
  // the rest is split evenly among the other palette colors
  static float  DOMINANT_EMOTION_SHARE   = 0.6;
  // Smoothing speed for each particle's hue transitioning toward its target gradient color (0..1, lower = smoother/slower)
  static float  HUE_TRANSITION_SPEED     = 0.01;

  // Chladni mode configuration
  // Spatial scaling applied to the Chladni field: 
  // 1 = original scale, values above 1 enlarge the central pattern
  static float   CHLADNI_SCALE         = 1.2;
  // Minimum modal complexity maintained when emotional energy is low (0 = old behaviour, 1 = always max complexity)
  static float   MODAL_COMPLEXITY_BASE = 0.3;
  // Probability of picking a circular Chladni mode vs rectangular (0 = always rect, 1 = always circular)
  static float   CIRCULAR_PROBABILITY  = 0.0;
  // If true, particles are scattered randomly whenever the mode changes on a kick
  static boolean RESET_ON_MODE_CHANGE  = false;

  // Development test prompts
  static String[] DEV_PROMPTS = {
    "I hate my children.", // anger, annoyance
    "I wished happy birthday to a friend I love who has cancer, and my heart breaks knowing she won't be probably here next Christmas",
    "I wish I had a family, children, a partner, lots of people and warmth around me. To eat together, to feel like family. Instead I feel alone, I'm tired, tired of the wrong relationships, tired of facing life by myself",
    "I transitioned and I regret it", // remorse, sadness
    "I had an amazing job offer overseas that I didn't accept and I regret it every day", // remorse, sadness, disappointment
    "I lie to my therapist because I'm afraid of her judgment. I know it's stupid. But I'm scared.", // fear
    "I'm married, but the homosexual side of me that was always inside has finally emerged. And I love it. And I feel caged.",
    "I'm a teacher and I'm attracted to one of my students",
    "My girlfriend is always sad. It's starting to affect me. I try to distance myself and I feel happy when I'm away from her. But I'm afraid to break up with her because of how she might react",
    "I'm pregnant and I'm terrified of my future",
    "I love my husband but I want to sleep with other men",
    "I wish I had a family, children, a partner, lots of people and warmth around me. To eat together, to feel like family. Instead I feel alone, I'm tired, tired of the wrong relationships, tired of facing life by myself"
  };
}
