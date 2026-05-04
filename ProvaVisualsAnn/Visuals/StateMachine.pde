// =============================================================
//  StateMachine.pde  |  FSM — macchina a stati finiti
// =============================================================

class StateMachine {

  BaseState[] states;
  int         current = -1;

  // ── Costruttore ──────────────────────────────────────────
  StateMachine() {
    states = new BaseState[Config.NUM_STATES];
    states[Config.STATE_DISCLAIMER] = new DisclaimerState();
    states[Config.STATE_INPUT]      = new InputState();
    states[Config.STATE_PARTICLES]  = new ParticlesState();
    states[Config.STATE_THANKS]     = new ThanksState();
  }

  // ── Cambia stato ─────────────────────────────────────────
  void changeState(int nextState) {
    if (current >= 0 && states[current] != null) {
      states[current].onExit();
    }
    println("[FSM] " + stateLabel(current) + " → " + stateLabel(nextState));
    current = nextState;
    states[current].onEnter();
  }

  // ── Loop principale ──────────────────────────────────────
  void update() {
    if (current >= 0) states[current].update();
  }

  void render() {
    if (current >= 0) states[current].render();
  }

  // ── Input forwarding ────────────────────────────────────
  void handleKey() {
    if (current >= 0) states[current].handleKey();
  }

  void handleKeyReleased() {
    if (current >= 0) states[current].handleKeyReleased();
  }

  // ── Dev: navigazione manuale ─────────────────────────────
  void nextState() {
    int next = (current + 1) % Config.NUM_STATES;
    changeState(next);
  }

  void prevState() {
    int prev = (current - 1 + Config.NUM_STATES) % Config.NUM_STATES;
    changeState(prev);
  }

  // ── Helper label ─────────────────────────────────────────
  String stateLabel(int s) {
    switch (s) {
      case Config.STATE_DISCLAIMER: return "DISCLAIMER";
      case Config.STATE_INPUT:      return "INPUT";
      case Config.STATE_PARTICLES:  return "PARTICLES";
      case Config.STATE_THANKS:     return "THANKS";
      default:                      return "NONE";
    }
  }

  int getCurrent() { return current; }
}

// =============================================================
//  BaseState — interfaccia comune per tutti gli stati
// =============================================================
abstract class BaseState {
  int     stateStartTime = 0;   // millis() all'entrata nello stato

  void onEnter()          { stateStartTime = millis(); }
  void onExit()           {}
  void update()           {}
  void render()           {}
  void handleKey()        {}
  void handleKeyReleased(){}

  // Tempo trascorso dall'entrata nello stato
  int elapsed() { return millis() - stateStartTime; }

  // Progresso 0.0→1.0 in base a una durata
  float progress(int duration) {
    return constrain((float) elapsed() / duration, 0.0, 1.0);
  }
}
