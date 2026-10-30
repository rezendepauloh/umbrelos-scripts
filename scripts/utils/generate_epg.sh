#!/usr/bin/env bash
# ==============================================================================
# Script: generate_epg.sh
# Finalidade: Baixar fontes de EPG brasileiras, cruzar automaticamente com a
#             lista canais_brasil.m3u e gerar o guia_brasil.xml sob medida.
# ==============================================================================
set -euo pipefail

DEST_DIR="/home/umbrel/umbrel/home/Downloads/iptv"
M3U_FILE="${DEST_DIR}/canais_brasil.m3u"
OUTPUT_XML="${DEST_DIR}/guia_brasil.xml"
PYTHON_BIN="$(which python3)"

if [[ ! -f "$M3U_FILE" ]]; then
    echo "Erro: Arquivo $M3U_FILE não encontrado."
    exit 1
fi

echo "[+] Iniciando processamento do Guia EPG XMLTV customizado..."

"$PYTHON_BIN" - << 'EOF'
import re
import urllib.request
import gzip
import xml.etree.ElementTree as ET
from datetime import datetime

M3U_FILE = "/home/umbrel/umbrel/home/Downloads/iptv/canais_brasil.m3u"
OUTPUT_XML = "/home/umbrel/umbrel/home/Downloads/iptv/guia_brasil.xml"

SOURCES = [
    ("epg.pw", "https://epg.pw/xmltv/epg_BR.xml.gz"),
    ("epgshare_BR1", "https://epgshare01.online/epgshare01/epg_ripper_BR1.xml.gz"),
    ("epgshare_BR2", "https://epgshare01.online/epgshare01/epg_ripper_BR2.xml.gz")
]

