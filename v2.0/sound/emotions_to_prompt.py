# ============================================================================
# emotions_to_prompt.py
#
# Translates the emotion score dictionary produced by the GoEmotions
# classifier (see detect_emotion.py) into a set of weighted text prompts
# for the Magenta RealTime music model running on Lightning.ai.
#
# Used by: emotion_smoother.py, which periodically calls
# emotions_to_prompts() on the current smoothed emotion values and sends
# the resulting prompt dictionary over WebSocket to Lightning.ai.
# ============================================================================

# ----------------------------------------------------------------------------
# Emotion -> music prompt mapping
#
# Each emotion from the GoEmotions label set maps to one or more text
# prompts describing musical qualities meant to evoke that emotion.
# Entries wrapped in underscores (e.g. "_joy_audio_") are special keywords
# recognized by the Magenta RealTime pipeline as references to pre-recorded
# audio snippets rather than plain text-conditioning prompts.
# ----------------------------------------------------------------------------
EMOTION_PROMPTS = {
    "joy":           ["bright pads", "major harmony", "_joy_audio_"],
    "anger":         ["distorted pad", "_anger_audio_"],
    "annoyance":     ["noisy textures"],
    "disapproval":   ["dissonant melody"],
    "disgust":       ["sub bass pulse", "chaotic textures", "organic timbre"],
    "embarrassment": ["uneasy textures"],
    "fear":          ["creepy sounds", "_fear_audio_"],
    "grief":         ["hollow pad", "melancholic melody", "_grief_audio_"],
    "nervousness":   ["trembling drone", "unstable textures"],
    "remorse":       ["reverse pads", "detuned textures", "_remorse_audio_"],
    "sadness":       ["slow melody", "minor pads", "_sadness_audio_"],

    "admiration":    ["slow counterpoint", "shimmering textures"],
    "amusement":     ["playful plucks"],
    "approval":      ["resolved harmony"],
    "desire":        ["lush pad", "gliding melody"],
    "caring":        ["warm textures", "soft pad", "_caring_audio_"],
    "excitement":    ["glittering textures"],
    "gratitude":     ["dreamy pad", "ethereal textures"],
    "love":          ["warm timbre", "love pad", "_love_audio_"],
    "optimism":      ["bright suspended chords", "_optimism_audio_"],
    "pride":         ["wide drone", "saw timbres"],

    "relief":        ["relaxing pads", "soft timbre"],
    "confusion":     ["shepard tones", "microtones"],
    "curiosity":     ["glittering arpeggios"],
    "realization":   ["tonic drone"],
    "surprise":      ["sudden motifs", "accented textures"],

    "neutral":       ["_neutral_audio_"],  # Special keyword for the neutral state
}


# ----------------------------------------------------------------------------
# Conversion function
# ----------------------------------------------------------------------------
def emotions_to_prompts(emotion_vector: dict) -> dict:
    """
    Convert an emotion score dictionary into a prompt-weight dictionary.

    Every prompt referenced in EMOTION_PROMPTS starts at weight 0.0, then
    prompts belonging to emotions present in `emotion_vector` are updated
    with that emotion's (rounded) weight. Emotions not present in
    EMOTION_PROMPTS are ignored.

    """
    result = {prompt: 0.0 for prompts in EMOTION_PROMPTS.values() for prompt in prompts}

    for emotion, weight in emotion_vector.items():
        if emotion in EMOTION_PROMPTS:
            for prompt in EMOTION_PROMPTS[emotion]:
                result[prompt] = round(weight, 2)

    return result
