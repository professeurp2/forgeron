const fs = require('fs');

const slides = [
  {mod:0,title:"Formation PowerPoint",sub:"Maîtriser PowerPoint de A à Z — Cours Pratique Complet",type:"cover"},
  {mod:1,title:"MODULE 1 — Les Bases",sub:"Durée estimée : 1h30",type:"module"},
  {mod:1,title:"L'utilité de PowerPoint",sub:"",type:"theory",points:["Créer des présentations visuelles professionnelles","Animer des réunions, formations, conférences","Communiquer avec impact grâce aux visuels","Compatible avec tous les environnements professionnels"]},
  {mod:1,title:"🖱️ EX 1.1 — Découverte de l'interface",sub:"Durée : 15 min",type:"exercise",steps:["Lancez PowerPoint → cliquez sur **Nouvelle présentation vierge**","Identifiez : le **Ruban** (en haut), les **onglets** (Accueil, Insertion…)","Repérez le **volet des diapositives** (gauche) et la **zone de travail** (centre)","En bas : la **barre d'état** et les boutons de **mode d'affichage**","✅ Check : Nommez 5 éléments de l'interface sans aide"]},
  {mod:1,title:"Les Modes d'affichage",sub:"",type:"theory",points:["**Normal** : édition principale (mode par défaut)","**Plan** : structure textuelle uniquement","**Trieuse de diapositives** : vue d'ensemble, réorganisation rapide","**Lecture** : prévisualisation plein écran","**Diaporama** : présentation finale [F5] ou [Maj+F5]"]},
  {mod:1,title:"🖱️ EX 1.2 — Naviguer entre les modes",sub:"Durée : 10 min",type:"exercise",steps:["Onglet **Affichage** → groupe **Modes de présentation**","Cliquez sur **Trieuse de diapositives** → observez la vue globale","Cliquez sur **Plan** → seul le texte apparaît","Revenez en mode **Normal** via la barre d'état (icône en bas à droite)","✅ Check : Passez en revue les 5 modes et revenez en Normal"]},
  {mod:1,title:"🖱️ EX 1.3 — Gestion des diapositives",sub:"Durée : 15 min",type:"exercise",steps:["En mode **Trieuse** : cliquez-glissez une diapositive pour la **déplacer**","Clic droit dans le volet → **Nouvelle diapositive** pour **insérer**","Sélectionnez une diapositive → touche **[Suppr]** pour **supprimer**","**[Ctrl+Z]** pour annuler une action","✅ Check : Votre présentation comporte 5 diapositives dans le bon ordre"]},
  {mod:1,title:"🖱️ EX 1.4 — Modes d'enregistrement",sub:"Durée : 10 min",type:"exercise",steps:["**[Ctrl+S]** → choisissez l'emplacement → nommez le fichier","**Format .pptx** : présentation modifiable (format par défaut)","**Format .ppsx** : diaporama direct (lecture seule, s'ouvre en plein écran)","Fichier → **Exporter** → **Modifier le type de fichier** → choisissez .ppsx","✅ Check : Deux fichiers créés : un .pptx et un .ppsx"]},
  {mod:2,title:"MODULE 2 — Création d'une Présentation",sub:"Durée estimée : 1h15",type:"module"},
  {mod:2,title:"Les Dispositions de diapositives",sub:"",type:"theory",points:["**Diapositive de titre** : titre + sous-titre (page de garde)","**Titre et contenu** : titre + zone de texte ou liste","**Deux contenus** : deux colonnes côte à côte","**Vide** : liberté totale de mise en page","Accès : onglet **Accueil** → bouton **Disposition**"]},
  {mod:2,title:"🖱️ EX 2.1 — Saisie et mise en forme",sub:"Durée : 20 min",type:"exercise",steps:["Cliquez dans la zone de titre → saisissez le titre du projet","Cliquez dans la zone contenu → saisissez 4 points clés","Sélectionnez le titre → onglet **Accueil** → changez la **police** et la **taille**","Appliquez **Gras** [Ctrl+G], **Italique** [Ctrl+I], changez la **couleur du texte**","✅ Check : Diapositive 1 avec titre formaté et 4 points de contenu"]},
  {mod:2,title:"🖱️ EX 2.2 — Appliquer un thème",sub:"Durée : 15 min",type:"exercise",steps:["Onglet **Création** → groupe **Thèmes** → survolez (prévisualisation live)","Cliquez sur un thème pour l'appliquer à toutes les diapositives","Observez : fond, couleurs, polices et puces changent automatiquement","Testez les **Variantes** (à droite des thèmes) pour ajuster les couleurs","✅ Check : Toutes vos diapositives partagent un thème cohérent"]},
  {mod:2,title:"🖱️ EX 2.3 — Transitions",sub:"Durée : 15 min",type:"exercise",steps:["Onglet **Transitions** → groupe **Transition vers cette diapositive**","Survolez les effets → cliquez sur **Fondu** et observez la prévisualisation","Réglez la **durée** (ex. : 01,00 s) dans le groupe **Minutage**","Cliquez **Appliquer à toutes** pour uniformiser","✅ Check : Lancez le diaporama [F5] et observez les transitions"]},
  {mod:3,title:"MODULE 3 — Gestion des Contenus",sub:"Durée estimée : 2h",type:"module"},
  {mod:3,title:"🖱️ EX 3.1 — Listes à puces multi-niveaux",sub:"Durée : 15 min",type:"exercise",steps:["Cliquez dans une zone de texte avec puces","Saisissez un point → appuyez sur **[Tab]** pour descendre d'un niveau","Appuyez sur **[Maj+Tab]** pour remonter d'un niveau","Onglet **Accueil** → **Puces** pour changer le style","✅ Check : Liste avec au moins 3 niveaux hiérarchiques distincts"]},
  {mod:3,title:"🖱️ EX 3.2 — Créer un graphique",sub:"Durée : 25 min",type:"exercise",steps:["Onglet **Insertion** → groupe **Illustrations** → **Graphique**","Choisissez **Histogramme groupé** → cliquez **OK**","Dans la feuille Excel intégrée : modifiez les données (4 séries, 3 catégories)","Fermez la feuille Excel → le graphique se met à jour automatiquement","Onglet **Création du graphique** → changez le type (ex. : Courbes)","✅ Check : Graphique avec vos données et un titre de graphique"]},
  {mod:3,title:"🖱️ EX 3.3 — Tableaux",sub:"Durée : 20 min",type:"exercise",steps:["Onglet **Insertion** → **Tableau** → sélectionnez 4 colonnes × 3 lignes","Saisissez les données dans chaque cellule","Sélectionnez la ligne 1 → **Outils de tableau** → **Mise en page** → **Fusionner les cellules**","Onglet **Création** → choisissez un **Style de tableau** dans la galerie","✅ Check : Tableau avec en-tête fusionné et style appliqué"]},
  {mod:3,title:"🖱️ EX 3.4 — Images",sub:"Durée : 20 min",type:"exercise",steps:["Onglet **Insertion** → **Images** → **Cet appareil** → sélectionnez une image","Sélectionnez l'image → onglet **Format de l'image** s'affiche","**Rogner** : cliquez Rogner, ajustez les poignées noires","**Styles d'image** : choisissez un cadre dans la galerie (reflet, ombre…)","**Corrections** : ajustez luminosité, contraste et netteté","✅ Check : Image rognée avec un style et des corrections appliqués"]},
  {mod:3,title:"🖱️ EX 3.5 — SmartArt Organigramme",sub:"Durée : 25 min",type:"exercise",steps:["Onglet **Insertion** → **SmartArt** → catégorie **Hiérarchie** → **Organigramme**","Cliquez sur une forme → saisissez un nom ou un poste","Clic droit sur une forme → **Ajouter une forme** → **En dessous**","Onglet **Création SmartArt** → testez différentes **Dispositions**","Onglet **Format SmartArt** → appliquez un **Style SmartArt** coloré","✅ Check : Organigramme avec 3 niveaux et un style SmartArt appliqué"]},
  {mod:4,title:"MODULE 4 — Formatage des Diapositives",sub:"Durée estimée : 1h",type:"module"},
  {mod:4,title:"🖱️ EX 4.1 — Mise en page et couleurs",sub:"Durée : 20 min",type:"exercise",steps:["Onglet **Accueil** → **Disposition** → choisissez une nouvelle mise en page","Onglet **Création** → **Variantes** → **Couleurs** → testez différents jeux","Créez un jeu personnalisé : **Couleurs** → **Personnaliser les couleurs…**","Nommez et enregistrez votre jeu de couleurs","✅ Check : Jeu de couleurs personnalisé appliqué à toute la présentation"]},
  {mod:4,title:"🖱️ EX 4.2 — Arrière-plan et modèle",sub:"Durée : 20 min",type:"exercise",steps:["Onglet **Création** → **Mettre en forme l'arrière-plan**","Testez : **Remplissage uni**, **Dégradé**, **Image ou texture**","Choisissez une texture → cliquez **Appliquer à toutes**","Pour un modèle externe : **Création** → **Thèmes** → **Rechercher des thèmes…**","✅ Check : Arrière-plan cohérent sur toutes les diapositives"]},
  {mod:5,title:"MODULE 5 — Impression",sub:"Durée estimée : 30 min",type:"module"},
  {mod:5,title:"🖱️ EX 5.1 — Modes d'impression",sub:"Durée : 20 min",type:"exercise",steps:["**[Ctrl+P]** ou **Fichier** → **Imprimer**","**Diapositives en pleine page** : une diapositive par page (présentateur)","**Documents → 3 diapositives** : avec lignes de notes (apprenants)","**Page de commentaires** : diapositive + notes du présentateur","**Plan** : texte uniquement, idéal pour relecture","✅ Check : Prévisualisez les 4 modes et imprimez le document 3 diapos/page"]},
  {mod:6,title:"MODULE 6 — Animations",sub:"Durée estimée : 1h",type:"module"},
  {mod:6,title:"Les 4 types d'animations",sub:"",type:"theory",points:["🟢 **Entrée** : l'élément apparaît (Fondu, Envol, Zoom…)","🟡 **Emphase** : l'élément est mis en valeur (Pulsation, Rotation…)","🔴 **Sortie** : l'élément disparaît (Estomper, Voler hors de…)","⚫ **Trajectoire** : l'élément se déplace selon un chemin personnalisé"]},
  {mod:6,title:"🖱️ EX 6.1 — Appliquer et ordonner",sub:"Durée : 20 min",type:"exercise",steps:["Sélectionnez un titre → onglet **Animations** → choisissez **Fondu** (Entrée)","Sélectionnez une image → choisissez **Zoom** (Entrée)","Cliquez **Volet Animation** pour ouvrir le panneau de gestion","Glissez les animations dans le volet pour les **réordonner**","✅ Check : Au moins 3 animations dans un ordre logique"]},
  {mod:6,title:"🖱️ EX 6.2 — Minutage des animations",sub:"Durée : 20 min",type:"exercise",steps:["Dans le **Volet Animation**, cliquez sur une animation → **Minutage**","**Démarrer** : Au clic / Avec le précédent / Après le précédent","**Durée** : temps d'exécution de l'animation (ex. : 00,50 s)","**Délai** : pause avant le démarrage (ex. : 00,50 s)","✅ Check : Séquence automatique (sans clic) fonctionnelle sur une diapositive"]},
  {mod:7,title:"MODULE 7 — Masques",sub:"Durée estimée : 1h",type:"module"},
  {mod:7,title:"Pourquoi utiliser le Masque ?",sub:"",type:"theory",points:["Appliquer une **charte graphique** en une seule opération","Garantir la **cohérence visuelle** sur toutes les diapositives","Ajouter logo, couleurs, polices **une seule fois**","Éviter de modifier chaque diapositive manuellement","2 niveaux : **Masque de diapositive** (parent) et **Masques de disposition** (enfants)"]},
  {mod:7,title:"🖱️ EX 7.1 — Masque de diapositive",sub:"Durée : 25 min",type:"exercise",steps:["Onglet **Affichage** → **Masque des diapositives**","Cliquez sur le **premier masque** (le plus grand, tout en haut)","Insérez un logo : **Insertion** → **Images** → positionnez en bas à droite","Modifiez la police du titre : sélectionnez la zone titre → changez la police","Onglet **Masque des diapositives** → **Fermer le mode Masque**","✅ Check : Le logo apparaît automatiquement sur toutes les diapositives"]},
  {mod:7,title:"🖱️ EX 7.2 — Pied de page et numérotation",sub:"Durée : 20 min",type:"exercise",steps:["Onglet **Insertion** → **En-tête et pied de page**","Cochez **Date et heure** → choisissez **Mise à jour automatique**","Cochez **Numéro de diapositive**","Cochez **Pied de page** → saisissez le nom de votre formation","Cliquez **Appliquer à toutes**","✅ Check : Date, numéro et pied de page visibles sur toutes les diapositives"]},
  {mod:8,title:"MODULE 8 — Les Plus",sub:"Durée estimée : 1h",type:"module"},
  {mod:8,title:"🖱️ EX 8.1 — Boutons d'action",sub:"Durée : 15 min",type:"exercise",steps:["Onglet **Insertion** → **Formes** → section **Boutons d'action** (tout en bas)","Dessinez le bouton **Suivant** (flèche droite) sur votre diapositive","La boîte **Action sur le lien hypertexte** s'ouvre automatiquement","Choisissez **Diapositive suivante** → cliquez **OK**","Testez en mode Diaporama **[F5]**","✅ Check : Le bouton navigue vers la diapositive suivante en diaporama"]},
  {mod:8,title:"🖱️ EX 8.2 — Liens hypertextes",sub:"Durée : 15 min",type:"exercise",steps:["Sélectionnez un texte ou une image → **[Ctrl+K]**","**Lien vers une diapositive** : choisissez **Emplacement dans ce document**","**Lien web** : collez l'URL dans le champ **Adresse**","**Lien fichier** : choisissez **Fichier ou page web existant(e)**","✅ Check : Cliquez le lien en mode Diaporama → la navigation fonctionne"]},
  {mod:8,title:"🖱️ EX 8.3 — Word vers PowerPoint",sub:"Durée : 20 min",type:"exercise",steps:["Dans **Word** : utilisez les styles **Titre 1** (= titre diapositive) et **Titre 2** (= contenu)","Rédigez un plan de 5 rubriques avec sous-points dans Word","Enregistrez le fichier Word","Dans **PowerPoint** : **Accueil** → **Nouvelle diapositive** → **Plan Word…**","Sélectionnez votre fichier Word → les diapositives se génèrent automatiquement","✅ Check : 5 diapositives créées automatiquement depuis le plan Word"]},
  {mod:0,title:"🎓 Exercice de Synthèse Final",sub:"Certification — 60 minutes",type:"cover",extra:"Créez une présentation complète de 12 diapositives sur le thème de votre choix en mobilisant TOUTES les compétences : thème, masque, animations, SmartArt, graphique, tableau, image, boutons d'action et liens hypertextes."},
];

