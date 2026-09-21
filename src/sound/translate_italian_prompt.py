# ============================================================================
# translate_italian_prompt.py
#
# Translates Italian text (received from Processing) into English before it
# is handed to the GoEmotions classifier in detect_emotion.py, which only
# understands English.
#
# Uses Helsinki-NLP/opus-mt-it-en (MarianMT, ~75M params), converted to
# CTranslate2 and quantized to int8 for fast CPU inference. Tokenization
# still goes through the original Hugging Face tokenizer; only the
# encoder-decoder forward pass runs through CTranslate2.
#
# The converted model is NOT committed to this repo (it's a build artifact).
# Generate it once, locally, after installing requirements.txt:
#
#   ct2-transformers-converter --model Helsinki-NLP/opus-mt-it-en \
#       --output_dir opus-it-en --quantization int8
#
# This writes the CTranslate2 model into sound/opus-it-en/ (next to this
# file), which is where load_translator() below expects to find it.
# ============================================================================

import os

import ctranslate2
from transformers import AutoTokenizer

MODEL_NAME = "Helsinki-NLP/opus-mt-it-en"
CT2_MODEL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "opus-it-en")

_tokenizer = None
_translator = None


def _load():
    """Lazily load the tokenizer and CTranslate2 translator, once."""
    global _tokenizer, _translator
    if _translator is not None:
        return

    if not os.path.isdir(CT2_MODEL_DIR):
        raise FileNotFoundError(
            f"CTranslate2 model not found at '{CT2_MODEL_DIR}'.\n"
            f"Convert it first with:\n"
            f"  ct2-transformers-converter --model {MODEL_NAME} "
            f"--output_dir {CT2_MODEL_DIR} --quantization int8"
        )

    print("Loading Italian->English translation model...")
    _tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    _translator = ctranslate2.Translator(CT2_MODEL_DIR, device="cpu")
    print("Translation model loaded.")


def translate_it_to_en(text: str) -> str:
    """Translate an Italian sentence to English using opus-mt-it-en (CTranslate2, int8)."""
    _load()

    source_tokens = _tokenizer.convert_ids_to_tokens(_tokenizer.encode(text))
    result = _translator.translate_batch([source_tokens])
    target_tokens = result[0].hypotheses[0]

    return _tokenizer.decode(
        _tokenizer.convert_tokens_to_ids(target_tokens),
        skip_special_tokens=True
    )


