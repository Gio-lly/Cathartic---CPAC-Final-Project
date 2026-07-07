# ============================================================================
# emotion_smoother.py
#
# Smooths a target emotion-score dictionary over time, instead of jumping
# instantly to new values whenever a new text analysis arrives, and
# continuously emits the smoothed state to a destination.
#
# Each EmotionSmoother instance is configured by detect_emotion.py for ONE
# destination:
#   - The "visuals" instance: a UDP OSC client is passed as `client`. Every
#     frame it sends `/emotion/<name> <value>` to Processing, which uses
#     it to drive the generative visuals.
#   - The "lightning" instance: `client=None`, but a `prompt_ws_url` is
#     given. Every `prompt_interval` seconds it converts the smoothed
#     emotion values into music-generation prompts (via
#     emotions_to_prompt.emotions_to_prompts) and sends them as JSON over a
#     WebSocket to Lightning.ai, where Magenta RealTime uses them to
#     synthesize audio live.
#
# When idle (no new text for `idle_timeout` seconds), values drift slowly
# back towards a neutral state instead of cutting off abruptly.
# ============================================================================

import json
import threading
import time

import websocket

from emotions_to_prompt import emotions_to_prompts


class EmotionSmoother:

    # ------------------------------------------------------------------
    # Setup
    # ------------------------------------------------------------------
    def __init__(self, client, active_rate=2.0, idle_rate=0.1, idle_timeout=5.0,
                 prompt_ws_url=None, prompt_interval=2.0):
        """
        client: OSC client used to send smoothed values to Processing, or
                None if this instance only sends prompts to Lightning.ai.
        active_rate (float): Speed of change when a new message arrives.
        idle_rate (float): Speed of decay to neutral after timeout.
        idle_timeout (float): Seconds to wait before drifting to neutral.
        prompt_ws_url (str): WebSocket URL of the Lightning.ai endpoint, if
                              this instance should send music prompts.
        prompt_interval (float): Minimum seconds between prompt sends.
        """
        self.client = client
        self.prompt_interval = prompt_interval
        self.fps = 30               # Update rate
        self.dt = 1.0 / self.fps    # Time per frame
        self.running = True
        self.ws = None
        self.ws_url = None

        if prompt_ws_url:
            self._connect_ws(prompt_ws_url)

        # Rate configuration
        self.active_rate = active_rate
        self.idle_rate = idle_rate
        self.idle_timeout = idle_timeout

        # Smoothing state
        self.current_values = {"neutral": 1.0}
        self.target_values = {"neutral": 1.0}
        self.last_input_time = time.time()
        self.is_idle = True

        # 0.0 forces a prompt send on the very first loop iteration
        self.last_prompt_time = 0.0

        self.lock = threading.Lock()
        print("[Engine] EmotionSmoother initialized.")

    # ------------------------------------------------------------------
    # WebSocket connection (Lightning.ai link only)
    # ------------------------------------------------------------------
    def _connect_ws(self, url):
        """Kick off a background thread that connects (and retries) to `url`."""
        self.ws_url = url
        threading.Thread(target=self._ws_connect_loop, daemon=True).start()

    def _ws_connect_loop(self):
        """Block until a WebSocket connection to self.ws_url succeeds."""
        while True:
            try:
                print(f"[WS] Connecting to {self.ws_url}...")
                self.ws = websocket.create_connection(self.ws_url)
                print("[WS] Connected.")
                return
            except Exception as e:
                print(f"[WS] Connection error: {e}, retrying in 3s...")
                time.sleep(3)

    def _reconnect_ws(self):
        """Used after a send failure: wait briefly, then reconnect."""
        time.sleep(1)
        self._ws_connect_loop()

    # ------------------------------------------------------------------
    # Public API (called from detect_emotion.py)
    # ------------------------------------------------------------------
    def set_target(self, new_emotions):
        """Set the new target emotion values to smooth towards."""
        with self.lock:
            self.target_values = new_emotions
            self.last_input_time = time.time()  # Reset the idle timer

            # Ensure current_values tracks all keys we might smooth towards
            for k in self.target_values:
                if k not in self.current_values:
                    self.current_values[k] = 0.0

    def start(self):
        """Start the smoothing/send loop on a background thread."""
        threading.Thread(target=self.update_and_send, daemon=True).start()

    # ------------------------------------------------------------------
    # Internal smoothing logic
    # ------------------------------------------------------------------
    def _get_active_target_and_rate(self):
        """Return (target_dict, rate) depending on idle vs. active state."""
        time_since_input = time.time() - self.last_input_time

        if time_since_input > self.idle_timeout:
            # IDLE: drift back towards neutral
            idle_target = {k: 0.0 for k in self.current_values}
            idle_target["neutral"] = 1.0
            self.is_idle = True
            return idle_target, self.idle_rate
        else:
            # ACTIVE: move towards the latest analyzed emotion values
            self.is_idle = False
            return self.target_values, self.active_rate

    def _send_prompts(self):
        """Convert current emotion values to music prompts and send to Lightning.ai."""
        if self.ws is None:
            return

        prompts = emotions_to_prompts(self.current_values)

        if prompts:
            try:
                self.ws.send(json.dumps(prompts))
                print(f"[WS] Sent: {prompts}")
            except Exception as e:
                print(f"[WS] Send error: {e}")
                self.ws = None  # Force a reconnect on the next cycle
                threading.Thread(target=self._reconnect_ws, daemon=True).start()

    # ------------------------------------------------------------------
    # Main loop
    # ------------------------------------------------------------------
    def update_and_send(self):
        """Runs continuously at `self.fps` Hz: smooth values, send OSC + prompts."""
        while self.running:
            start_time = time.time()

            with self.lock:
                # 1. Determine where we should be heading and how fast
                target_dict, rate = self._get_active_target_and_rate()

                # 2. Step every emotion towards its target
                for emotion in list(self.current_values.keys()):
                    current = self.current_values[emotion]
                    target = target_dict.get(emotion, 0.0)  # Default to 0 for stale keys

                    diff = target - current
                    step = rate * self.dt

                    if abs(diff) < step:
                        self.current_values[emotion] = target
                    else:
                        direction = 1.0 if diff > 0 else -1.0
                        self.current_values[emotion] += step * direction

                    # 3. Send the smoothed value to Processing (visuals)
                    if self.client is not None:
                        clean_name = emotion.replace(" ", "_")
                        osc_path = f"/emotion/{clean_name}"
                        self.client.send_message(osc_path, round(self.current_values[emotion], 2))

                # 4. Send music prompts to Lightning.ai at a slower, fixed interval
                now = time.time()
                if now - self.last_prompt_time > self.prompt_interval:
                    self._send_prompts()
                    self.last_prompt_time = now

            # 5. Maintain target frame rate
            elapsed = time.time() - start_time
            time.sleep(max(0, self.dt - elapsed))
