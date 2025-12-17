# 2. Import required packages
from transformers import pipeline
import torch
import pandas as pd

# 3. Load the pre-trained GoEmotions model
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

# 4. Example usage
if __name__ == "__main__":
    sample_texts = [
        "I am so happy today!",
        "This is the worst day ever.",
        "I feel nothing."
    ]
    
    emotion_results = analyze_emotions(sample_texts, emotion_classifier)
    
    # Convert results to a DataFrame for better visualization
    df_results = pd.DataFrame(emotion_results)
    print(df_results)