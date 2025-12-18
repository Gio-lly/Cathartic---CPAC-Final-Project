# 1. Import required packages
from transformers import pipeline
import torch
import pandas as pd
from pythonosc import dispatcher
from pythonosc import osc_server
from pythonosc import udp_client

# 2. Load the pre-trained GoEmotions model
MODEL_NAME = "SamLowe/roberta-base-go_emotions"

emotion_classifier = pipeline(
    "text-classification",
    model=MODEL_NAME,
    return_all_scores=True,
    top_k=None
)

def analyze_emotions(texts, classifier):
    """
    Executes emotion analysis on a list of texts.
    
    Arguments:
        texts (list or str): A single text or a list of texts to analyze.
        classifier: The emotion_classifier instance (e.g., from Hugging Face).

    Returns:
        list: A list of dictionaries with the original text and ordered emotions.
    """
    # If a single string is provided, convert it to a list
    if isinstance(texts, str):
        texts = [texts]
        
    results = []
    
    for t in texts:
        # Execute the classifier on the text
        # Note: we assume the classifier returns a list of dictionaries
        scores = classifier(t)[0]
        
        # Transform the list into a dictionary {label: score}
        emotions = {d["label"]: float(d["score"]) for d in scores}

        # Order the dictionary by score (descending)
        sorted_emo = dict(sorted(emotions.items(), key=lambda x: x[1], reverse=True))
        
        # Unify the original text with the ordered results
        results.append({"text": t, **sorted_emo})
        
    return results

def osc_text_handler(address, *args):
    text = args[0]
    print("Received text:", text)

    # ANALISI EMOZIONI
    results = analyze_emotions(text, emotion_classifier)

    df_results = pd.DataFrame(results)
    print(df_results)
    
    # Send emotions as OSC messages
    client = udp_client.SimpleUDPClient("127.0.0.1", 12002)
    
    # Extract emotions from results (skip the 'text' key)
    emotions = {k: v for k, v in results[0].items() if k != 'text'}
    
    for emotion_name, emotion_value in emotions.items():
        osc_path = f"/emotion/{emotion_name}"
        client.send_message(osc_path, emotion_value)
        print(f"Sent OSC: {osc_path} = {emotion_value}")


# 3. Example usage
if __name__ == "__main__":
    disp = dispatcher.Dispatcher()
    disp.map("/text", osc_text_handler)

    server = osc_server.ThreadingOSCUDPServer(
        ("127.0.0.1", 12001),
        disp
    )

    print("Python OSC server listening on port 12001")
    server.serve_forever()

