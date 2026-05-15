# MAPS every emotion to a specific music prompt for the generative model.
# The mapping is designed to evoke the corresponding emotion in the generated music.


EMOTION_PROMPTS = {
    "joy":          ["bright harmonic pads", "major"],
    "anger":        ["distorted pad"],
    "annoyance":    ["noisy textures"],
    "disapproval":  ["dissonant melody"],
    "disgust":      ["sub bass pulse", "chaotic textures", "organic"],
    "embarrassment":["awkward effects"],
    "fear":         ["creepy sounds"],
    "grief":        ["empty", "melancholic"],
    "nervousness":  ["irregular pulses", "unstable textures"],
    "remorse":      ["reverse pads"],
    "sadness":      ["slow", "minor pads"],

    "admiration":   ["slow counterpoint", "shimmering textures"],
    "amusement":    ["playful melodies"],
    "approval":     ["fulfilling harmonic pad"],
    "desire":       ["irregular", "gliding melody"],
    "caring":       ["warm textures", "slow tempo"],
    "excitement":   ["energetic textures"],
    "gratitude":    ["oniric pad", "ethereal"],
    "love":         ["warm", "love pad"],
    "optimism":     ["nature pulses", "suspended bright"],
    "pride":        ["electric bagpipe", "abstract"],

   
    "relief":       ["relaxing pads", "soft"],
    "confusion":    ["shepard scale", "microtones"],
    "curiosity":    ["random bright arpeggios"],
    "realization":  ["tonic ethereal"],
    "surprise":     ["spurious melodies", "slight chaos"],
    "neutral":      ["_neutral_audio_"], # Special keyword
}

def emotions_to_prompts(emotion_vector: dict, top_n: int = 3, threshold: float = 0.1) -> dict:
    """
    Restituisce TUTTI i prompt con il loro peso corrente.
    Emozioni non in EMOTION_PROMPTS vengono ignorate.
    """
    result = {}
    
    # Prima metti tutti a 0
    for prompt_list in EMOTION_PROMPTS.values():
        for prompt in prompt_list:        
            result[prompt] = 0.0
    
    # Poi aggiorna con i valori correnti
    for emotion, weight in emotion_vector.items():
        if emotion in EMOTION_PROMPTS:
            for prompt in EMOTION_PROMPTS[emotion]:
                result[prompt] = round(weight, 2)
    
    return result