# 1. Import required packages
import time
import threading
import random
from transformers import pipeline
import torch
import pandas as pd
from pythonosc import dispatcher
from pythonosc import osc_server
from pythonosc import udp_client

from emotion_smoother import EmotionSmoother

# Configuration
OSC_IP = "127.0.0.1"
OSC_SEND_PORT = 9000  # Sending smoothed data out
OSC_SEND_PORT_ABLETON = 9001  
OSC_RECV_PORT = 12001  # Listening for text

# Speed of change (units per second)
# Since values are 0.0 to 1.0:
# 2.0 means it can go 0->1 in 0.5 seconds (Fast)
# 0.2 means it can go 1->0 in 5.0 seconds (Slow)
ASCENT_RATE = 0.20  
DESCENT_RATE = 0.05
IDLE_TIMEOUT = 20.0    # Seconds to wait before drifting to neutral  
FRAME_RATE = 30     # How many times per second we update/send OSC

# 2. Load the pre-trained GoEmotions model
print("Loading model...")
MODEL_NAME = "SamLowe/roberta-base-go_emotions"

emotion_classifier = pipeline(
    "text-classification",
    model=MODEL_NAME,
    return_all_scores=True,
    top_k=None
)
print("Model loaded.")

# Setup OSC sender for EmotionSmoother
osc_sender = udp_client.SimpleUDPClient(OSC_IP, OSC_SEND_PORT)
osc_sender_ableton = udp_client.SimpleUDPClient(OSC_IP, OSC_SEND_PORT_ABLETON)

# Rate Configuration
smoother = EmotionSmoother(
    osc_sender, 
    active_rate=ASCENT_RATE,      # Fast change when message arrives (0->1 in 0.5s)
    idle_rate=DESCENT_RATE,       # Very slow drift to neutral (1->0 in 20s)
    idle_timeout=IDLE_TIMEOUT     # Wait 10 seconds before starting drift (For testing)
)
smoother.start()

smoother_ableton = EmotionSmoother(
    osc_sender_ableton, 
    active_rate=ASCENT_RATE,      # Fast change when message arrives (0->1 in 0.5s)
    idle_rate=DESCENT_RATE,       # Very slow drift to neutral (1->0 in 20s)
    idle_timeout=IDLE_TIMEOUT     # Wait 10 seconds before starting drift (For testing)
)
smoother_ableton.start()

# Emotion Analysis Function
def analyze_emotions(text):
    scores = emotion_classifier(text)[0]
    return {d["label"]: float(d["score"]) for d in scores}

# OSC Message Handler
def osc_text_handler(*args):
    text = args[1]
    print(f"[Server] Received: '{text}'")
    new_emotions = analyze_emotions(text)
    
    # Send to smoother
    smoother.set_target(new_emotions)
    smoother_ableton.set_target(new_emotions)
    top = sorted(new_emotions.items(), key=lambda x: x[1], reverse=True)[:2]
    print(f"         > Targets: {top}")

# 4. Example usage
if __name__ == "__main__":
    disp = dispatcher.Dispatcher()
    disp.map("/text", osc_text_handler)
    server = osc_server.ThreadingOSCUDPServer((OSC_IP, OSC_RECV_PORT), disp)
    
    print(f"Server listening on {OSC_RECV_PORT}. Sending to {OSC_SEND_PORT} and {OSC_SEND_PORT_ABLETON}")
    server.serve_forever()
