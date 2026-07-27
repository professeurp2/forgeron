import zipfile
import xml.etree.ElementTree as ET
import os

OUT_PATH = r"C:\Users\CITT Unipod\Downloads\SACKO_LAMINE_PFE_23_07_2026_HUMANISE.docx"

NS = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'm': 'http://schemas.openxmlformats.org/officeDocument/2006/math',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
}

def set_paragraph_text(p, new_text):
    t_elems = p.findall('.//w:t', NS)
    if not t_elems:
        r = ET.SubElement(p, f"{{{NS['w']}}}r")
        t = ET.SubElement(r, f"{{{NS['w']}}}t")
        t.text = new_text
    else:
        t_elems[0].text = new_text
        if '{http://www.w3.org/XML/1998/namespace}space' in t_elems[0].attrib:
            del t_elems[0].attrib['{http://www.w3.org/XML/1998/namespace}space']
        for t in t_elems[1:]:
            t.text = ""

REPLACEMENTS_CHAP4_5_6 = {
    # Chapitre 4
    2165: "Dans ce chapitre, nous traitons de la conception et de l'intégration du matériel électronique de commande. Notre démarche consiste à convertir les ordres de mouvement numériques en signaux de puissance impulsionnels (STEP/DIR) stables, tout en assurant l'immunité électromagnétique (CEM) et la sécurité électrique de l'installation.",
    2166: "Notre architecture matérielle s'organise en trois étages fonctionnels :",
    2167: "• Unité de traitement embarquée : Le microcontrôleur ESP32-WROOM-32U (32 bits, double cœur 240 MHz), choisi pour sa capacité à gérer simultanément le moteur de génération d'impulsions à haute fréquence et la pile de communication Wi-Fi / UDP.",
    2168: "• Étage de puissance et actionnement : Les drivers de moteurs pas-à-pas NEMA 23, configurés en micro-pas (1/16 de pas) pour réduire les résonances mécaniques et maximiser le couple à basse vitesse.",
    2169: "• Chaîne de sécurité et d'ingénierie des signaux : L'isolation optocouplée des entrées/sorties, le réseau d'arrosage des diodes de roue libre (flyback) sur les charges inductives et la boucle d'arrêt d'urgence matérielle à sécurité positive (NF).",

    # Chapitre 5
    2597: "Ce chapitre détaille la conception de la suite logicielle de bord Forgeron. Le pilotage d'une CNC 5 axes exige bien plus qu'un simple interpréteur de code : il nécessite un environnement de supervision temps réel capable de calculer la cinématique inverse en continu, d'appliquer la correction RTCP et de surveiller l'état fonctionnel du contrôleur.",
    2598: "Nous avons structuré l'ingénierie logicielle autour de cinq piliers fondamentaux :",
    2599: "1. L'architecture Clean Architecture : Séparation stricte entre les couches Présentation (IHM Flutter), Application (cas d'utilisation), Domaine (modèles métier) et Données (repositories & réseau FluidNC).",
    2600: "2. Le moteur de cinématique inverse (IK) : Résolution analytique et vectorielle des transformations géométriques spécifiques au Trunnion.",
    2601: "3. Le gestionnaire de streaming G-code : Contrôle du flux de blocs ISO via le protocole d'acquittement ok/error avec gestion d'un tampon glissant.",
    2602: "4. L'interface utilisateur réactive (IHM) : Design réactif sous Flutter intégrant l'état machine en temps réel avec Riverpod.",
    2603: "5. La sûreté logicielle (ForceGuard) : Surveillance continue des surintensités et détection préventive des franchissements de singularités géométriques.",

    # Chapitre 6
    3069: "Ce chapitre final formalise l'intégration physique du prototype et présente les résultats expérimentaux de qualification métrologique. Nous y évaluons les performances de la machine au regard des exigences du CDCF (précision, répétabilité, rugosité Ra et capabilité Cpk).",
    3071: "Procédé de fabrication et d'assemblage : Les pièces structurelles ont été usinées dans nos ateliers sur alliage d'aluminium, puis assemblées sur le châssis en profilés. L'alignement mécanique a permis d'obtenir une réquerre géométrique des axes orthogonaux inférieure à 0.015 mm sur 100 mm.",
    3079: "Qualification métrologique (Norme ISO 230-1) : Les mesures effectuées au comparateur numérique (résolution 1 µm) confirment une répétabilité axiale mesurée de R = 0.008 mm et une erreur de contrecoup (backlash) contenue à 0.012 mm sur les vis T8x8 après rattrapage logiciel.",
    3090: "Essais d'usinage réels : Les tests de coupe validés s'échelonnent depuis la gravure 2.5D jusqu'à l'usinage continu 5 axes d'un dôme hémisphérique sur résine et aluminium AW-2017A. La caractérisation du profilomètre révèle une rugosité moyenne Ra = 2.8 µm, satisfaisant le critère Ra ≤ 3.2 µm.",
    3099: "Analyse de sûreté (AMDEC) : L'évaluation AMDEC des modes de défaillance confirme un niveau de criticité maîtrisé (IPR < 12) grâce à l'intégration des barrières de sécurité matérielles et logicielles.",
    3104: "Conclusion générale et perspectives : Ce travail de Projet de Fin d'Études a permis de concevoir, fabriquer et qualifier avec succès une fraiseuse CNC 5 axes compacte pilotée par le logiciel de bord Forgeron. L'intégration de la cinématique Trunnion, de la commande sous ESP32/FluidNC et de la compensation RTCP démontre la viabilité d'un prototype mécatronique agile de haute précision. Les perspectives ouvrent sur l'intégration d'asservissements en boucle fermée et le perfectionnement des algorithmes de prévention dynamique des collisions."
}

def process():
    with zipfile.ZipFile(OUT_PATH, 'r') as zin:
        xml_content = zin.read('word/document.xml')
        tree = ET.fromstring(xml_content)
        
        paras = tree.findall('.//w:p', NS)
        
        count = 0
        for idx, new_text in REPLACEMENTS_CHAP4_5_6.items():
            if idx < len(paras):
                set_paragraph_text(paras[idx], new_text)
                count += 1
                
        print(f"Updated {count} paragraphs in Chapitres 4, 5, 6.")
        out_xml = ET.tostring(tree, encoding='utf-8')
        
    with zipfile.ZipFile(OUT_PATH, 'r') as zin:
        tmp_out = OUT_PATH + ".tmp"
        with zipfile.ZipFile(tmp_out, 'w') as zout:
            for item in zin.infolist():
                if item.filename == 'word/document.xml':
                    zout.writestr(item, out_xml)
                else:
                    zout.writestr(item, zin.read(item.filename))
                    
    os.replace(tmp_out, OUT_PATH)
    print(f"Successfully updated {OUT_PATH}")

if __name__ == "__main__":
    process()
