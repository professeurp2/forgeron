import re

user_msg = 'Charge ce fichier STEP et prépare le G-code de finition. Fichier : C:\\path\\rend.step'
ai_bad = 'I encountered an error while attempting to generate the G-code from the STEP file. The delay exceeded the maximum allowed time of 120 seconds. Please check the file and ensure it is compatible with the CAM generator.'
ai_good = "J'ai rencontré une erreur lors de la génération du G-code pour ce fichier STEP. Le délai de 120 secondes a été dépassé. Vérifiez que la pièce est bien adaptée au générateur CAM."

def is_french(text):
    fr_words = {'le', 'la', 'les', 'un', 'une', 'des', 'du', 'de', 'ce', 'cette', 'ces', 'et', 'en', 'pour', 'dans', 'sur', 'avec', 'est', 'sont', 'j', 'l', 'd', 'qu', 'charge', 'prepare', 'fichier', 'usinage', 'bonjour'}
    words = re.findall(r'[a-zA-Z\u00C0-\u00FF]+', text.lower())
    hits = sum(1 for w in words if w in fr_words)
    has_accent = any(c in text.lower() for c in 'éèêàçùôîëï')
    return hits >= 2 or has_accent

def is_english_prose(text):
    en_words = {'the', 'is', 'are', 'and', 'to', 'of', 'in', 'that', 'it', 'you', 'we', 'with', 'for', 'on', 'as', 'this', 'from', 'at', 'by', 'an', 'be', 'have', 'has', 'would', 'please', 'encountered', 'while', 'attempting', 'ensure', 'check'}
    words = re.findall(r'[a-zA-Z]+', text.lower())
    hits = sum(1 for w in words if w in en_words)
    return hits >= 3

print('user_msg is_french:', is_french(user_msg))
print('ai_bad is_english:', is_english_prose(ai_bad), 'is_french:', is_french(ai_bad))
print('ai_good is_english:', is_english_prose(ai_good), 'is_french:', is_french(ai_good))

