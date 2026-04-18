#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  scripts/old-server-prep.sh
# ═══════════════════════════════════════════════════════════════════
#  Prépare mc-server-old pour un boot rapide en mode "migration" :
#    1. Cold backup complet de mc-server-old → backups/pre-migration-*
#    2. Multiverse worlds.yml : autoload=false pour toutes les maps
#       sauf `swr` (la map principale définie par level-name).
#    3. keepspawninmemory=false partout (garde moins de chunks en RAM).
#
#  Résultat : boot en ~30s au lieu de 7 min, tu `/mv load <map>` à la
#  demande au moment de l'export schematic.
#
#  Idempotent : ré-exécuter ne refait pas le backup si présent, ne
#  retouche pas les flags déjà désactivés.
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

OLD_DIR="mc-server-old"
WORLDS_YML="$OLD_DIR/plugins/Multiverse-Core/worlds.yml"
SPIGOT_YML="$OLD_DIR/spigot.yml"
SERVER_PROPS="$OLD_DIR/server.properties"
KEEP_WORLD="${KEEP_WORLD:-swr}"   # map principale (synced with server.properties level-name)

# ─── Garde-fous ────────────────────────────────────────────────────
[[ -d "$OLD_DIR" ]]     || { echo "❌ $OLD_DIR introuvable. Lance depuis la racine du repo."; exit 1; }
[[ -f "$WORLDS_YML" ]]  || { echo "❌ $WORLDS_YML introuvable."; exit 1; }
[[ -f "$SPIGOT_YML" ]]  || { echo "❌ $SPIGOT_YML introuvable."; exit 1; }
[[ -f "$SERVER_PROPS" ]] || { echo "❌ $SERVER_PROPS introuvable."; exit 1; }

# ─── 1. Cold backup (une seule fois) ───────────────────────────────
mkdir -p backups
BACKUP_GLOB=(backups/pre-migration-*.tar.gz)
if [[ -f "${BACKUP_GLOB[0]}" ]]; then
    echo "✓ Cold backup déjà présent : ${BACKUP_GLOB[0]} (skip)"
else
    TS=$(date +%Y%m%d-%H%M%S)
    BACKUP_FILE="backups/pre-migration-${TS}.tar.gz"
    echo "▶ Création du cold backup : $BACKUP_FILE"
    tar czf "$BACKUP_FILE" "$OLD_DIR"
    echo "✓ Cold backup OK ($(du -h "$BACKUP_FILE" | cut -f1))"
fi

# ─── 2. Patch worlds.yml (Python pour un YAML propre) ──────────────
echo "▶ Patch worlds.yml : autoload=false sauf '$KEEP_WORLD'…"
python3 - "$WORLDS_YML" "$KEEP_WORLD" <<'PYEOF'
import sys, re, shutil, pathlib
path, keep = sys.argv[1], sys.argv[2]
p = pathlib.Path(path)
shutil.copy(p, p.with_suffix(".yml.bak"))   # backup local côte-à-côte
text = p.read_text()

# Parser ligne à ligne : détecter les blocs `  <worldname>:` et appliquer.
lines = text.splitlines()
out = []
current = None
changed = 0
for line in lines:
    m = re.match(r"^  ([A-Za-z0-9_]+):\s*$", line)
    if m:
        current = m.group(1)
        out.append(line)
        continue
    if current and current != keep:
        if re.match(r"^    autoload:\s*true\s*$", line):
            out.append("    autoload: false")
            changed += 1
            continue
        if re.match(r"^    keepspawninmemory:\s*true\s*$", line):
            out.append("    keepspawninmemory: false")
            changed += 1
            continue
    out.append(line)

p.write_text("\n".join(out) + "\n")
print(f"  → {changed} flags basculés à false.")
PYEOF

# ─── 3. Patch spigot.yml : désactive IP forwarding BungeeCord ──────
#
# L'ancien serveur vivait derrière un BungeeCord en 2016. spigot.yml
# contient `bungeecord: true` → le serveur refuse toute connexion
# directe (erreur : "If you wish to use IP forwarding, please enable
# it in your BungeeCord config as well!"). En mode migration on se
# connecte en direct, donc on désactive ce flag.
echo "▶ Patch spigot.yml : bungeecord=false (connexion directe)…"
python3 - "$SPIGOT_YML" <<'PYEOF'
import sys, re, pathlib
p = pathlib.Path(sys.argv[1])
text = p.read_text()
new, n = re.subn(r"^(\s*bungeecord:\s*)true\s*$",
                 r"\1false", text, flags=re.MULTILINE)
if n:
    p.write_text(new)
    print(f"  → bungeecord: true → false ({n} remplacement)")
else:
    print("  ✓ bungeecord déjà à false (rien à faire)")
PYEOF

# ─── 4. Patch server.properties : vide server-ip ──────────────────
#
# L'ancien serveur tournait sur un VPS dédié avec IP publique fixe
# (62.210.62.193 en 2016). Cette IP est écrite dans server-ip= et
# sur WSL/ta machine elle n'existe pas → « Cannot assign requested
# address ». On vide le champ : le serveur binde alors sur 0.0.0.0
# (toutes les interfaces locales), ce qui marche partout.
echo "▶ Patch server.properties : server-ip=<vide> (bind 0.0.0.0)…"
python3 - "$SERVER_PROPS" <<'PYEOF'
import sys, re, pathlib
p = pathlib.Path(sys.argv[1])
text = p.read_text()
new, n = re.subn(r"^server-ip=.*$", "server-ip=", text, flags=re.MULTILINE)
if n:
    p.write_text(new)
    print(f"  → server-ip vidé ({n} remplacement)")
else:
    # Pas de ligne server-ip → on l'ajoute vide pour cohérence.
    p.write_text(text.rstrip() + "\nserver-ip=\n")
    print("  → server-ip ajouté (vide)")
PYEOF

echo ""
echo "✓ Préparation terminée. Tu peux maintenant lancer :"
echo "    cd $OLD_DIR"
echo "    /usr/lib/jvm/java-8-openjdk-amd64/bin/java -Xmx2G -jar spigot-1.8.7.jar nogui 2>&1 | tee logs/migration.log"
echo ""
echo "Une fois in-game, charge les maps à la demande :"
echo "    /mv load <nom-de-la-map>"
echo "    //schem save <nom> fast"
