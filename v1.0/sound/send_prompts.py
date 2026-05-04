from pythonosc import udp_client
import json

client = udp_client.SimpleUDPClient("127.0.0.1", 9001) # port on lightning.ai

# manda solo quelli che vuoi aggiornare
# I prompt non presenti nel messaggio rimangono invariati. 
# Assicurati che i nomi corrispondano esattamente a quelli già presenti in current_params["prompts"] su lightning.
client.send_message("/prompts", json.dumps({
    "ambient": 0.8,
    "distorted noise": 0.2,
}))