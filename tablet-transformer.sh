#!/bin/bash

# --- PERSISTENCE FILE ---
CONFIG_FILE="$HOME/.tablet_config"
DEVICE="SZ PING-IT INC.  T505 Graphic Tablet Pen (0)"

# Function to load saved values safely
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # Extract values using grep/cut to avoid 'source' execution risks
        LAST_TW=$(grep "LAST_TW" "$CONFIG_FILE" | cut -d"'" -f2)
        LAST_TH=$(grep "LAST_TH" "$CONFIG_FILE" | cut -d"'" -f2)
        LAST_SW=$(grep "LAST_SW" "$CONFIG_FILE" | cut -d"'" -f2)
        LAST_SH=$(grep "LAST_SH" "$CONFIG_FILE" | cut -d"'" -f2)
    fi
}

# Function to prompt with a default value
ask_value() {
    local prompt=$1
    local default=$2
    read -p "$prompt [$default]: " input
    echo "${input:-$default}"
}

load_config

echo "--- 🖋️ TabletScale: Universal Configuration ---"

# 1. Dimension Acquisition
TW=$(ask_value "Tablet Width (cm)" "$LAST_TW")
TH=$(ask_value "Tablet Height (cm)" "$LAST_TH")
SW=$(ask_value "Screen Width (cm)" "$LAST_SW")
SH=$(ask_value "Screen Height (cm)" "$LAST_SH")

# Save values for the next session
cat <<EOF > "$CONFIG_FILE"
LAST_TW='$TW'
LAST_TH='$TH'
LAST_SW='$SW'
LAST_SH='$SH'
EOF

# Normalize decimals (handle comma as decimal separator)
tw=$(echo $TW | tr ',' '.'); th=$(echo $TH | tr ',' '.')
sw=$(echo $SW | tr ',' '.'); sh=$(echo $SH | tr ',' '.')

# Base Scaling Factors
sx=$(echo "scale=4; $tw / $sw" | bc)
sy=$(echo "scale=4; $th / $sh" | bc)

# 2. Rotation Selection
echo -e "\nChoose Tablet Orientation:"
echo "[1] 0°   (Normal / Landscape)"
echo "[2] 90°  (Vertical / Left-handed)"
echo "[3] 180° (Inverted)"
echo "[4] 270° (Inverted Vertical)"
read -p "Select (1-4) [1]: " rot
rot=${rot:-1}

# 3. Position Selection
echo -e "\nChoose Active Area Position:"
echo "[1] Center"
echo "[2] Bottom Right"
echo "[3] Bottom Left"
echo "[4] Top Right"
echo "[5] Top Left"
read -p "Select (1-5) [1]: " pos
pos=${pos:-1}

# --- MATRIX LOGIC AND OFFSETS ---
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

# --- APPLICATION ---
xinput set-prop "$DEVICE" "Coordinate Transformation Matrix" $MATRIX
notify-send "TabletScale" "Configuration Applied: Rotation $rot at Position $pos"
echo -e "\n✅ Applied Matrix: $MATRIX"
