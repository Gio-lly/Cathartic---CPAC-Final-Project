# ============================================================================
# detect_emotion.py
# 
# RUN THIS SCRIPT TO START THE EMOTION DETECTION.
# 
# Listens over OSC for incoming text prompts from Processing (OSC_RECV_PORT), 
# classifies their emotional content with the GoEmotions model, and forwards 
# the result to two downstream consumers via EmotionSmoother instances (see emotion_smoother.py):
#
#   1. Processing (visuals) — smoothed per-emotion float values are sent as
#      OSC messages (`/emotion/<name> <value>`) on OSC_SEND_PORT, driving
#      the visuals in real time.
#   2. Lightning.ai (audio) — emotion values are converted into weighted
#      music-generation prompts (emotions_to_prompt.py) and sent as JSON
#      over a WebSocket to a Lightning.ai GPU instance running Magenta
#      RealTime, which synthesizes audio live from those prompts.
#
# Receives text over OSC on OSC_RECV_PORT (from Processing).
# ============================================================================

# ----------------------------------------------------------------------------
# Imports
# ----------------------------------------------------------------------------
import json

from pythonosc import dispatcher, osc_server, udp_client
from transformers import pipeline

from emotion_smoother import EmotionSmoother

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
LIGHTNING_WS_URL = "wss://9002-01kp66x818nvqtvyvcf9bkr5ze.cloudspaces.litng.ai" #SUBSIDIZE WITH YOUR OWN INSTANCE URL

OSC_IP = "127.0.0.1"
OSC_SEND_PORT = 9000   # Smoothed emotion values -> Processing (visuals)
OSC_RECV_PORT = 12001  # Incoming text prompts from Processing

# One full emotion pulse plays out as three phases, back to back:
#   ascent (rises to the target) -> hold (sits idle at the peak) -> descent
#   (fades back to neutral). The phase durations below are the source of
#   truth; rates and IDLE_TIMEOUT are derived from them.
ASCENT_DURATION_S = 20.0   # how fast a new emotion takes over
HOLD_DURATION_S = 60.0     # how long it sits at the peak before fading
DESCENT_DURATION_S = 40.0  # how slowly it fades back to neutral once idle (2x ascent)
PARTICLES_DURATION_S = ASCENT_DURATION_S + HOLD_DURATION_S + DESCENT_DURATION_S  # 60s total

# Speed of change (units per second): value range is 0.0-1.0, so rate =
# 1 / duration to cross the full range in that many seconds.
ASCENT_RATE = 1.0 / ASCENT_DURATION_S
DESCENT_RATE = 1.0 / DESCENT_DURATION_S
# IDLE_TIMEOUT counts from the same instant ascent starts, so it must cover
# both the ascent and the hold for the hold to actually happen before descent.
IDLE_TIMEOUT = ASCENT_DURATION_S + HOLD_DURATION_S

MODEL_NAME = "SamLowe/roberta-base-go_emotions"

# ----------------------------------------------------------------------------
# Model loading
# ----------------------------------------------------------------------------
print("Loading model...")
emotion_classifier = pipeline(
    "text-classification",
    model=MODEL_NAME,
    return_all_scores=True,
    top_k=None
)
print("Model loaded.")

# ----------------------------------------------------------------------------
# Output destinations
#
# Two EmotionSmoother instances share the same emotion classification, but
# smooth and forward it to different consumers:
#   - `smoother`           -> OSC to Processing (visuals)
#   - `smoother_lightning` -> WebSocket prompts to Lightning.ai (audio)
# ----------------------------------------------------------------------------
osc_sender = udp_client.SimpleUDPClient(OSC_IP, OSC_SEND_PORT)

# Sent once on startup, for convenience: this way Config.PARTICLES_DURATION
# in Processing doesn't have to be kept in sync by hand whenever the phase
# durations above change.
osc_sender.send_message("/config/particles_duration", PARTICLES_DURATION_S * 1000)

smoother = EmotionSmoother(
    osc_sender,
    active_rate=ASCENT_RATE,
    idle_rate=DESCENT_RATE,
    idle_timeout=IDLE_TIMEOUT
)
smoother.start()

smoother_lightning = EmotionSmoother(
    client=None,
    active_rate=ASCENT_RATE,
    idle_rate=DESCENT_RATE,
    idle_timeout=IDLE_TIMEOUT,
    prompt_ws_url=LIGHTNING_WS_URL,
    prompt_interval= 1.5  # Just under Magenta's 2s chunk length, so each new chunk can start with a fresh prompt
)
smoother_lightning.start()

# ----------------------------------------------------------------------------
# Emotion analysis
# ----------------------------------------------------------------------------
def analyze_emotions(text):
    """Run the GoEmotions classifier on `text` and return {label: score}."""
    scores = emotion_classifier(text)[0]
    scores = {d["label"]: round(float(d["score"]), 2) for d in scores}
    print(f"         > Rounded Scores: {scores}")
    return scores

# ----------------------------------------------------------------------------
# OSC message handler
# ----------------------------------------------------------------------------
def osc_text_handler(*args):
    """Handle an incoming `/text` OSC message: classify and forward it."""
    text = args[1]
    print(f"[Server] Received: '{text}'")
    new_emotions = analyze_emotions(text)

    smoother.set_target(new_emotions)
    smoother_lightning.set_target(new_emotions)

    # Tell Lightning.ai to flush/refresh immediately on new input, instead
    # of waiting for the next periodic prompt_interval send.
    if smoother_lightning.ws:
        try:
            smoother_lightning.ws.send(json.dumps({"__flush__": True}))
            print("[FLUSH] Signal sent to Lightning.")
        except Exception as e:
            print(f"[FLUSH] Failed to send flush signal: {e}")

    top = sorted(new_emotions.items(), key=lambda x: x[1], reverse=True)[:2]
    print(f"         > Targets: {top}")

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
if __name__ == "__main__":
    disp = dispatcher.Dispatcher()
    disp.map("/text", osc_text_handler)
    server = osc_server.ThreadingOSCUDPServer((OSC_IP, OSC_RECV_PORT), disp)

    print(f"Server listening on {OSC_RECV_PORT}. Sending visuals OSC on {OSC_SEND_PORT}, "
          f"audio prompts via WebSocket to {LIGHTNING_WS_URL}")
    server.serve_forever()
