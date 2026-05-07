# MAPS every emotion to a specific music prompt for the generative model.
# The mapping is designed to evoke the corresponding emotion in the generated music.


EMOTION_PROMPTS = {
    # --- POSITIVE ---
    "joy":          "bright harmonc pads, major",
    "anger":        "distorted pad",
    "annoyance":    "noisy textures",
    "disapproval":  "dissonant melody",
    "disgust":      "sub bass pulse, chaotic textures, organic",
    "embarrassment":"awkward effects",
    "fear":         "creepy sounds",
    "grief":        "empty space, slow decay, melancholic",
    "nervousness":  "irregular pulses, unstable textures",
    "remorse":      "reverse pads",
    "sadness":      "slow pads in minor key, sparse texture",

    "admiration":   "slow counterpoint melody electronic",
    "amusement":    "playful staccato synth",
    "approval":     "fulfilliing harmonic pad",
    "desire":       "fast irregular gliding melody",
    "caring":       "warm texture, slow tempo",
    "excitement":   "energetic rhythm, bright texture",
    "gratitude":    "oniric pad, joy harp",
    "love":         "warm and love pad",
    "optimism":     "nature pulses, suspended bright",
    "pride":        "electric bagpipe, abstract",

   
    "relief":       "relaxing ambient pad",
    "confusion":    "shepard scale, microtinality",
    "curiosity":    "whimsical woodwinds, exploratory melody, random bright arpeggios",
    "realization":  "tonic ethereal",
    "surprise":     "spurious melodies, slight chaos",
    "neutral":      "ambient silence, soft white noise, minimal texture, 30bpm",
}

def emotions_to_prompts(emotion_vector: dict, top_n: int = 3, threshold: float = 0.1) -> dict:
    """
    Restituisce TUTTI i prompt con il loro peso corrente.
    Emozioni non in EMOTION_PROMPTS vengono ignorate.
    """
    result = {}
    
    # Prima metti tutti a 0
    for prompt in EMOTION_PROMPTS.values():
        result[prompt] = 0.0
    
    # Poi aggiorna con i valori correnti
    for emotion, weight in emotion_vector.items():
        if emotion in EMOTION_PROMPTS:
            prompt = EMOTION_PROMPTS[emotion]
            result[prompt] = round(weight, 2)
    
    return result