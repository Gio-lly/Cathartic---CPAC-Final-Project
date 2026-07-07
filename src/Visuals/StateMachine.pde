// StateMachine.pde  |  Finite-state machine and shared state logic
// Manages application states, transitions, lifecycle events, and input delegation

class StateMachine {

  BaseState[] states;
  int         current = -1;

  // State initialization
  StateMachine() {
    states = new BaseState[Config.NUM_STATES];
    states[Config.STATE_DISCLAIMER] = new DisclaimerState();
    states[Config.STATE_INPUT]      = new InputState();
    states[Config.STATE_PARTICLES]  = new ParticlesState();
    states[Config.STATE_THANKS]     = new ThanksState();
  }

  // State transitions
  void changeState(int nextState) {
    if (current >= 0 && states[current] != null) {
      states[current].onExit();
    }
    println("[FSM] " + stateLabel(current) + " → " + stateLabel(nextState));
    current = nextState;
    states[current].onEnter();
  }

  // Principal loop
  void update() {
    if (current >= 0) states[current].update();
  }

  void render() {
    if (current >= 0) states[current].render();
  }

  // Input forwarding
  void handleKey() {
    if (current >= 0) states[current].handleKey();
  }

  void handleKeyReleased() {
    if (current >= 0) states[current].handleKeyReleased();
  }

  // Developer state navigation
  void nextState() {
    int next = (current + 1) % Config.NUM_STATES;
    changeState(next);
  }

  void prevState() {
    int prev = (current - 1 + Config.NUM_STATES) % Config.NUM_STATES;
    changeState(prev);
  }

  // State information
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

//  BaseState | Shared base class for all application states

abstract class BaseState {
  int     stateStartTime = 0;   // Time at which the current state was entered, in ms
  
  // Lifecycle hooks overridden by individual states when needed
  void onEnter()          { stateStartTime = millis(); }
  void onExit()           {}
  void update()           {}
  void render()           {}
  void handleKey()        {}
  void handleKeyReleased(){}

  // Returns the time elapsed since the state was entered
  int elapsed() { return millis() - stateStartTime; }

  // Returns normalized progress over the specified duration
  float progress(int duration) {
    return constrain((float) elapsed() / duration, 0.0, 1.0);
  }
}
