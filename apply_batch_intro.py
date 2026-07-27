import zipfile
import xml.etree.ElementTree as ET
import os

DOC_PATH = r"C:\Users\CITT Unipod\Downloads\SACKO_LAMINE_PFE_23_07_2026.docx"
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

# Dictionary of replacements for Intro and Résumé
REPLACEMENTS = {
    # Résumé
    93: "Ce Projet de Fin d’Études (PFE) est consacré à la conception, la modélisation et la réalisation d’un prototype de fraiseuse CNC 5 axes compacte, supervisée par un logiciel dédié développé sur mesure (Forgeron). Notre travail répond au besoin de produire des pièces aux géométries complexes sans nécessiter de multiples reprenages manuels, en garantissant un niveau élevé de précision, de répétabilité et de sûreté de fonctionnement.",
    94: "La démarche débute par l'analyse des fondements théoriques de la coupe et des machines à commande numérique, débouchant sur l'évaluation comparative des architectures multi-axes.",
    95: "L'analyse fonctionnelle (APTE, SADT A0, CDCF) nous a conduits à sélectionner une architecture de type Table–Table (Trunnion), intégrant deux axes rotatifs (A et C) au sein de la table porte-pièce combinés aux trois mouvements linéaires orthogonaux (X, Y, Z).",
    96: "Le dimensionnement mécanique a été conduit sur la base des efforts de coupe calculés selon le modèle de Kienzle pour l’alliage aluminium AW-2017A. Nous avons dimensionné les guidages linéaires, les transmissions par vis trapézoïdales/billes, les arbres et les roulements du Trunnion en contrôlant la rigidité, la flèche et la tenue en fatigue.",
    97: "L'architecture électronique s'articule autour du microcontrôleur ESP32-WROOM-32U exécutant le firmware open-source FluidNC v3.7. Le matériel intègre des étages de puissance à moteurs pas-à-pas NEMA 23, une chaîne d'isolation galvanique et de sécurité (fins de course normalement fermés, protection inductive et arrêt d'urgence).",
    98: "Enfin, nous avons développé la suite logicielle Forgeron sous Flutter/Riverpod. Elle prend en charge la supervision en temps réel, le parsing du G-code, le calcul cinématique inverse avec compensation RTCP (Tool Center Point Control) et la détection préventive des singularités géométriques.",
    99: "Mots-clés : CNC 5 axes, mécatronique, Trunnion, ESP32, FluidNC, RTCP, cinématique inverse, Flutter, dimensionnement mécanique, usinage.",

    # Abstract
    103: "This Master’s Thesis focuses on the design, modeling, and fabrication of a compact 5-axis CNC milling machine paired with a custom onboard software suite (Forgeron). The project aims to enable the machining of complex spatial geometries without manual repositioning, ensuring high precision, repeatability, and operational safety.",
    104: "The methodology begins with a comprehensive literature review of milling physics, numerical control systems, and multi-axis kinematics.",
    105: "System engineering tools (APTE, SADT, FAST) led to selecting a Table–Table (Trunnion) architecture, which houses two rotary axes (A and C) in the workpiece table alongside three orthogonal linear axes (X, Y, Z).",
    106: "Mechanical sizing was conducted based on cutting force estimates derived from Kienzle’s model for AW-2017A aluminum. Linear guide rails, lead/ball screws, rotary shafts, and bearings were sized considering structural stiffness, static deflection, and fatigue life.",
    107: "The electronic architecture relies on an ESP32-WROOM-32U microcontroller running FluidNC v3.7 firmware, paired with NEMA 23 stepper drivers, optocoupled isolators, and fail-safe safety circuits (normally closed endstops, flyback protection, and emergency stop).",
    108: "Finally, the Forgeron software application was built using Flutter and Riverpod to handle real-time supervision, G-code parsing, inverse kinematics with Tool Center Point Control (RTCP), and geometric singularity mitigation.",
    109: "Keywords: five-axis CNC, mechatronics, Trunnion, ESP32, FluidNC, RTCP, inverse kinematics, Flutter, mechanical sizing, machining.",

    # Intro
    399: "Dans le secteur moderne du génie mécanique, l'usinage par enlèvement de matière exige un niveau de précision et de flexibilité sans cesse accru. La généralisation des machines-outils à commande numérique (CNC) a profondément transformé les ateliers de fabrication en automatisant le suivi des trajectoires et en supprimant l'incertitude liée aux manipulations manuelles. En particulier, le fraisage constitue la méthode privilégiée pour façonner des surfaces prismatiques et complexes au moyen d'outils rotatifs multi-arêtes.",
    400: "Toutefois, les fraiseuses conventionnelles à 3 axes orthogonaux (X, Y, Z) se heurtent rapidement à des limites géométriques lorsqu'il s'agit de réaliser des dépouilles, des cavités inclinées ou des pales de turbomachines. L'obligation de réorienter manuellement la pièce entre plusieurs phases d'usinage accumule des erreurs d'isostatisme, dégrade la répétabilité et accroît les temps morts. Pour affranchir l'usinage de ces contraintes, l'ingénierie s'oriente vers la cinématique à 5 axes, combinant 3 translats et 2 rotations. Cette configuration permet de maintenir l'outil dans une orientation optimale par rapport à la surface usinée, réduisant l'usure de l'outil et garantissant un état de surface homogène.",
    401: "Notre projet répond à l'opportunité de concevoir une fraiseuse CNC 5 axes compacte à coût maîtrisé. Outre son intérêt expérimental pour l'analyse des algorithmes de commande multi-axes, un tel prototype constitue un équipement d'usinage agile pour le prototypage rapide de pièces mécatroniques de haute précision.",
    403: "Si les bénéfices de l'usinage 5 axes sont avérés, sa mise en œuvre matérielle et logicielle pose des défis majeurs. L'intégration de deux axes rotatifs modifie continuellement la position relative entre le point outil et le repère pièce, engendrant des erreurs cinématiques complexes si la machine ne dispose pas d'une correction continue du repère outil.",
    404: "De plus, la compacité imposée exige d'assurer une rigidité dynamique élevée sous effort de coupe malgré des bras de levier rotatifs importants. Sur le plan de la commande, le pilotage coordonné de 5 actionneurs nécessite une chaîne d'information rapide et une interface de supervision capable d'anticiper les risques de collision, d'instabilité ou de franchissement de singularités géométriques.",
    405: "Dans cette perspective, le défi de notre étude consiste à synthétiser une architecture mécatronique complète (mécanique, électronique embarquée et logiciel de bord) garantissant la précision, la répétabilité et la sécurité des opérations d'usinage.",
    406: "La problématique centrale de notre travail de fin d'études s'énonce ainsi :",
    407: "Comment concevoir et réaliser une fraiseuse CNC 5 axes compacte, intégrant une architecture mécatronique cohérente et un logiciel de bord dédié, afin d’assurer l’usinage de pièces complexes avec précision, répétabilité et sécurité ?",
    408: "De cette question générale découlent les interrogations scientifiques et techniques suivantes :",
    409: "• Quelle architecture cinématique (Trunnion vs Tête pivotante) offre le meilleur compromis entre rigidité et compacité pour une machine d'atelier ?",
    410: "• Comment effectuer le dimensionnement analytique des axes linéaires et rotatifs pour contenir la flèche mécanique sous effort de coupe à un seuil inférieur à 0,02 mm ?",
    411: "• Comment orchestrer la génération des impulsions et la communication temps réel sur une cible électronique microcontrôlée moderne ?",
    412: "• De quelle manière développer l'application de supervision pour intégrer les corrections cinématiques inverses (IK) et la gestion du RTCP (Tool Center Point Control) ?",
    413: "• Quel protocole de test métrologique déployer pour qualifier expérimentalement la répétabilité et la rugosité de la machine réalisée ?",
    415: "Pour guider notre démarche de conception, nous avons posé cinq hypothèses structurantes :",
    416: "1. Architecture cinématique : Nous retenons l'architecture de type Table–Table (Trunnion), où les rotations A (berceau) et C (plateau) sont portées par la table, isolant le portique linéaire X-Y-Z des moments d'inertie de rotation.",
    417: "2. Exigences métrologiques : La conception vise une tolérance géométrique de ±0,05 mm, une précision de positionnement ≤ 0,02 mm, une répétabilité ≤ 0,01 mm et un état de surface caractérisé par une rugosité Ra ≤ 3,2 µm.",
    418: "3. Matériau de référence : L'alliage d'aluminium AW-2017A (Duralumin) est choisi comme matériau de référence pour l'évaluation des forces de coupe et la vérification RDM.",
    419: "4. Actionnement et commande : La chaîne d'énergie repose sur des moteurs pas-à-pas à fort couple pilotés par drivers à micro-pas, contrôlés par un microcontrôleur ESP32-WROOM-32U sous firmware FluidNC.",
    420: "5. Supervision logicielle : Le pilotage repose sur la suite logicielle Forgeron développée sous Flutter, assurant l'interface IHM, la gestion du streaming G-code et la résolution temps réel de la cinématique inverse.",
    421: "Ces hypothèses fixent le cadre technique rigoureux dans lequel nous avons développé et validé notre prototype.",
    423: "L’objectif général de ce Projet de Fin d’Études est de concevoir, dimensionner, fabriquer et qualifier une fraiseuse CNC 5 axes compacte pilotée par un logiciel de bord dédié (Forgeron).",
    424: "Cette réalisation doit valider l'intégration harmonieuse des sous-systèmes mécaniques, électroniques et logiciels pour permettre l'usinage multi-axes de pièces complexes dans le respect des contraintes de précision et de sûreté.",
    426: "Pour répondre à cet objectif global, nous avons mené à bien les actions suivantes :",
    427: "• Synthétiser l'état de l'art du fraisage 5 axes, des topologies cinématiques et des architectures de contrôle numérique.",
    428: "• Formaliser le besoin fonctionnel par la méthode APTE et dresser le Cahier des Charges Fonctionnel (CDCF).",
    429: "• Établir l'architecture mécanique Trunnion et effectuer les calculs de dimensionnement des transmissions (vis/écrous), des guidages et de la tenue mécanique des arbres A et C.",
    430: "• Développer le schéma électronique de puissance et d'adaptation de signal autour de l'ESP32, en intégrant les chaînes de protection et d’arrêt d’urgence.",
    431: "• Programmer l'application de supervision Forgeron, en y intégrant le résoluteur de cinématique inverse, la compensation RTCP et le contrôle des singularités.",
    432: "• Réaliser l'assemblage physique de la machine et procéder aux essais métrologiques de répétabilité, de rigidité et d'usinage effectif.",
    438: "Notre méthodologie s'inscrit dans une approche d'ingénierie système mécatronique, articulant la conception mécanique, la chaîne d'information électronique et le développement logiciel au sein d'un cycle de développement intégré.",
    439: "La démarche débute par l'étude bibliographique, visant à synthétiser les théorèmes de coupe, la cinématique vectorielle et les standards d'interfaçage CNC.",
    440: "Elle se poursuit par la modélisation fonctionnelle (SADT A0, FAST, CDCF) afin de formaliser sans ambiguïté les flux d'énergie et de matière.",
    441: "La phase de dimensionnement mécanique applique le modèle de Kienzle pour estimer les sollicitations de coupe et calculer analytiquement la rigidité des axes X, Y, Z, A et C.",
    442: "La conception électronique élabore le schéma d'interconnexion de l'ESP32, en dimensionnant la distribution de puissance, l'isolation galvanique et le traitement des signaux d'entrée/sortie.",
    443: "Le volet logiciel déploie l'architecture Clean Architecture sous Flutter pour construire l'application Forgeron, garantissant une parfaite séparation entre la logique métier cinématique et l'interface utilisateur.",
    444: "Enfin, la phase d'intégration physique et de qualification métrologique permet de valider le comportement expérimental du prototype sur banc de mesure et d'exécuter des usinages réels.",
    446: "Intérêt scientifique : Ce travail apporte une contribution à l'étude des machines-outils à cinématique sérielle Trunnion. La formalisation mathématique des transformations géométriques (matrices Denavit-Hartenberg), la résolution analytique de la cinématique inverse et le traitement numérique du RTCP constituent un champ d'application concret pour la robotique et la commande numérique.",
    447: "Intérêt technique : Le projet réunit l'ensemble des piliers de la mécatronique moderne : calcul de structures, choix d'actionneurs pas-à-pas, ingénierie des signaux rapides (STEP/DIR), programmation embarquée sous FluidNC et développement d'interfaces de supervision réactives.",
    448: "Intérêt pédagogique : À l'ENI-ABT, cette machine constitue une plateforme idéale d'expérimentation pour l'enseignement du fraisage multi-axes, permettant d'illustrer la corrélation directe entre la chaîne d'énergie et la chaîne d'information.",
    449: "Intérêt économique : En démocratisant l'accès à une technologie 5 axes d'atelier par une conception modulaire basée sur des composants industriels standards (ESP32, guidages linéaires du commerce), ce projet réduit drastiquement le coût d'investissement pour le prototypage rapide et l'enseignement supérieur.",
    450: "Intérêt industriel : La cinématique 5 axes Trunnion ouvre la voie à l'usinage en un seul posage de pièces complexes, minimisant les tolérances d'assemblage et améliorant les états de surface par une orientation continue de l'outil.",
    452: "Le présent mémoire est articulé en six chapitres scientifiques et techniques :",
    453: "• Chapitre 1 : Étude bibliographique et fondements théoriques — Présentation des principes fondamentaux du fraisage, de la cinématique 5 axes, du G-code, du RTCP et de l'état de l'art des commandes numériques.",
    454: "• Chapitre 2 : Étude technologique et analyse fonctionnelle — Analyse du besoin (APTE, SADT A0, FAST), élaboration du Cahier des Charges Fonctionnel et justification des architectures retenues.",
    455: "• Chapitre 3 : Modélisation et dimensionnement mécanique — Calcul des efforts de coupe selon Kienzle, dimensionnement RDM des axes linéaires (X, Y, Z) et des axes rotatifs (A, C) du Trunnion.",
    456: "• Chapitre 4 : Architecture électronique et ingénierie des signaux — Conception du matériel de commande autour de l'ESP32, gestion de la puissance, de la CEM, du filtrage et de la sûreté électrique.",
    457: "• Chapitre 5 : Développement logiciel et ingénierie de commande — Développement de l'application Forgeron (Flutter/Riverpod), mise en œuvre de la cinématique inverse, du RTCP et du streaming G-code.",
    458: "• Chapitre 6 : Réalisation, tests et validation métrologique — Assemblage expérimental, protocole de calibration de la table Trunnion, mesures de répétabilité et essais d'usinage réels."
}

def process():
    src_file = OUT_PATH if os.path.exists(OUT_PATH) else DOC_PATH
    with zipfile.ZipFile(src_file, 'r') as zin:
        xml_content = zin.read('word/document.xml')
        tree = ET.fromstring(xml_content)
        
        paras = tree.findall('.//w:p', NS)
        
        count = 0
        for idx, new_text in REPLACEMENTS.items():
            if idx < len(paras):
                set_paragraph_text(paras[idx], new_text)
                count += 1
                
        print(f"Updated {count} paragraphs in Intro/Résumé.")
        
        out_xml = ET.tostring(tree, encoding='utf-8')
        
    with zipfile.ZipFile(src_file, 'r') as zin:
        with zipfile.ZipFile(OUT_PATH, 'w') as zout:
            for item in zin.infolist():
                if item.filename == 'word/document.xml':
                    zout.writestr(item, out_xml)
                else:
                    zout.writestr(item, zin.read(item.filename))
                    
    print(f"Saved updated doc to {OUT_PATH}")

if __name__ == "__main__":
    process()
