import zipfile
import xml.etree.ElementTree as ET
import sys
import os

DOC_PATH = r"C:\Users\CITT Unipod\Downloads\SACKO_LAMINE_PFE_23_07_2026.docx"
OUT_PATH = r"C:\Users\CITT Unipod\Downloads\SACKO_LAMINE_PFE_23_07_2026_HUMANISE.docx"

NS = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'm': 'http://schemas.openxmlformats.org/officeDocument/2006/math',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
}

def get_paragraph_text(p):
    return ''.join([t.text for t in p.findall('.//w:t', NS) if t.text])

def set_paragraph_text(p, new_text):
    # Check if paragraph has drawing or math
    if p.findall('.//w:drawing', NS) or p.findall('.//m:oMath', NS):
        # Do not overwrite drawings or complex math structures completely
        pass
    
    t_elems = p.findall('.//w:t', NS)
    if not t_elems:
        # If no w:t element exists, create one inside a run
        r = ET.SubElement(p, f"{{{NS['w']}}}r")
        t = ET.SubElement(r, f"{{{NS['w']}}}t")
        t.text = new_text
    else:
        t_elems[0].text = new_text
        t_elems[0].attrib.pop('{http://www.w3.org/XML/1998/namespace}space', None)
        # Clear remaining w:t elements
        for t in t_elems[1:]:
            t.text = ""

def load_document(doc_path=DOC_PATH):
    with zipfile.ZipFile(doc_path, 'r') as z:
        xml_content = z.read('word/document.xml')
        tree = ET.fromstring(xml_content)
    return tree

def get_sections(tree):
    paragraphs = tree.findall('.//w:p', NS)
    sections = []
    current_sec = "En-tête"
    current_list = []
    
    for idx, p in enumerate(paragraphs):
        p_text = get_paragraph_text(p).strip()
        pStyle = p.find('.//w:pStyle', NS)
        style_val = pStyle.attrib.get(f"{{{NS['w']}}}val", '') if pStyle is not None else ''
        
        is_heading = 'Titre1' in style_val or 'Heading1' in style_val or p_text.upper().startswith(('CHAPITRE', 'INTRODUCTION GÉNÉRALE', 'CONCLUSION GÉNÉRALE'))
        
        if is_heading and p_text:
            if current_list:
                sections.append((current_sec, current_list))
            current_sec = p_text
            current_list = [(idx, p, p_text, style_val)]
        else:
            current_list.append((idx, p, p_text, style_val))
            
    if current_list:
        sections.append((current_sec, current_list))
        
    return sections

if __name__ == "__main__":
    tree = load_document()
    secs = get_sections(tree)
    print(f"Loaded {len(secs)} sections.")
    for title, paras in secs:
        non_empty = [p for idx, p, txt, st in paras if txt]
        wcount = sum(len(txt.split()) for idx, p, txt, st in paras if txt)
        print(f"Section: {title[:50]} -> {len(non_empty)} non-empty paras, ~{wcount} words")