const colors = {0:"#C0392B",1:"#E74C3C",2:"#E67E22",3:"#27AE60",4:"#2980B9",5:"#8E44AD",6:"#16A085",7:"#2C3E50",8:"#D35400"};
const modNames = {0:"",1:"Module 1",2:"Module 2",3:"Module 3",4:"Module 4",5:"Module 5",6:"Module 6",7:"Module 7",8:"Module 8"};

let slideHtml = "";
slides.forEach((s, i) => {
  const c = colors[s.mod] || "#333";
  const mn = modNames[s.mod];
  const header = s.type === "cover" ? "" : `<div class="slide-header" style="background:${c}">${mn}</div>`;
  let body = "";
  if (s.type === "cover") {
    const ex = s.extra ? `<p class="cover-extra">${s.extra}</p>` : "";
    body = `<div class="cover-content"><div class="cover-icon">📊</div><h1>${s.title}</h1><p class="cover-sub">${s.sub}</p>${ex}</div>`;
  } else if (s.type === "module") {
    body = `<div class="module-content" style="border-left:8px solid ${c}"><span class="module-number" style="color:${c}">${mn}</span><h1>${s.title}</h1><p class="module-sub">${s.sub}</p></div>`;
  } else if (s.type === "theory") {
    const pts = s.points.map(p => `<li>${p}</li>`).join("");
    body = `<div class="slide-body"><h2 class="slide-title" style="color:${c}">${s.title}</h2><ul class="theory-list">${pts}</ul></div>`;
  } else {
    const steps = s.steps.map(st => `<li>${st}</li>`).join("");
    body = `<div class="slide-body"><div class="ex-header" style="background:${c}"><span>🖱️</span><h2>${s.title}</h2><span class="ex-dur">${s.sub}</span></div><ol class="step-list">${steps}</ol></div>`;
  }
  slideHtml += `<div class="slide" id="s${i}" style="display:none">${header}${body}</div>\n`;
});