# 1. Carregar canais da M3U
m3u_channels = []
with open(M3U_FILE, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        if line.startswith("#EXTINF"):
            name = line.split(",")[-1].strip()
            tvg_id = ""
            m_id = re.search(r'tvg-id="([^"]+)"', line)
            if m_id:
                tvg_id = m_id.group(1)
            m3u_channels.append({"name": name, "tvg_id": tvg_id})

print(f"[+] Total de canais na M3U: {len(m3u_channels)}")

# 2. Baixar e agregar EPGs
epg_trees = []
headers = {"User-Agent": "Mozilla/5.0"}
for sname, url in SOURCES:
    try:
        print(f"[+] Baixando fonte {sname}...")
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = gzip.decompress(resp.read())
            root = ET.fromstring(data)
            epg_trees.append((sname, root))
            print(f"    -> {sname}: {len(root.findall('channel'))} canais e {len(root.findall('programme'))} programas.")
    except Exception as e:
        print(f"    [!] Falha ao baixar {sname}: {e}")

if not epg_trees:
    print("[!] Nenhuma fonte de EPG disponível.")
    exit(1)

def normalize(s):
    if not s:
        return ""
    s = s.lower()
    s = re.sub(r"\s*[\[\(].*?[\]\)]", "", s)
    s = re.sub(r"^(são paulo/sp|belo horizonte/mg|rio de janeiro/rj|\.+)\s*", "", s)
    s = re.sub(r"\b(hd|sd|³|brasil|brazil|interior|sp|mg|rj|nacional|news|tv|canal|fast|oficial|play)\b", "", s)
    s = re.sub(r"[^a-z0-9]", "", s)
    return s.strip()

# Indexar canais e programas de todas as fontes
# canal_key -> lista de programmes
programmes_by_source_id = {} # (sname, cid) -> list of ET.Element
channels_by_source_id = {}   # (sname, cid) -> {names, elem}

for sname, root in epg_trees:
    for ch in root.findall("channel"):
        cid = ch.attrib.get("id")
        dnames = [d.text for d in ch.findall("display-name") if d.text]
        channels_by_source_id[(sname, cid)] = {"names": dnames, "elem": ch}
    for prog in root.findall("programme"):
        pcid = prog.attrib.get("channel")
        programmes_by_source_id.setdefault((sname, pcid), []).append(prog)

# Mapeamento explícito para os principais canais abertos e conhecidos
EXPLICIT_MAP = {
    # M3U tvg-id -> (sname, cid)
    "RecordTVInteriorSP.br@SD": [("epg.pw", "523282"), ("epgshare_BR1", "São.Paulo/SP..Record.HD.br")],
    "RecordNews.br@SD": [("epg.pw", "523352"), ("epgshare_BR1", "São.Paulo/SP..Record.News..br")],
    "PlutoTVRecordNews.us@BR": [("epg.pw", "523352"), ("epgshare_BR1", "São.Paulo/SP..Record.News..br")],
    "SBTInterior.br@SD": [("epg.pw", "523298"), ("epgshare_BR1", "São.Paulo/SP..SBT.HD.br")],
    "SBTNacional.br@SD": [("epg.pw", "523298"), ("epgshare_BR1", "São.Paulo/SP..SBT.HD.br")],
    "SBTNews.br@SD": [("epg.pw", "523298"), ("epgshare_BR1", "São.Paulo/SP..SBT.HD.br")],
    "SBTNovaMutum.br@SD": [("epg.pw", "523298"), ("epgshare_BR1", "São.Paulo/SP..SBT.HD.br")],
    "TVCultura.br@SD": [("epg.pw", "523305"), ("epgshare_BR1", "São.Paulo/SP..Cultura.HD.br")],
    "CulturaFast.br@SD": [("epg.pw", "523305"), ("epgshare_BR1", "São.Paulo/SP..Cultura.HD.br")],
    "TVGloboBrasilia.br@SD": [("epg.pw", "523353"), ("epgshare_BR1", "São.Paulo/SP..Globo.HD.br")],
    "GloboNews.br@SD": [("epg.pw", "523341"), ("epgshare_BR1", "São.Paulo/SP..GloboNews.HD.³.br")],
    "RedeTV.br@SD": [("epg.pw", "523301")],
    "RedeTVMais.br@SD": [("epg.pw", "523301")],
    "RedeTVParana.br@SD": [("epg.pw", "523301")],
    "Band.br@SD": [("epg.pw", "523315"), ("epgshare_BR1", "São.Paulo/SP..Band.HD.br")],
    "BandNews.br@SD": [("epg.pw", "523314"), ("epgshare_BR1", "São.Paulo/SP..Band.News.HD.br")],
    "BandSports.br@SD": [("epg.pw", "523330"), ("epgshare_BR1", "São.Paulo/SP..Band.Sports.HD.³.br")],
    "Arte1.br@SD": [("epg.pw", "523338"), ("epgshare_BR1", "São.Paulo/SP..Arte.1.HD.br")],
    "JovemPanNews.br@SD": [("epg.pw", "417187"), ("epgshare_BR1", "Jovem.Pan.News.br")],
    "CNNBrasil.br@SD": [("epg.pw", "575441"), ("epgshare_BR1", "São.Paulo/SP..CNN.Brasil.HD.br")],
    "CanalRural.br@SD": [("epg.pw", "523340")],
    "CanaldoBoi.br@SD": [("epg.pw", "523289")],
    "AgroMais.br@SD": [("epg.pw", "575394")],
    "AgroCanal.br@SD": [("epg.pw", "575394")],
    "TVBrasil.br@SD": [("epg.pw", "523339")],
    "TVBrasil2.br@SD": [("epg.pw", "523339")],
    "TVJustica.br@SD": [("epg.pw", "523337")],
    "TVSenado.br@SD": [("epg.pw", "523336")],
    "TVCamara.br@SD": [("epg.pw", "523335")],
    "TVNovoTempo.br@SD": [("epg.pw", "523304")],
    "TVGazeta.br@SD": [("epg.pw", "523302")],
    "TVGazetaSP.br@SD": [("epg.pw", "523302")],
    "RedeVida.br@SD": [("epg.pw", "523303")],
    "RedeSeculo21.br@SD": [("epg.pw", "523288")],
    "RedeGospel.br@SD": [("epg.pw", "575422")],
    "RITTV.br@SD": [("epg.pw", "574430")],
    "TVAparecida.br@SD": [("epg.pw", "523345")],
    "Futura.br@SD": [("epg.pw", "426052")],
    "CanalFutura.br@SD": [("epg.pw", "426052")],
    "AXN.br@SD": [("epg.pw", "523313")],
    "ESPN.br@SD": [("epg.pw", "418725")],
    "ESPN2.br@SD": [("epg.pw", "418722")],
    "ESPN4.br@SD": [("epg.pw", "425978")],
    "SonyMovies.br@SD": [("epg.pw", "417588")],
    "TelecineAction.br@SD": [("epg.pw", "523346")],
    "TerraViva.br@SD": [("epg.pw", "575451")],
    "TNTNovelas.br@SD": [("epg.pw", "575397")],
    "RedeBrasil.br@SD": [("epg.pw", "417589")]
}

# Criar a nova árvore XMLTV unificada e exata
out_root = ET.Element("tv", {
    "generator-info-name": "Homelab-EPG-Generator",
    "generator-info-url": "http://192.168.0.8"
})

matched_count = 0
total_programmes = 0

for ch_info in m3u_channels:
    tvg_id = ch_info["tvg_id"]
    name = ch_info["name"]
    if not tvg_id:
        continue
    
    # 1. Verificar mapa explícito
    candidates = EXPLICIT_MAP.get(tvg_id, [])
    
    # 2. Se não houver explícito, tentar correspondência heurística
    if not candidates:
        norm_name = normalize(name)
        if len(norm_name) >= 3:
            for (sname, cid), ch_data in channels_by_source_id.items():
                for dname in ch_data["names"]:
                    norm_epg = normalize(dname)
                    if norm_name == norm_epg and len(norm_epg) >= 3:
                        candidates.append((sname, cid))
                        break
                if candidates:
                    break

    # Pegar programas dos candidatos encontrados
    target_programmes = []
    for sname, cid in candidates:
        progs = programmes_by_source_id.get((sname, cid), [])
        if progs:
            target_programmes = progs
            break
            
    # Criar tag <channel> com o exato tvg_id do M3U
    ch_elem = ET.SubElement(out_root, "channel", {"id": tvg_id})
    d_elem = ET.SubElement(ch_elem, "display-name", {"lang": "pt"})
    d_elem.text = name

    if target_programmes:
        matched_count += 1
        for p in target_programmes:
            # Clonar o programa mas alterando o atributo channel para o tvg_id da M3U
            p_elem = ET.SubElement(out_root, "programme", {
                "start": p.attrib.get("start", ""),
                "stop": p.attrib.get("stop", ""),
                "channel": tvg_id
            })
            for child in p:
                c_sub = ET.SubElement(p_elem, child.tag, child.attrib)
                c_sub.text = child.text
            total_programmes += 1

print(f"[+] Canais M3U com grade de programação casada: {matched_count} de {len(m3u_channels)}")
print(f"[+] Total de programas inseridos no novo guia: {total_programmes}")

# Salvar arquivo formatado
tree = ET.ElementTree(out_root)
ET.indent(tree, space="  ", level=0)
tree.write(OUTPUT_XML, encoding="utf-8", xml_declaration=True)
print(f"[+] Arquivo gerado com sucesso em: {OUTPUT_XML}")
EOF

echo "[+] Ajustando permissões para o Jellyfin..."
chmod 664 "$OUTPUT_XML"
echo "[+] Concluído!"

