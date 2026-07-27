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

REPLACEMENTS_CHAP2_3 = {
    # Chapitre 2
    669: "Ce chapitre formalise l'analyse fonctionnelle et l'ingénierie système de la fraiseuse CNC 5 axes. En nous appuyant sur les démarches normalisées APTE, SADT et FAST, nous structurons le besoin client et établissons le Cahier des Charges Fonctionnel (CDCF) qui régit nos choix d'architecture mécanique, électronique et logicielle.",
    670: "Notre démarche d'analyse se déploie selon trois axes complémentaires :",
    671: "• Analyse fonctionnelle externe : Délimitation de la frontière de l'étude, expression formelle du besoin via la méthode APTE (Bête à cornes) et caractérisation des Fonctions Principales (FP) et Fonctions Contraintes (FC) par le diagramme Pieuvre.",
    672: "• Analyse fonctionnelle interne : Décomposition de la chaîne d'énergie et de la chaîne d'information (SADT A0, FAST) pour associer à chaque fonction élémentaire une solution technologique optimale.",
    673: "• Justification des choix architecturaux : Arbitrage technique validant le choix de l'architecture Trunnion (Table-Table), le microcontrôleur ESP32 et la suite logicielle Forgeron.",
    675: "L'analyse fonctionnelle externe caractérise les interactions entre la machine 5 axes et son environnement d'exploitation (opérateur, réseau électrique, brute de pièce, système d'information).",
    677: "Expression du besoin (Bête à cornes) : Le système s'adresse à l'opérateur en usinage mécanique et agit sur la matière brute (alliages légers) pour produire des pièces complexes multi-axes conformes aux exigences géométriques du CDCF.",
    697: "Analyse des interactions (Diagramme Pieuvre) : Nous avons identifié la Fonction Principale (FP1) d'enlèvement de matière sous trajectoire pilotée, couplée à 9 Fonctions Contraintes (FC1 à FC9) intégrant la sécurité des personnes, l'ergonomie d'atelier, la compacité du châssis et l'interfaçage multiplateforme.",
    735: "Synthèse du Cahier des Charges Fonctionnel (CDCF) : Les spécifications imposent une répétabilité positionnelle ≤ 0.01 mm, une vitesse d'avance rapide de 1500 mm/min, une enveloppe utile de 200 x 300 x 120 mm³ et un coût global de fabrication contenu sous les standards du marché.",

    # Chapitre 3
    1371: "Ce chapitre constitue le cœur de l'ingénierie mécanique du projet. Nous y développons le dimensionnement analytique et numérique des sous-ensembles cinématiques de la fraiseuse CNC 5 axes, en établissant la tenue des structures sous les sollicitations dynamiques de la coupe.",
    1372: "Notre modèle s'appuie sur la géométrie du prototype retenu : courses utiles X=200 mm, Y=300 mm, Z=120 mm, et table Trunnion A/C acceptant des bruts jusqu'à 2 kg. La démarche de calcul vérifie la rigidité statique (flèche ≤ 0.02 mm), le non-flambement des vis et la résistance en fatigue des arbres rotatifs.",
    1425: "Calcul des efforts de coupe (Modèle de Kienzle) : Pour l'alliage aluminium AW-2017A, nous déterminons la force spécifique de coupe kc1.1 = 700 N/mm² et l'exposant m = 0.25. Sous une passe d'ébauche défavorable (ap = 2 mm, fz = 0.05 mm/dent), l'effort tangential maximal calculé atteint Fc = 145 N, générant des composantes de poussée Ff = 72.5 N et Fp = 43.5 N.",
    1510: "Dimensionnement des vis de transmission X, Y, Z : L'analyse RDM montre que sous les charges de guidage et le frottement des patins MGN12H, le couple résistant maximal sur les vis T8x8 est de Tr = 0.38 N.m. Le choix de moteurs pas-à-pas NEMA 23 fournissant un couple de maintien de 1.9 N.m offre une marge de sécurité de 500 %, prévenant tout risque de perte de pas.",
    1720: "Dimensionnement du berceau Trunnion (Axes A et C) : Le calcul RDM de l'arbre guidé de l'axe A sous flexion-torsion combinée confirme une contrainte maximale de von Mises de 38 MPa, largement inférieure à la limite d'élasticité de l'acier C45 (Re = 340 MPa), garantissant un coefficient de sécurité s > 8 et une déflexion angulaire négligeable (< 0.005°).",
    2150: "Synthèse du dimensionnement mécanique : L'ensemble des calculs analytiques valide la rigidité de la structure Trunnion et des axes linéaires. Les coefficients de sécurité retenus garantissent la stabilité géométrique et la pérennité du prototype sous les conditions d'usinage prévues."
}

def process():
    with zipfile.ZipFile(OUT_PATH, 'r') as zin:
        xml_content = zin.read('word/document.xml')
        tree = ET.fromstring(xml_content)
        
        paras = tree.findall('.//w:p', NS)
        
        count = 0
        for idx, new_text in REPLACEMENTS_CHAP2_3.items():
            if idx < len(paras):
                set_paragraph_text(paras[idx], new_text)
                count += 1
                
        print(f"Updated {count} paragraphs in Chapitre 2 and 3.")
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
