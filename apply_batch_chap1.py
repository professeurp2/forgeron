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

REPLACEMENTS_CHAP1 = {
    461: "La conception et le pilotage des machines-outils à commande numérique (CNC) reposent sur la synergie entre la mécanique générale, la dynamique de coupe et l'informatique industrielle.",
    462: "Ce chapitre établit le socle bibliographique et théorique nécessaire à la conception de notre fraiseuse 5 axes. Nous y analysons les paramètres fondamentaux de la coupe par fraisage, la typologie des outils et des porte-outils, ainsi que les principes de la commande numérique par calculateur.",
    463: "L'étude développe ensuite la cinématique spécifique des machines 5 axes, en évaluant comparativement les architectures sérielles (Head-Head, Head-Table, Table-Table).",
    464: "Enfin, nous examinons l'écosystème logiciel moderne : normalisation ISO du G-code, gestion du RTCP (Remote Tool Center Point), firmwares embarqués open-source et protocoles de communication pour la supervision temps réel.",

    467: "Le fraisage constitue un procédé de fabrication mécanique par enlèvement de matière où l'action d'une fraise rotative à dents multiples est combinée à une trajectoire de translation ou de rotation contrôlée. La géométrie de la pièce découle directement de l'interaction dynamique entre les arêtes tranchantes de l'outil et le matériau brut.",
    469: "Dans les fraiseuses conventionnelles, la disposition spatiale de l'axe de broche détermine l'ergonomie et la dynamique de travail :",
    471: "• Fraiseuses horizontales : L'axe de la broche est parallèle à la table d'usinage. Cette architecture favorise l'évacuation des copeaux sous gravité et permet l'emploi de fraises-disques montées sur arbre long avec clavetage pour le surfaçage de pièces massives.",
    478: "• Fraiseuses verticales : La broche est orientée perpendiculairement au plan de la table. Cette configuration offre une visibilité directe de la zone de coupe et facilite les opérations de perçage, d'alésage et de surfaçage à l'aide de fraises à queue.",
    481: "• Fraiseuses universelles : Équipées d'une tête orientable et d'une table orientable selon un axe vertical, elles autorisent le taillage d'engrenages hélicoïdaux et l'exécution d'usinages obliques complexes.",

    493: "Classification selon la construction matérielle : Les fraiseuses intègrent soit des fraises monoblocs (en acier rapide HSS ou carbure monobloc, privilégiées pour leur grande rigidité géométrique), soit des fraises à plaquettes amovibles (en carbure de tungstène revêtues TiAlN, assurant une vitesse de coupe élevée et un renouvellement économique du tranchant).",
    499: "Classification selon la denture et le taillage : Le mode de taillage (fraises à une, deux, trois ou quatre flûtes) conditionne le volume des goujures. Les outils à deux dents sont recommandés pour le fraisage de l'aluminium (AW-2017A) afin de prévenir le bourrage des copeaux, tandis que les fraises à quatre dents maximisent la productivité sur aciers.",

    510: "La liaison encastrement entre la broche et la fraise détermine le niveau de battement radial (run-out) et la déflexion mécanique sous effort.",
    512: "• Fixation par alésage : L'outil est centré sur un arbre porte-fraise avec clavetage transversal pour les fraises à surfacer de grand diamètre.",
    524: "• Fixation par queue : Les fraises à queue cylindrique ou conique (Cône Morse, ISO, BT, CAT) s'insèrent dans des organes d'adaptation.",
    540: "• Porte-outils à pinces ER : Largement généralisés sur les machines CNC compactes, les mandrins ER (pinces ER11 à ER32) assurent une concentricité rigoureuse (faux-rond < 0,01 mm) et un maintien par striction élastique à 360°, garantissant l'absorption des vibrations sous sollicitations dynamiques.",

    553: "La sélection rationnelle des conditions de coupe garantit la précision dimensionnelle tout en évitant l'usure prématurée de l'outil et le broutement (chatter).",
    555: "Vitesse de coupe (Vc) et vitesse de broche (N) : La vitesse de coupe (Vc, en m/min) exprime la vitesse linéaire relative de l'arête tranchante en contact avec la matière. La vitesse de broche (N, en tr/min) dérive directement de la relation N = (1000 * Vc) / (pi * D), où D est le diamètre effectif de la fraise.",
    561: "Avance par dent (fz) et vitesse d'avance (Vf) : L'avance par dent (fz, en mm/dent) fixe l'épaisseur maximale du copeau. La vitesse d'avance linéaire de la machine (Vf, en mm/min) est calculée par la relation Vf = N * z * fz, où z est le nombre de dents actives.",
    567: "L'engagement de l'outil est caractérisé par la profondeur de passe axiale (ap, ADOC) et la largeur de passe radiale (ae, RDOC). En ébauche sur aluminium, nous adoptons ae ≈ 0.4 * D pour maximiser le débit de matière, tandis qu'en finition, ae est réduit à 5 % de D pour garantir une faible rugosité (Ra ≤ 3.2 µm).",

    574: "L'évolution des systèmes CNC reflète la transition depuis la logique câblée vers l'ingénierie embarquée numérique temps réel.",
    576: "Origines et évolution : Initiée dans les années 1950 par Parsons et le MIT sur cartes perforées, la commande numérique a évolué de la CN câblée aux architectures intégrées modernes reposant sur des microcontrôleurs 32 bits (ESP32) cadencés à 240 MHz et équipés de bus de communication rapides (Wi-Fi, USB-Serial).",
    582: "L'asservissement d'un système CNC garantit la fidélité de la trajectoire. En boucle fermée, des capteurs de position (encodeurs angulaires ou règles optiques) comparent la position réelle à la position consigne pour corriger l'erreur de suivi. En boucle ouverte (retenue pour notre prototype compact avec moteurs pas-à-pas), la précision repose sur le non-décrochage du couple moteur et la résolution fine du micro-pas.",

    600: "Le passage de 3 à 5 axes cinématiques introduit deux degrés de liberté de rotation complémentaires, autorisant l'orientation permanente de l'axe outil parallèlement à la normale de la surface à usiner.",
    608: "Configuration « Head-Head » (Tête bi-rotative) : Les deux rotations sont portées par la tête porte-broche. Cette architecture déconnecte la masse de la pièce des axes rotatifs, la rendant idéale pour les pièces aéronautiques volumineuses, mais impose un grand porte-à-faux mécanique et une rigidité angulaire complexe à stabiliser.",
    617: "Configuration « Head-Table » (Hybride) : La rotation est répartie entre la tête (axe B ou A) et la table (axe C). Elle offre un équilibre cinématique, mais complique la géométrie des transformations vectorielles.",
    627: "Configuration « Table-Table » (Trunnion Table) : Retenue pour notre prototype, cette architecture intègre les deux axes rotatifs A (basculement du berceau) et C (rotation du plateau) au sein du bloc table. Elle conserve une broche fixe en orientation (translations X, Y, Z pures), maximisant la rigidité structurelle et la précision angulaire pour les pièces compactes.",

    633: "Singularités et Gimbal Lock : Une singularité cinématique survient lorsque l'axe de rotation C devient colinéaire avec l'axe de la broche (axe Z en position A = 0°). Dans cette zone, une infime variation d'orientation outil exige une vitesse angulaire théoriquement infinie de l'axe C. Notre étude intègre un algorithme de détection et de contournement par saut angulaire pour éviter les pertes de pas.",

    640: "La chaîne numérique 5 axes relie la CAO 3D à la pièce physique via le processeur CAM (FAO), le post-processeur (générant le G-code ISO 6983) et le système d'interprétation CNC.",
    648: "Gestion du RTCP (G43.4) : Le contrôle du point centre outil (RTCP - Remote Tool Center Point) est la brique logicielle indispensable en 5 axes. Il calcule dynamiquement la compensation des translations X, Y, Z lors des rotations de la table Trunnion pour maintenir la pointe de l'outil exactement sur le point de consigne de la pièce.",

    651: "Firmwares Open-Source et Interfaces : L'analyse comparative des firmwares embarqués (Grbl, Marlin, Smoothieware, FluidNC) met en évidence la supériorité de FluidNC pour les systèmes multi-axes sous ESP32, grâce à sa gestion native des systèmes de coordonnées, du Wi-Fi et de la modularité YAML.",

    664: "Conclusion du chapitre : L'étude bibliographique confirme la pertinence de l'architecture Trunnion (Table-Table) couplée à une commande sous ESP32/FluidNC pour fabriquer une fraiseuse 5 axes compacte, rigide et précise."
}

def process():
    with zipfile.ZipFile(OUT_PATH, 'r') as zin:
        xml_content = zin.read('word/document.xml')
        tree = ET.fromstring(xml_content)
        
        paras = tree.findall('.//w:p', NS)
        
        count = 0
        for idx, new_text in REPLACEMENTS_CHAP1.items():
            if idx < len(paras):
                set_paragraph_text(paras[idx], new_text)
                count += 1
                
        print(f"Updated {count} paragraphs in Chapitre 1.")
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
