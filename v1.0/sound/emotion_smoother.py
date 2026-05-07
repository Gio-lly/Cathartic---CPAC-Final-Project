import time
import threading
import os
import json
import websocket
import time

def cls(): os.system('cls' if os.name=='nt' else 'clear')

class EmotionSmoother:
    def __init__(self, client, active_rate=2.0, idle_rate=0.1, idle_timeout=5.0, 
                 prompt_ws_url = None, prompt_interval = 3.0):
        """
        active_rate (float): Speed of change when a new message arrives.
        idle_rate (float): Speed of decay to neutral after timeout.
        idle_timeout (float): Seconds to wait before drifting to neutral.
        """
        self.client = client
        self.prompt_interval = prompt_interval
        self.fps = 30               # Update rate
        self.dt = 1.0 / self.fps    # Time per frame
        self.running = True
        self.ws = None
        
        if prompt_ws_url:
            self._connect_ws(prompt_ws_url)

        # Configuration
        self.active_rate = active_rate
        self.idle_rate = idle_rate
        self.idle_timeout = idle_timeout
        
        # State
        self.current_values = {"neutral": 1.0}
        self.target_values = {"neutral": 1.0}
        self.last_input_time = time.time()
        self.is_idle = True

        #FORCES SENDING AT FIRST START
        self.last_prompt_time  = 0.0

        self.lock = threading.Lock()
        print("[Engine] EmotionSmoother initialized.")
    
    def _connect_ws(self, url):
        """Connessione WebSocket con riconnessione automatica."""
        self.ws_url = url
        def connect():
            while True:
                try:
                    print(f"[WS] Connessione a {url}...")
                    self.ws = websocket.create_connection(url)
                    print(f"[WS] Connesso!")
                    break
                except Exception as e:
                    print(f"[WS] Errore connessione: {e}, riprovo in 3s...")
                    time.sleep(3)
        
        threading.Thread(target=connect, daemon=True).start()

    def set_target(self, new_emotions):
        """Called by the main script when analysis is done."""
        with self.lock:
            self.target_values = new_emotions
            self.last_input_time = time.time() # Reset the idle timer
            
            # Ensure current_values tracks all keys
            for k in self.target_values:
                if k not in self.current_values:
                    self.current_values[k] = 0.0

    def _get_active_target_and_rate(self):
        """Returns the target emotion values and rate."""
        time_since_input = time.time() - self.last_input_time
        
        if time_since_input > self.idle_timeout:
            # --- IDLE MODE ---
            # Target is Neutral=1, everything else=0
            # We construct a target dict based on what we currently have
            idle_target = {k: 0.0 for k in self.current_values}
            idle_target["neutral"] = 1.0
            self.is_idle = True
            return idle_target, self.idle_rate
        else:
            # --- ACTIVE MODE ---
            self.is_idle = False
            return self.target_values, self.active_rate
    

    def _reconnect_ws(self):
        time.sleep(1)
        while True:
            try:
                print(f"[WS] Riconnessione a {self.ws_url}...")
                self.ws = websocket.create_connection(self.ws_url)
                print(f"[WS] Riconnesso!")
                break
            except Exception as e:
                print(f"[WS] Errore riconnessione: {e}, riprovo in 3s...")
                time.sleep(3)

    
    def _send_prompts(self):
        if self.ws is None:
            return
        from emotions_to_prompt import emotions_to_prompts
        prompts = emotions_to_prompts(self.current_values, top_n=3, threshold=0.1)
        if prompts:
            try:
                self.ws.send(json.dumps(prompts))
                print(f"[WS] Sent: {prompts}")
            except Exception as e:
                print(f"[WS] Send error: {e}")
                self.ws = None  # forza riconnessione al prossimo ciclo
                threading.Thread(target=self._reconnect_ws, daemon=True).start()
    

    def update_and_send(self):
        """Main Loop: Runs 30 times a second."""
        while self.running:
            start_time = time.time()
            
            with self.lock:
                # 1. Determine where we should be going and how fast
                target_dict, rate = self._get_active_target_and_rate()
                
                # 2. Update every emotion
                all_keys = list(self.current_values.keys())
                
                for emotion in all_keys:
                    current = self.current_values[emotion]
                    # If emotion is not in target_dict (e.g. from old msg), target is 0
                    target = target_dict.get(emotion, 0.0)
                    
                    diff = target - current
                    step = rate * self.dt
                    
                    if abs(diff) < step:
                        # Close enough, just snap to target
                        self.current_values[emotion] = target
                    else:
                        # Move towards target
                        direction = 1.0 if diff > 0 else -1.0
                        self.current_values[emotion] = self.current_values[emotion] + step * direction


                    # 3. Send OSC
                    # Only send if value is significant (> 0.001) or if it's the target
                    if self.client is not None:
                        val = self.current_values[emotion]


                        #if val > 0.001 or (target > 0.001 and abs(diff) > 0.001):
                        clean_name = emotion.replace(" ", "_")
                        osc_path = f"/emotion/{clean_name}"
                        self.client.send_message(osc_path, round(val,2))
                now = time.time()
                if now - self.last_prompt_time > self.prompt_interval:
                    self._send_prompts()
                    self.last_prompt_time = now

                # 4. Display Current State in Console
                # We will overwrite the previous block of text
                # Commento questo perchè ora si possono vedere in devMode su processing
                    """
                    # A. Move cursor UP to erase previous print
                    cls()

                    # B. Prepare new lines to print
                    lines = []
                    status_str = "IDLE (Drifting)" if self.is_idle else "ACTIVE"
                    lines.append(f"--- SYSTEM STATUS: {status_str} ---")          

                    sorted_items = sorted(self.current_values.items(), key=lambda x: x[1], reverse=True)
                    
                    # Display top 8 active emotions (to keep the list stable)
                    count = 0
                    for name, val in sorted_items:
                        if val > 0.01: # Only show significant emotions
                            # Create ASCII Bar: [████------]
                            bar_len = int(val * 20)
                            bar = "█" * bar_len + "-" * (20 - bar_len)
                            
                            lines.append(f"{name:<15} : [{bar}] {val:.3f}")
                            count += 1
                            if count >= 8: break # Limit height
                    
                    # C. Print the block
                    output_block = "\n".join(lines)
                    print(output_block)
                    
                    # D. Save line count for the next loop
                    last_line_count = len(lines)
                    """

                    

            # 4. Maintain Frame Rate
            elapsed = time.time() - start_time
            sleep_time = max(0, self.dt - elapsed)
            time.sleep(sleep_time)

    def start(self):
        t = threading.Thread(target=self.update_and_send, daemon=True)
        t.start()