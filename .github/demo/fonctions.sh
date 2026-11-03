#!/bin/bash
# Enregistre et monte toutes les vidéos « fonctionnalités » (passager, chauffeur, console).
# bash fonctions.sh <application web démo> <application web chauffeur> <serveur de démo> <dossier de sortie> [scénario ...]
# ELEVENLABS_API_KEY (facultatif) : voix du narrateur et vocal de la passagère WhatsApp.
set -u
ICI=$(cd "$(dirname "$0")" && pwd)
APP=$1; APPCH=$2; SERVEUR=$3; OUT=$4; shift 4
SEULS=("$@")
BRUT=$OUT/brut; VOIX=$OUT/voix
mkdir -p "$BRUT" "$VOIX" "$OUT/passager" "$OUT/chauffeur" "$OUT/console"
veut() { [ ${#SEULS[@]} -eq 0 ] && return 0; for s in "${SEULS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

# Caméra simulée du SOS : l'intérieur du taxi.
ffmpeg -loglevel error -y -i "$ICI/media/interieur-taxi.mp4" -pix_fmt yuv420p "$BRUT/camera.y4m"

APPLI=()
for s in p1-commander p2-vocal p3-destination p4-securite p5-fin-de-course p6-proche-plus-tard p7-compte c1-inscription c2-course c3-ma-destination c4-gains; do
  veut "$s" && APPLI+=("$s")
done
if [ ${#APPLI[@]} -gt 0 ]; then
  FAUSSE_CAMERA=$BRUT/camera.y4m APP_CHAUFFEUR=$APPCH node "$ICI/record_fonctions.js" "$APP" "$BRUT" "${APPLI[@]}" || true
fi
if veut p8-whatsapp; then
  python3 "$ICI/voix_fonctions.py" phrase passagere "$VOIX/passagere-whatsapp.mp3" "Bonjour, je voudrais aller au Twin Center, s'il vous plaît." || true
  node "$ICI/whatsapp.js" "$SERVEUR" "$APP" "$BRUT/p8-whatsapp" "$VOIX/passagere-whatsapp.mp3" || true
fi
CONSOLE=()
for s in visite publicites; do veut "k-$s" && CONSOLE+=("$s"); done
if [ ${#CONSOLE[@]} -gt 0 ]; then
  node "$ICI/console.js" "$SERVEUR" "$BRUT/console" "${CONSOLE[@]}" || true
fi

# Voix du narrateur (une par légende, déjà faites gardées), puis montage.
python3 "$ICI/voix_fonctions.py" legendes "$VOIX" "$BRUT"/*/marks.json "$BRUT"/console/*/marks.json || true
monte() { # <brut> <sortie> [format]
  [ -f "$1/marks.json" ] || { echo "pas d'enregistrement : $1"; return; }
  python3 "$ICI/compose_fonction.py" "$1" "$2" --voix "$VOIX" --format "${3:-telephone}" || echo "::error title=Montage::$2"
}
monte "$BRUT/p1-commander" "$OUT/passager/1-Commander-un-taxi.mp4"
monte "$BRUT/p2-vocal" "$OUT/passager/2-Commander-a-la-voix.mp4"
monte "$BRUT/p8-whatsapp" "$OUT/passager/3-Commander-sur-WhatsApp.mp4"
monte "$BRUT/p3-destination" "$OUT/passager/4-Changer-de-destination.mp4"
monte "$BRUT/p4-securite" "$OUT/passager/5-Securite-et-SOS.mp4"
monte "$BRUT/p5-fin-de-course" "$OUT/passager/6-Fin-de-course-note-et-pourboire.mp4"
monte "$BRUT/p6-proche-plus-tard" "$OUT/passager/7-Pour-un-proche-ou-plus-tard.mp4"
monte "$BRUT/p7-compte" "$OUT/passager/8-Creer-son-compte.mp4"
monte "$BRUT/c1-inscription" "$OUT/chauffeur/1-Inscription-du-chauffeur.mp4"
monte "$BRUT/c2-course" "$OUT/chauffeur/2-Une-course-cote-chauffeur.mp4"
monte "$BRUT/c3-ma-destination" "$OUT/chauffeur/3-Je-rentre-chez-moi.mp4"
monte "$BRUT/c4-gains" "$OUT/chauffeur/4-Mes-gains.mp4"
monte "$BRUT/console/visite" "$OUT/console/1-Console-de-commande.mp4" bureau
monte "$BRUT/console/publicites" "$OUT/console/2-Gerer-les-publicites.mp4" bureau
cp "$BRUT"/echec-*.png "$BRUT"/*/echec*.png "$BRUT"/console/echec-*.png "$OUT/" 2>/dev/null || true
ls -la "$OUT"/passager "$OUT"/chauffeur "$OUT"/console
