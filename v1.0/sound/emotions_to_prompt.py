# MAPS every emotion to a specific music prompt for the generative model.
# The mapping is designed to evoke the corresponding emotion in the generated music.


EMOTION_PROMPTS = {
    "joy":          ["bright pads", "major harmony", "_joy_audio_"],
    "anger":        ["distorted pad", "_anger_audio_"],
    "annoyance":    ["noisy textures"],
    "disapproval":  ["dissonant melody"],
    "disgust":      ["sub bass pulse", "chaotic textures", "organic timbre"],
    "embarrassment":["uneasy textures"],
    "fear":         ["creepy sounds", "_fear_audio_"],
    "grief":        ["hollow pad", "melancholic melody", "_grief_audio_"],
    "nervousness":  ["trembling drone", "unstable textures"],
    "remorse":      ["reverse pads", "detuned textures", "_remorse_audio_"],
    "sadness":      ["slow melody", "minor pads", "_sadness_audio_"],

    "admiration":   ["slow counterpoint", "shimmering textures"],
    "amusement":    ["playful plucks"],
    "approval":     ["resolved harmony"],
    "desire":       ["lush pad", "gliding melody"],
    "caring":       ["warm textures", "soft pad", "_caring_audio_"],
    "excitement":   ["glittering textures"],
    "gratitude":    ["dreamy pad", "ethereal textures"],
    "love":         ["warm timbre", "love pad", "_love_audio_"],
    "optimism":     ["bright suspended chords", "_optimism_audio_"],
    "pride":        ["wide drone", "saw timbres"],

   
    "relief":       ["relaxing pads", "soft timbre"],
    "confusion":    ["shepard tones", "microtones"],
    "curiosity":    ["glittering arpeggios"],
    "realization":  ["tonic drone"],
    "surprise":     ["sudden motifs", "accented textures"],
    
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