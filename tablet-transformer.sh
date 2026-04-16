#!/bin/bash

# --- ARCHIVO DE PERSISTENCIA ---
CONFIG_FILE="$HOME/.tablet_config"
DEVICE="SZ PING-IT INC.  T505 Graphic Tablet Pen (0)"

# Función para cargar valores guardados de forma segura
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # Extraemos los valores usando grep y cut para evitar errores de source
        LAST_TW=$(grep "LAST_TW" "$CONFIG_FILE" | cut -d"'" -f2)
        LAST_TH=$(grep "LAST_TH" "$CONFIG_FILE" | cut -d"'" -f2)
        LAST_SW=$(grep "LAST_SW" "$CONFIG_FILE" | cut -d"'" -f2)
        LAST_SH=$(grep "LAST_SH" "$CONFIG_FILE" | cut -d"'" -f2)
    fi
}

# Función para preguntar con valor por defecto
ask_value() {
    local prompt=$1
    local default=$2
    read -p "$prompt [$default]: " input
    echo "${input:-$default}"
}

load_config

echo "--- 🖋️ TabletScale: Configuración Universal ---"

# 1. Obtención de Dimensiones
TW=$(ask_value "Ancho de tableta (cm)" "$LAST_TW")
TH=$(ask_value "Alto de tableta (cm)" "$LAST_TH")
SW=$(ask_value "Ancho de pantalla (cm)" "$LAST_SW")
SH=$(ask_value "Alto de pantalla (cm)" "$LAST_SH")

# Guardar valores para la próxima ejecución
cat <<EOF > "$CONFIG_FILE"
LAST_TW='$TW'
LAST_TH='$TH'
LAST_SW='$SW'
LAST_SH='$SH'
EOF

# Normalizar decimales
tw=$(echo $TW | tr ',' '.'); th=$(echo $TH | tr ',' '.')
sw=$(echo $SW | tr ',' '.'); sh=$(echo $SH | tr ',' '.')

# Escalas base
sx=$(echo "scale=4; $tw / $sw" | bc)
sy=$(echo "scale=4; $th / $sh" | bc)

# 2. Selección de Rotación
echo -e "\nElija orientación de la tableta:"
echo "[1] 0°   (Normal / Horizontal)"
echo "[2] 90°  (Vertical / Zurdos)"
echo "[3] 180° (Invertida)"
echo "[4] 270° (Vertical inversa)"
read -p "Seleccione (1-4) [1]: " rot
rot=${rot:-1}

# 3. Selección de Posición
echo -e "\nElija posición del área activa:"
echo "[1] Centro"
echo "[2] Inferior Derecha"
echo "[3] Inferior Izquierda"
echo "[4] Superior Derecha"
echo "[5] Superior Izquierda"
read -p "Seleccione (1-5) [1]: " pos
pos=${pos:-1}

# --- LÓGICA DE MATRIZ Y OFFSETS ---
case $rot in
    1) # 0°: [ sx 0 ox 0 sy oy 0 0 1 ]
        case $pos in
            1) ox=$(echo "scale=4; (1-$sx)/2" | bc); oy=$(echo "scale=4; (1-$sy)/2" | bc) ;;
            2) ox=$(echo "scale=4; 1-$sx" | bc);     oy=$(echo "scale=4; 1-$sy" | bc) ;;
            3) ox=0;                                 oy=$(echo "scale=4; 1-$sy" | bc) ;;
            4) ox=$(echo "scale=4; 1-$sx" | bc);     oy=0 ;;
            5) ox=0;                                 oy=0 ;;
        esac
        MATRIX="$sx 0 $ox 0 $sy $oy 0 0 1"
        ;;
    2) # 90°: [ 0 sy ox -sx 0 oy 0 0 1 ]
        case $pos in
            1) ox=$(echo "scale=4; (1-$sy)/2" | bc); oy=$(echo "scale=4; (1+$sx)/2" | bc) ;;
            2) ox=$(echo "scale=4; 1-$sy" | bc);     oy=1 ;;
            3) ox=0;                                 oy=1 ;;
            4) ox=$(echo "scale=4; 1-$sy" | bc);     oy=$sx ;;
            5) ox=0;                                 oy=$sx ;;
        esac
        MATRIX="0 $sy $ox -$sx 0 $oy 0 0 1"
        ;;
    3) # 180°: [ -sx 0 ox 0 -sy oy 0 0 1 ]
        case $pos in
            1) ox=$(echo "scale=4; (1+$sx)/2" | bc); oy=$(echo "scale=4; (1+$sy)/2" | bc) ;;
            2) ox=1;                                 oy=1 ;;
            3) ox=$sx;                               oy=1 ;;
            4) ox=1;                                 oy=$sy ;;
            5) ox=$sx;                               oy=$sy ;;
        esac
        MATRIX="-$sx 0 $ox 0 -$sy $oy 0 0 1"
        ;;
    4) # 270°: [ 0 -sy ox sx 0 oy 0 0 1 ]
        case $pos in
            1) ox=$(echo "scale=4; (1+$sy)/2" | bc); oy=$(echo "scale=4; (1-$sx)/2" | bc) ;;
            2) ox=1;                                 oy=0 ;;
            3) ox=$sy;                               oy=0 ;;
            4) ox=1;                                 oy=$(echo "scale=4; 1-$sx" | bc) ;;
            5) ox=$sy;                               oy=$(echo "scale=4; 1-$sx" | bc) ;;
        esac
        MATRIX="0 -$sy $ox $sx 0 $oy 0 0 1"
        ;;
esac

# --- APLICACIÓN ---
xinput set-prop "$DEVICE" "Coordinate Transformation Matrix" $MATRIX
notify-send "TabletScale" "Configuración Aplicada: Rotación $rot en Posición $pos"
echo -e "\n✅ Matriz aplicada: $MATRIX"
