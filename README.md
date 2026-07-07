# Cathartic

> An interactive audiovisual installation where what you feel becomes what you hear and see.

*CPAC — Creative Programming and Computing, Final Project. Music Engineering.*

## Index
* [The Project](#the-project)
* [How it works](#how-it-works-technology)
* [Computational contstraints](#a-note-on-compute-magenta-v1-vs-v2-and-local-generation)
* [Installation and Setup](#installation--setup)
    * [Magenta Host](#1-magenta-host--run-the-setup-notebook-on-lightning-a100)
    * [Local Emotion Detection](#2-local-python-environment-emotion-detection)
    * [Audio Routing](#3-audio-routing--so-processing-can-analyze-the-music)
* [Running the full installation](#running-the-full-installation)
* [Troubleshooting](#troubleshooting)
* [Project Structure](#project-structure)
* [Credits](#credits)

---

## The Project

**Cathartic** is an interactive installation about externalizing what we keep inside. A visitor approaches a screen, reads a short disclaimer, and is invited to **type how they feel — or to confess a secret**. The text is never saved or shown to anyone; it exists only for the few seconds it takes the system to read it. In that moment it stops being words and becomes atmosphere.

The typed text is analyzed in real time for emotional content. That emotion drives two things at once:

- **Generative ambient music** that shifts in mood as the detected emotion changes.
- **A reactive particle field**, inspired by Chladni resonance patterns, whose colours and visual character reflect the detected emotions, while its motion breathes, swirls, and reorganizes itself in response to the generated music.

The result is an interconnected relationship between the visitor's inner state, sound, and image: you write a feeling, the room fills with a sound that matches it, and the visuals dance to that sound. The act of putting an emotion into words — and then watching it dissolve into light and music — is the cathartic gesture the piece is named after.

The experience runs as a simple state machine:

```
Disclaimer  →  Input  →  Particles  →  Thanks  →  (back to Disclaimer)
```

---

## Privacy and Data Handling

Cathartic is designed as an ephemeral experience. The visitor's text is used only while the audiovisual interaction is being generated and is not intentionally stored in a file, database, or user profile. The message is transmitted locally from Processing to the Python emotion-detection pipeline, where it is processed in memory. Only the resulting emotion values and musical prompt weights are passed to the other components of the system.

---

## How It Works (Technology)

Cathartic is a distributed system spanning **three environments** that talk to each other in real time.

```
┌──────────────────────┐     OSC: user text      ┌──────────────────────┐
│   PROCESSING (local) │ ──────────────────────► │    PYTHON (local)    │
│                      │ ◄────────────────────── │                      │
│  • State machine     │   OSC: emotion values   │  • OSC receiver      │
│  • Particle visuals  │                         │  • GoEmotions model  │
│  • Audio analysis    │                         │  • EmotionSmoother   │
│    (FFT / amplitude) │                         │  • emotion→prompt    │
└──────────▲───────────┘                         └──────────┬───────────┘
           │                                                │ WebSocket
           │ audio (virtual cable)                          │ (prompts, :9002)
           │                                                ▼
   ┌───────┴──────────────────────────────────────────────────────┐
   │                  MAGENTA HOST (remote GPU — Lightning)       │
   │   • Magenta RT, system.MagentaRT(tag="large", lazy=False)    │
   │   • Gradio control panel (sampling params, text/audio prompt)│
   │   • WebSocket server :9002 (receives weighted prompts)       │
   │   • WebSocket server :9004 (broadcasts raw float32 PCM       │
   │     @ 48 kHz)                                                │
   └──────────────────────────────────────────────────────────────┘
           │ audio (WebSocket :9004)
           ▼
   Browser AudioWorklet player ──► speakers
               │
               └──► virtual audio cable ──► Processing
```

![Architecture](images/Cathartic%20architecture.png)

### Processing (local) — interface, visuals, audio analysis
Processing manages the interactive and visual side of the installation. Built with the P2D / OpenGL renderer, it controls the complete interaction flow through a finite-state machine, from the initial disclaimer and text input to the audiovisual experience and final reset. 

When the visitor submits a message, Processing sends the text to the local Python application via OSC. The same text is rasterized into pixels and used to define the initial distribution of the particles, allowing the written message to become the starting shape of the visualization. The particle system is inspired by Chladni resonance patterns and is influenced by two main data sources:

- Emotion values received from Python, which shape the colour palette, visual energy, and broader character of the particle field.
- Audio features extracted from the generated music, which control its immediate movement and response over time.

The audio returning from the Magenta host is analyzed in real time using the Processing Sound library. Amplitude tracking, FFT frequency bands, and transient detection are used to make the particles expand, rotate, vibrate, and reorganize themselves in response to the music.

A dedicated DevMode overlay provides live diagnostic information, including the current state, frame rate, audio amplitude, frequency-band activity, and incoming emotion values.

### Python (local) — emotion detection
The local Python pipeline connects the visitor’s text to both the music-generation system and the Processing visuals. It is organized into three main scripts:

- `detect_emotion.py` — runs an **OSC server** that receives the visitor's text from Processing, and runs the **GoEmotions** model.
- `emotion_smoother.py` — the `EmotionSmoother` class, which gradually interpolates the emotion vector over time, preventing abrupt changes in both the music and the visuals.
- `emotions_to_prompt.py` — maps the 28 GoEmotions labels to descriptive **musical prompt strings** (`EMOTION_PROMPTS`).

Emotion is detected with **`SamLowe/roberta-base-go_emotions`**, a multi-label text-classification model based on RoBERTa and accessed through Hugging Face Transformers. 
Instead of assigning the text to a single category, the model returns a score for each emotion, allowing multiple emotional qualities to coexist in the same input.
The resulting weighted prompt dictionary is sent to the Magenta host over a **WebSocket** (UDP/OSC can't reach a remote GPU host like Lightning — see below).

### Magenta host (remote GPU) — music generation
A pair of notebooks running **[Magenta RT](https://github.com/magenta/magenta-realtime)** (Google's open-weights real-time music model). The model is instantiated as `system.MagentaRT(tag="large", lazy=False)` — the **large** open-weights model — and generates **stereo float32 audio at 48 kHz** in short chunks, steered live by the weighted prompts.

- **Gradio** is used **only** as a control panel: text/audio prompts and the sampling parameters (temperature, top-k, guidance). The audio does **not** travel through Gradio.
- The audio is streamed separately as **raw float32 PCM over a WebSocket** into a **browser AudioWorklet** ring buffer for gapless playback.

Two WebSocket servers run on the host:

- **`:9002`** — receives weighted prompts from local Python.
- **`:9004`** — broadcasts generated audio to the browser AudioWorklet.

### Communication summary

| Link | Transport | Port | Carries |
|---|---|---|---|
| Processing → Python (local) | **OSC / UDP** | `OSC_RECV_PORT` *(see note)* | visitor's text |
| Python (local) → Processing | **OSC / UDP** | Processing OSC input port | smoothed emotion scores |
| Python (local) → Magenta host | **WebSocket** | `9002` | weighted emotion prompts |
| Magenta host → Browser | **WebSocket** | `9004` | raw float32 PCM @ 48 kHz |
| Browser → Processing | **virtual audio cable** | — | audio for analysis |

> **Note on the OSC port:** the local OSC port is the `OSC_RECV_PORT` constant in `detect_emotion.py`. It **must match** the port Processing sends to in `Osc.pde`. Confirm the two values are identical before running.

> **Why WebSocket and not OSC to the host?** A remote GPU host such as Lightning AI blocks incoming UDP, so OSC (which is UDP-based) never arrives. WebSocket runs over HTTP/WSS, which is exposed cleanly. OSC is therefore used **only** for the local Processing ↔ Python hop.

### Tech stack at a glance

- **Processing** — P2D renderer, Sound library (JSyn `AudioIn`, `Amplitude`, `FFT`)
- **Python** — `transformers` + `torch` (GoEmotions), `python-osc`, `websocket-client`
- **Magenta host** — Magenta RT (large), JAX/CUDA, Gradio, `websockets`, `nest_asyncio`
- **Browser** — Web Audio API, AudioWorklet ring buffer
- **Audio routing** — VoiceMeeter Banana + VB-Audio Virtual Cable (Windows) / BlackHole (macOS)

---

## A Note on Compute: Magenta v1 vs v2 (and Local Generation)

This project runs **Magenta RT v1**, the JAX/GPU version of the model. **v1 is computationally heavy** — the `tag="large"` model needs an **NVIDIA A100 or better** to generate audio in real time. Because few machines have that kind of GPU on hand, we host the model **remotely on a Lightning AI GPU Studio**.

**Lightning is not strictly required** — any environment with an A100-class GPU and the dependencies below will work. Lightning is simply a convenient way to rent that hardware and expose the WebSocket ports.

Recently, Google released **[Magenta RealTime 2](https://github.com/magenta/magenta-realtime)**, an updated open-weights model that **can run locally in real time** — notably on **Apple Silicon Macs** via its MLX backend (48 kHz stereo, ~200 ms control latency) — without a remote GPU. **A future release of Cathartic may move music generation fully local using v2**, which would remove the need for a remote host, port exposure, and (potentially) even the virtual-cable audio routing, collapsing the whole pipeline onto a single machine.

For now, the setup below targets **v1 on a remote GPU**.

---

## Installation & Setup

You'll set up three things, in this order:

1. The **Magenta host** (music generation) on a GPU machine — via the `setup` notebook — plus **port exposure**
2. The **local Python environment** (emotion detection)
3. **Audio routing** (VoiceMeeter / BlackHole) so Processing can "hear" the generated music

### Prerequisites

- **Processing 4.x** with the **Sound** library installed (Sketch → Import Library → Add Library → "Sound")
- **Python 3.12** (locally)
- A **GPU machine with an NVIDIA A100 or better** for Magenta RT v1 — e.g. a **Lightning AI** GPU Studio
- **Windows:** [VB-Audio Virtual Cable](https://vb-audio.com/Cable/) + [VoiceMeeter Banana](https://vb-audio.com/Voicemeeter/banana.htm)
  **macOS:** [BlackHole 2ch](https://existential.audio/blackhole/)

---

### 1. Magenta host — run the `setup` notebook (on Lightning, A100+)

The repo ships a dedicated **`setup` notebook** (`setup.ipynb`) that builds the exact environment the `inference` notebook needs. Start a **GPU Studio (A100 or better)** on Lightning, open the setup notebook, and work through it top to bottom.

**1.1 — System Python 3.12** *(notebook cell)*
Installs Python 3.12 from the deadsnakes PPA (the version Magenta RT / JAX are tested against):
```bash
sudo apt update
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt install python3.12 python3.12-venv python3.12-dev -y
```

**1.2 — Clone Magenta RT** *(notebook cell)*
```bash
git clone https://github.com/magenta/magenta-realtime.git
```

**1.3 — Build the isolated venv and install Magenta RT** *(run in the TERMINAL, not a Python cell)*
Lightning's bundled conda env ships conflicting `jax` / `flax` / `numpy` versions, so we install Magenta into a clean, isolated venv (`~/magenta_venv`) where we control every version. Paths below are Lightning's `/teamspace/...` layout — adjust if you run elsewhere.

```bash
# Clean venv with python3.12
python3.12 -m venv ~/magenta_venv
source ~/magenta_venv/bin/activate

# t5x is NOT on PyPI — install it from the clone, BEFORE magenta-rt
cd /teamspace/studios/this_studio/magenta-realtime/t5x
~/magenta_venv/bin/pip install '.[gpu]'
cd ..

# Magenta RT (GPU) + tf2jax
~/magenta_venv/bin/pip install -e '/teamspace/studios/this_studio/magenta-realtime[gpu]'
~/magenta_venv/bin/pip install tf2jax==0.3.8

# Pin the working version combination (jax 0.9.2 + numpy 2.x + flax 0.12.6)
~/magenta_venv/bin/pip install \
  'jax[cuda12]==0.9.2' \
  'numpy>=2' \
  'flax==0.12.6' \
  'orbax-checkpoint==0.11.33' \
  'optax==0.2.8'
~/magenta_venv/bin/pip install 'chex>=0.1.86'

# Patch seqio: removes its tensorflow import (which broke under numpy 2.x)
patch /teamspace/studios/this_studio/magenta_venv/lib/python3.12/site-packages/seqio/vocabularies.py \
  < /teamspace/studios/this_studio/magenta-realtime/patch/seqio_vocabularies.py.patch

# Verify
~/magenta_venv/bin/python -c "import jax; import flax; import seqio; print('dependencies OK')"
~/magenta_venv/bin/python -c "from magenta_rt import system; print('magenta_rt OK')"
```

**1.4 — Inference & audio-streaming packages** *(notebook cell)*
On top of `magenta-rt`:
```bash
pip install ipywidgets        # Gradio widgets render correctly in Jupyter
pip install nest_asyncio      # let asyncio loops coexist with Jupyter's
pip install gradio            # control panel only (prompts + sampling sliders)
pip install "uvicorn<0.30"    # ASGI server Gradio runs on (newer versions break here)
pip install websockets        # the real-time audio + prompt WebSocket servers
conda install -y -c conda-forge ffmpeg   # decode mp3/ogg audio prompts via librosa/soundfile
```

**1.5 — Run the `inference` notebook against `magenta_venv`.**
Make sure the inference notebook uses the **`magenta_venv`** environment. Its **very first cell**, before any other import, must neutralize Lightning's default `uvloop` (otherwise you get `uvloop` / `nest_asyncio` errors and ports that "won't free"):
```python
import asyncio
asyncio.set_event_loop_policy(asyncio.DefaultEventLoopPolicy())
```
If anything misbehaves, **Kernel → Restart** and re-run from this cell.

**1.6 — Expose the ports.**
In the Lightning Studio, open the **Ports** panel and add **`9002`** (prompts) and **`9004`** (audio) as public ports. Lightning gives you a public URL per port, like:
```
https://<studio-id>-9002.lightning.ai   →  wss://<studio-id>-9002.lightning.ai
https://<studio-id>-9004.lightning.ai   →  wss://<studio-id>-9004.lightning.ai
```
- Put the **:9002** `wss://` URL into `LIGHTNING_WS_URL` in local `detect_emotion.py` (step 2).
- Put the **:9004** `wss://` URL into the browser audio player.

When the inference notebook is running you should see both servers come up:
```
[WS] Listening on :9002
[Audio WS] Listening on :9004
```
Open the browser player (the page the notebook serves), start generation, and confirm the audio WebSocket connects in the browser console (F12).

---
### 2. Local Python environment (emotion detection)
 
From the repository root:
 
```bash
# Create and activate a virtual environment (Python 3.12)
python3.12 -m venv .venv
 
# Windows
.venv\Scripts\activate
# macOS / Linux
source .venv/bin/activate
 
# Upgrade pip, then install the pinned dependencies from requirements.txt
pip install --upgrade pip
pip install -r requirements.txt
```
 
`requirements.txt` was generated with `pip freeze`, so it pins the exact versions used during development (`transformers`, `torch`, `python-osc`, `websocket-client`, `numpy`, and their transitive dependencies). Installing from it guarantees you get the same working set rather than whatever latest versions resolve to.
 
> The first run downloads the `SamLowe/roberta-base-go_emotions` weights from HuggingFace (a few hundred MB). Be online the first time.
 
> If you later add a dependency, regenerate the lockfile with `pip freeze > requirements.txt` so it stays in sync.
 
Before launching, open `sound/detect_emotion.py` and check the configuration block:
 
- `OSC_RECV_PORT` — must match the port Processing sends to in `Osc.pde`.
- The OSC server should bind to `"0.0.0.0"` (all interfaces), **not** `127.0.0.1`, otherwise Windows raises `WinError 10049`:
```python
  server = osc_server.ThreadingOSCUDPServer(("0.0.0.0", OSC_RECV_PORT), disp)
```
- `LIGHTNING_WS_URL` — the **:9002** Lightning WebSocket URL from step 1.6.
Run it:
```bash
python sound/detect_emotion.py
```
You should see `Model loaded.` and `EmotionSmoother initialized.`
 
---

### 3. Processing environment — interface and visuals

Install **Processing 4** and open the sketch located in the `processing/` folder.

From **Sketch → Import Library → Manage Libraries**, install:

* **Sound** — used for audio input, amplitude analysis, and FFT.
* **oscP5** — used for OSC communication between Processing and the local Python pipeline.

Before running the sketch, check the following configuration:

1. Open `Osc.pde` and verify that the OSC port used to send the visitor's text matches `OSC_RECV_PORT` in `sound/detect_emotion.py`.

2. Verify that the port used by Processing to receive emotion values matches the OSC output port configured in the Python pipeline.

3. List the available audio devices by temporarily adding:

   ```java
   Sound.list();
   ```

   Run the sketch once and check the device indices printed in the Processing console.

4. Set the virtual audio input used by the installation wherever `inputDevice(...)` is configured:

   ```java
   Sound sound = new Sound(this);
   sound.inputDevice(AUDIO_INPUT_INDEX);
   ```

   Replace `AUDIO_INPUT_INDEX` with the index corresponding to:

   * `CABLE Output` on Windows;

   * `BlackHole 2ch` on macOS.

   > Audio device indices are machine-specific. Always check them again when running the installation on a different computer.

5. Run the main Processing sketch. The application should open in the **Disclaimer** state.

Use the `DevMode` overlay to verify that:

* the installation moves correctly between states;
* OSC emotion values are being received;
* the `Audio amp:` value reacts when music is playing;
* the frame rate remains stable.

If the sketch opens correctly but `Audio amp:` remains at `0.000`, continue with the audio-routing configuration in the following section.

---

### 4. Audio routing — so Processing can analyze the music

The music is generated remotely and played in your **browser**. Processing needs to *analyze* that same audio (for the FFT-driven particles) **while you still hear it**. A virtual audio device duplicates the browser's output into an input that Processing can read.

**Align everything to 48 kHz** (Magenta RT outputs 48 kHz; matching sample rates avoids glitches and dead readouts).

#### Windows — VoiceMeeter Banana + VB-Audio Virtual Cable

Install **VB-Audio Virtual Cable** and **VoiceMeeter Banana**, reboot, then:

1. In VoiceMeeter, set the **hardware outputs** (top right):
   - **A1** → your real speakers/headphones (e.g. `Realtek Audio`)
   - **A2** → `CABLE Input (VB-Audio Virtual Cable)`
2. Set the **browser's** audio output (Windows Sound settings, or per-app) to **`VoiceMeeter Input`**.
3. On the VoiceMeeter strip that carries the browser, enable both **A1** and **A2**. The audio now reaches your speakers **and** the virtual cable.
4. In Processing, select **`CABLE Output (VB-Audio Virtual Cable)`** as the input device. The Sound library needs the device **index**, so list devices once and use the matching number:
   ```java
   import processing.sound.*;
   Sound.list();                        // prints all devices + indices to the console
   Sound s = new Sound(this);
   s.inputDevice(CABLE_OUTPUT_INDEX);   // e.g. 45 — yours may differ!
   ```
   > The index is **machine-specific** — never hardcode someone else's number. Read it from `Sound.list()` on the actual installation machine.
5. Verify in Processing's **DevMode** overlay: the `Audio amp:` readout should move when music plays. If it sits at `0.000`, the routing chain is broken (check VoiceMeeter's meters: the bus feeding CABLE Input must show level).

> **Simpler alternative (no VoiceMeeter):** set the browser output **directly** to `CABLE Input`, then in Windows go to *Sound → Recording → CABLE Output → Listen → "Listen to this device"* and pick your speakers. Processing still reads `CABLE Output`. Fastest way to isolate routing problems.

#### macOS — BlackHole

Install **BlackHole 2ch**, then create a combined output so you hear the audio *and* route it:

1. Open **Audio MIDI Setup** (Applications → Utilities).
2. **+ → Create Multi-Output Device.** Tick both **BlackHole 2ch** and your **speakers** (set the speakers as the primary/clock device).
3. Set the **system or browser output** to this **Multi-Output Device**. You now hear audio while a copy flows into BlackHole.
4. In Processing, select **BlackHole 2ch** as the input device (same `Sound.list()` → `inputDevice(index)` approach as above).
5. Confirm with the `Audio amp:` readout in DevMode.

> Keep BlackHole, the Multi-Output Device, and Processing all at **48 kHz** in Audio MIDI Setup.

---

## Running the Full Installation

Bring the system up in this order:

1. **Magenta host** — run the inference notebook, confirm `:9002` and `:9004` are up and the browser player is connected and generating.
2. **Audio routing** — start VoiceMeeter (Windows) / select the Multi-Output Device (macOS) and confirm `Audio amp:` reacts to the music.
3. **Local Python** — `python sound/detect_emotion.py` (prompts WS connected to the host).
4. **Processing** — run the sketch. It opens on the Disclaimer state.

Type a feeling or a secret in the **Input** state → emotion is detected → the music morphs → the **Particles** react to it.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `WinError 10049` on launch | OSC server bound to `127.0.0.1` | Bind to `"0.0.0.0"` |
| Prompts not reaching the host | UDP/OSC blocked by the remote host | Use the **WebSocket** path (:9002), not OSC, for the host |
| Setup: jax/flax/numpy import errors | Lightning's conda env version clash | Use the isolated `~/magenta_venv` exactly as in step 1.3 |
| Notebook: `Cannot find empty port` / `uvloop` errors | event-loop policy conflict | Restart kernel; set `DefaultEventLoopPolicy()` in the first cell |
| Browser audio never connects | port `9004` not public | Expose `9004` in the Lightning **Ports** panel; check browser console (F12) |
| `Audio amp:` stuck at `0.000` | broken audio routing | Verify VoiceMeeter/BlackHole chain; try the direct CABLE-Input bypass |
| Particles barely move with the music | sample-rate mismatch / audio influence scaled too low | Align everything to **48 kHz**; check FFT/Config scaling in the sketch |
| `LineUnavailableException` on second input | audio line re-opened per state cycle | Open the input line **once** and keep it open for the app's lifetime |

---
## Project Structure
```text
Cathartic/
├── processing/               # Processing sketch (P2D)
│   ├── AudioManager.pde      # mic/line input, amplitude + FFT analysis
│   ├── ParticleSystem.pde    # audio-reactive particle field
│   ├── States.pde            # Disclaimer → Input → Particles → Thanks
│   ├── Visuals.pde           # main sketch setup, rendering, and initialization
│   ├── Config.pde            # tunable constants
│   ├── Osc.pde               # OSC communication with the local Python pipeline
│   ├── DevMode.pde           # live diagnostics overlay
│   ├── InputHandler.pde      # manages the visitor's text input and editing
│   └── StateMachine.pde      # controls state transitions and shared state behaviour 
├── sound/                    # local Python pipeline
│   ├── detect_emotion.py     # OSC server + GoEmotions
│   ├── emotion_smoother.py   # EmotionSmoother (ramping + dispatch)
│   └── emotions_to_prompt.py # EMOTION_PROMPTS mapping
├── setup.ipynb               # Lightning: builds the Magenta RT environment (run first)
└── inference.ipynb           # Lightning: Magenta RT generation + WS servers (:9002 / :9004)
```
---

## Credits

Built for the **CPAC (Creative Programming and Computing)** course, Music Engineering.
**Luca Trapella**, **Anna Impembo**, **Giorgio Mattina**, **Francesco Saverio Nisoli**.

Powered by [Magenta RT](https://github.com/magenta/magenta-realtime) (Apache 2.0 code, CC-BY 4.0 weights) and the [GoEmotions](https://huggingface.co/SamLowe/roberta-base-go_emotions) RoBERTa model.