const html = `<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Formation PowerPoint Complète</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700;800&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Inter',sans-serif;background:#0f0f23;display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:100vh}
.deck{position:relative;width:960px;height:540px;box-shadow:0 30px 80px rgba(0,0,0,.6);border-radius:12px;overflow:hidden;background:#fff;flex-shrink:0}
.slide{width:100%;height:100%;display:flex;flex-direction:column;position:absolute;top:0;left:0}
.slide-header{padding:10px 28px;font-size:12px;font-weight:700;color:#fff;letter-spacing:1.5px;text-transform:uppercase;flex-shrink:0}
.cover-content{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;background:linear-gradient(135deg,#C0392B 0%,#8E44AD 100%);color:#fff;text-align:center;padding:40px}
.cover-icon{font-size:64px;margin-bottom:16px;animation:float 3s ease-in-out infinite}
@keyframes float{0%,100%{transform:translateY(0)}50%{transform:translateY(-10px)}}
.cover-content h1{font-size:40px;font-weight:800;line-height:1.2;margin-bottom:12px}
.cover-sub{font-size:17px;opacity:.85;font-weight:300}
.cover-extra{font-size:13.5px;opacity:.88;margin-top:24px;max-width:700px;line-height:1.7;background:rgba(255,255,255,.15);padding:20px;border-radius:10px;text-align:left}
.module-content{flex:1;display:flex;flex-direction:column;justify-content:center;padding:60px;background:linear-gradient(135deg,#f8f9fa 0%,#e9ecef 100%)}
.module-number{font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:2px;margin-bottom:14px;display:block}
.module-content h1{font-size:34px;font-weight:800;color:#1a1a2e;margin-bottom:14px}
.module-sub{font-size:16px;color:#666}
.slide-body{flex:1;padding:24px 36px;display:flex;flex-direction:column;overflow:hidden}
.slide-title{font-size:24px;font-weight:700;margin-bottom:16px;padding-bottom:10px;border-bottom:3px solid currentColor}
.theory-list{list-style:none;flex:1;display:flex;flex-direction:column;justify-content:space-around;gap:6px}
.theory-list li{font-size:15px;padding:10px 16px;background:#f8f9fa;border-radius:8px;border-left:4px solid #ddd;line-height:1.5}
.ex-header{display:flex;align-items:center;gap:12px;padding:12px 18px;border-radius:10px;color:#fff;margin-bottom:14px;flex-shrink:0;font-size:22px}
.ex-header h2{font-size:17px;font-weight:700;flex:1}
.ex-dur{font-size:12px;opacity:.85;white-space:nowrap;font-weight:400}
.step-list{list-style:none;flex:1;display:flex;flex-direction:column;justify-content:space-around;gap:4px;counter-reset:step}
.step-list li{counter-increment:step;display:flex;align-items:flex-start;gap:10px;font-size:13.5px;line-height:1.55;padding:4px 0}
.step-list li::before{content:counter(step);background:#1a1a2e;color:#fff;border-radius:50%;min-width:24px;height:24px;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;flex-shrink:0;margin-top:1px}
.nav{display:flex;align-items:center;gap:16px;margin-top:16px}
.btn{background:rgba(255,255,255,.12);color:#fff;border:1px solid rgba(255,255,255,.2);padding:11px 28px;border-radius:50px;font-size:14px;font-weight:700;cursor:pointer;transition:all .2s;backdrop-filter:blur(10px);font-family:'Inter',sans-serif}
.btn:hover{background:rgba(255,255,255,.22);transform:translateY(-2px)}
.btn:disabled{opacity:.3;cursor:not-allowed;transform:none}
.counter{color:rgba(255,255,255,.7);font-size:13px;font-weight:500;min-width:120px;text-align:center}
.progress{width:960px;height:3px;background:rgba(255,255,255,.15);border-radius:2px;margin-top:10px;overflow:hidden}
.progress-bar{height:100%;background:linear-gradient(90deg,#E74C3C,#8E44AD);transition:width .35s}
</style>
</head>
<body>
<div class="deck">${slideHtml}</div>
<div class="progress"><div class="progress-bar" id="prog"></div></div>
<div class="nav">
  <button class="btn" id="prev" onclick="go(-1)">← Précédent</button>
  <span class="counter" id="cnt"></span>
  <button class="btn" id="next" onclick="go(1)">Suivant →</button>
</div>
<script>
const slides=document.querySelectorAll('.slide');
let cur=0;
function parse(){
  document.querySelectorAll('.slide li,.slide p,.slide h2,.slide h1').forEach(n=>{
    n.innerHTML=n.innerHTML
      .replace(/\\*\\*([^*]+)\\*\\*/g,'<strong style="font-weight:700;color:#1a1a2e">$1</strong>')
      .replace(/\\[([^\\]]+)\\]/g,'<kbd style="background:#eee;border:1px solid #ccc;border-radius:3px;padding:1px 5px;font-size:11px;font-family:monospace">$1</kbd>');
  });
}
function show(n){
  slides[cur].style.display='none';
  cur=Math.max(0,Math.min(n,slides.length-1));
  slides[cur].style.display='flex';
  document.getElementById('cnt').textContent='Diapositive '+(cur+1)+' / '+slides.length;
  document.getElementById('prev').disabled=cur===0;
  document.getElementById('next').disabled=cur===slides.length-1;
  document.getElementById('prog').style.width=((cur+1)/slides.length*100)+'%';
}
function go(d){show(cur+d);}
document.addEventListener('keydown',e=>{
  if(e.key==='ArrowRight'||e.key===' ')go(1);
  if(e.key==='ArrowLeft')go(-1);
});
parse();show(0);
</script>
</body>
</html>`;

fs.writeFileSync('cours_powerpoint.html', html, 'utf8');
console.log('Fichier genere avec succes !');
