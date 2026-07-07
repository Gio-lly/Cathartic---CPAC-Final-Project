// AudioManager.pde | audio input, playback and real-time signal analysis
// Manages live audio input and provides smoothed amplitude and FFT data to the visual system.

class AudioManager {
  Sound        sound;
  AudioIn      input;
  SoundFile    player;
  FFT          fft;
  Amplitude    amp;

  boolean active            = false;
  boolean fileMode          = false;
  float   smoothedAmplitude = 0;
  float[] fftValues;
  float[] rawFft;

  static final int    FFT_BANDS    = 512;
  static final float  SMOOTH       = 0.15;
  static final int INPUT_DEVICE_MAC = 9;   // BlackHole 2ch on Mac
  static final int INPUT_DEVICE_WIN = 41;   // default on Windows (ex. VB-Cable)
  static final String AUDIO_FILE   = "Universel.mp3";

  // Initialization
  AudioManager() {
    sound = new Sound(Visuals.this);
    Sound.list();
    fftValues = new float[FFT_BANDS];
    rawFft    = new float[FFT_BANDS];
    println("[AudioManager] Sound inizializzato");
  }

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
      deviceIndex = INPUT_DEVICE_WIN;   // fallback Linux/altro
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
      player.loop();
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
    fft.input(source);
    amp.input(source);
  }

  void _initDSP(SoundFile source) {
    fft  = new FFT(Visuals.this, FFT_BANDS);
    amp  = new Amplitude(Visuals.this);
    fft.input(source);
    amp.input(source);
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

  // Playback state and controls
  boolean isPlaying()  { return fileMode && player != null && player.isPlaying(); }

  void togglePause() {
    if (!fileMode || player == null) return;
    if (player.isPlaying()) player.pause();
    else                    player.play();
  }
}
