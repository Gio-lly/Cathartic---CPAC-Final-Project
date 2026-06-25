//  AudioManager.pde: audio input, playback and real-time signal analysis

class AudioManager {
  Sound        sound;
  AudioIn      input;
  SoundFile    player;
  FFT          fft;
  Amplitude    amp;
  BeatDetector beat;

  boolean active            = false;
  boolean fileMode          = false;
  float   smoothedAmplitude = 0;
  float[] fftValues;
  float[] rawFft;

  static final int    FFT_BANDS    = 512;
  static final float  SMOOTH       = 0.15;
  static final int INPUT_DEVICE_MAC = 13;   // BlackHole 2ch on Mac
  static final int INPUT_DEVICE_WIN = 41;   // default on Windows (ex. VB-Cable)
  static final String AUDIO_FILE   = "Universel.mp3";

  // Initialization
  AudioManager() {
    sound = new Sound(Visuals.this);
    Sound.list();   // stampa device disponibili in console (utile per debug)
    fftValues = new float[FFT_BANDS];
    rawFft    = new float[FFT_BANDS];
    println("[AudioManager] Sound inizializzato");
  }

  // Default audio input
  void start() { startMic(); }

  // Live audio input
  void startMic() {
    if (active) stop();
    delay(500); // Small delay: allow the previous audio line to be released
    fileMode = false;
    try {
      int deviceIndex;
      String os = System.getProperty("os.name").toLowerCase();
      
      if (os.contains("mac")) {
      deviceIndex = INPUT_DEVICE_MAC;
      println("[AudioManager] Sistema: macOS, uso device " + deviceIndex);
    } else if (os.contains("win")) {
      deviceIndex = INPUT_DEVICE_WIN;
      println("[AudioManager] Sistema: Windows, uso device " + deviceIndex);
    } else {
      deviceIndex = 41;   // fallback Linux/altro
      println("[AudioManager] Sistema: " + os + ", uso device " + deviceIndex);
    }
    sound = new Sound(Visuals.this);
    sound.inputDevice(deviceIndex);
    input = new AudioIn(Visuals.this, 0);
    input.start();
    _initDSP(input);
    active = true;
    println("[AudioManager] Input device " + deviceIndex + " aperto");
  } catch (Exception e) {
    println("[AudioManager] ERRORE input: " + e.getMessage());
    active = false;
  }
}
      
  // Audio file playback
  void startFile() {
    if (active) stop();
    fileMode = true;
    try {
      player = new SoundFile(Visuals.this, AUDIO_FILE);
      if (player.frames() <= 0) {
        println("[AudioManager] ERRORE: file " + AUDIO_FILE + " non trovato in data/");
        active = false;
        return;
      }
      player.loop();   // loop continuo; usa player.play() per una sola riproduzione
      _initDSP(player);
      active = true;
      println("[AudioManager] File audio avviato: " + AUDIO_FILE);
    } catch (Exception e) {
      println("[AudioManager] ERRORE file audio: " + e.getMessage());
      active = false;
    }
  }
  
  // DSP analyzer setup
  void _initDSP(AudioIn source) {
    fft  = new FFT(Visuals.this, FFT_BANDS);
    amp  = new Amplitude(Visuals.this);
    beat = new BeatDetector(Visuals.this);
    fft.input(source);
    amp.input(source);
    beat.input(source);
  }

  void _initDSP(SoundFile source) {
    fft  = new FFT(Visuals.this, FFT_BANDS);
    amp  = new Amplitude(Visuals.this);
    beat = new BeatDetector(Visuals.this);
    fft.input(source);
    amp.input(source);
    beat.input(source);
  }

  // Audio resource cleanup
  void stop() {
    if (input  != null) { input.stop();  input  = null; }
    if (player != null) { player.stop(); player = null; }
    active   = false;
    fileMode = false;
    println("[AudioManager] Audio chiuso");
  }

  // Amplitude analysis
  float getAmplitude() {
    if (!active || amp == null) return 0;
    float raw = amp.analyze();
    smoothedAmplitude += (raw - smoothedAmplitude) * SMOOTH;
    return smoothedAmplitude;
  }

  // Frequency spectrum analysis
  float[] getFFT() {
    if (!active || fft == null) return fftValues;
    fft.analyze(rawFft);
    for (int i = 0; i < FFT_BANDS; i++) {
      fftValues[i] += (rawFft[i] - fftValues[i]) * SMOOTH;
    }
    return fftValues;
  }

  // Beat and percussion detection
  boolean isBeat() {
    if (!active || beat == null) return false;
    return beat.isBeat();
  }

  boolean isKick() {
    if (!active || fftValues == null) return false;
    float energy = 0;
    int lo = 1, hi = 8;             // ~ 0-350 Hz a 44.1kHz / 512 bande
    for (int i = lo; i < hi; i++) energy += fftValues[i];
    energy /= (hi - lo);
    return energy > 0.04;           // soglia da tarare
  }

  boolean isSnare() {
    if (!active || fftValues == null) return false;
    float energy = 0;
    int lo = 40, hi = 100;          // ~ 1.5-4 kHz
    for (int i = lo; i < hi; i++) energy += fftValues[i];
    energy /= (hi - lo);
    return energy > 0.02;           // soglia da tarare
  }

  // Playback state and controls
  boolean isFileMode() { return fileMode; }
  boolean isPlaying()  { return fileMode && player != null && player.isPlaying(); }

  void togglePause() {
    if (!fileMode || player == null) return;
    if (player.isPlaying()) player.pause();
    else                    player.play();
  }
}
