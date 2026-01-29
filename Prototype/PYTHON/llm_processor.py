from llama_cpp import Llama
from langdetect import detect, LangDetectException
from huggingface_hub import hf_hub_download

# Downloading the model from HuggingFace Hub
model_name = "bartowski/google_gemma-3-4b-it-qat-GGUF"
model_file = "google_gemma-3-4b-it-qat-Q4_K_S.gguf"

# Model loading
# n_ctx=512 memory context
try:
    print("Model downloading/loading... (This may take a while the first time)") 
    model_path = hf_hub_download(repo_id=model_name, filename=model_file)

    llm = Llama(
        model_path=model_path,
        n_ctx=512, 
        n_gpu_layers=0, # Currently force CPU usage (for laptop applications)
        verbose=False   # Disable loading info printout
    )

except Exception as e:
    print(f"Error loading LLM: {e}")
    llm = None

def translate(text):
    if not llm:
        return text # Model not loaded
    
    # Detect the language of the input text
    try:
        lang = detect(text)
    except LangDetectException:
        return text

    # If already English, return as is
    if lang == 'en':
        return text

    prompt = f"""<start_of_turn>user
                You are a faithful translation engine. You'll translate all user input into English.
                "{text}"<end_of_turn>
                <start_of_turn>model
                """

    output = llm(
        prompt, 
        max_tokens=2000, 
        stop=["<end_of_turn>"], # Stops generation at end of turn token
        echo=False
    )
    
    return output['choices'][0]['text'].strip()