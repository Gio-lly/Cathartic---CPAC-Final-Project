// =============================================================
//  AudioManager.pde  |  Wrapper Minim — FFT + ampiezza
// =============================================================
class AudioManager {
  Minim         minim;
  AudioInput    input;
  AudioPlayer   player;
  FFT           fft;
  BeatDetect    beat;
  boolean       active      = false;
  boolean       fileMode    = false;   // true = file audio, false = microfono
  float         smoothedAmplitude = 0;
  float[]       fftValues;

  static final int   FFT_BANDS    = 512;
  static final float SMOOTH       = 0.15;
  static final String AUDIO_FILE  = "Universel.mp3";

  // ── Costruttore ──────────────────────────────────────────
  AudioManager() {
    minim = new Minim(Visuals.this);
    println("[AudioManager] Minim inizializzato");
  }

  // ── Avvia microfono ───────────────────────────────────────
  void start() {
    startMic();
  }

  void startMic() {
    if (active) stop();
    fileMode = false;
    try {
      input = minim.getLineIn(Minim.STEREO, 1024);
      _initDSP(input.bufferSize(), input.sampleRate());
      active = true;
      println("[AudioManager] Microfono aperto");
    } catch (Exception e) {
      println("[AudioManager] ERRORE microfono: " + e.getMessage());
      active = false;
    }
  }

  // ── Avvia file audio ──────────────────────────────────────
  void startFile() {
    if (active) stop();
    fileMode = true;
    try {
      player = minim.loadFile(AUDIO_FILE, 1024);
      if (player == null) {
        println("[AudioManager] ERRORE: file " + AUDIO_FILE + " non trovato nella cartella data/");
        active = false;
        return;
      }
      player.loop();   // loop continuo; usa player.play() per una sola riproduzione
      _initDSP(player.bufferSize(), player.sampleRate());
      active = true;
      println("[AudioManager] File audio avviato: " + AUDIO_FILE);
    } catch (Exception e) {
      println("[AudioManager] ERRORE file audio: " + e.getMessage());
      active = false;
    }
  }

  // ── Inizializza FFT e BeatDetect ──────────────────────────
  void _initDSP(int bufSize, float sampleRate) {
    fft  = new FFT(bufSize, sampleRate);
    beat = new BeatDetect(bufSize, sampleRate);
    beat.setSensitivity(100);
    fftValues = new float[FFT_BANDS];
  }

  // ── Chiude tutto ──────────────────────────────────────────
  void stop() {
    if (input  != null) { input.close();  input  = null; }
    if (player != null) { player.close(); player = null; }
    active   = false;
    fileMode = false;
    println("[AudioManager] Audio chiuso");
  }

  // ── Buffer corrente (microfono o file) ────────────────────
  AudioBuffer _mix() {
    if (fileMode && player != null) return player.mix;
    if (!fileMode && input  != null) return input.mix;
    return null;
  }

  // ── Ampiezza RMS con smoothing ────────────────────────────
  float getAmplitude() {
    AudioBuffer mix = _mix();
    if (!active || mix == null) return 0;
    float raw = mix.level();
    smoothedAmplitude += (raw - smoothedAmplitude) * SMOOTH;
    return smoothedAmplitude;
  }

  // ── Valori FFT normalizzati ───────────────────────────────
  float[] getFFT() {
    AudioBuffer mix = _mix();
    if (!active || mix == null) return fftValues;
    fft.forward(mix);
    for (int i = 0; i < FFT_BANDS; i++) {
      float band = fft.getBand(i);
      fftValues[i] += (band - fftValues[i]) * SMOOTH;
    }
    return fftValues;
  }

  // ── Beat detection ────────────────────────────────────────
  boolean isKick() {
    AudioBuffer mix = _mix();
    if (!active || beat == null || mix == null) return false;
    beat.detect(mix);
    return beat.isKick();
  }

  boolean isSnare() {
    AudioBuffer mix = _mix();
    if (!active || beat == null || mix == null) return false;
    beat.detect(mix);
    return beat.isSnare();
  }

  // ── Utilità file mode ─────────────────────────────────────
  boolean isFileMode()  { return fileMode; }
  boolean isPlaying()   { return fileMode && player != null && player.isPlaying(); }
  void   togglePause() {
    if (!fileMode || player == null) return;
    if (player.isPlaying()) player.pause();
    else                    player.play();
  }
}
