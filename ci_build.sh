#!/usr/bin/env bash

directories_to_compile=("Maps" "Maps/Edges" "Maps/Connectors")
base_plugins=("TFOR.ESP" "Quilts & Quills.esp")

final_plugin_name="The Propaganda Machine"

zip_name="The Propaganda Machine.zip"
directories_to_zip=("Scripts" "Textures" "Meshes" "Icons" "Sound" "Shaders")

final_omwaddon=""
first_file=true

current_dir=$(pwd)

config_file="$HOME/.config/openmw/openmw.cfg"
MTM_VERSION=v0.9.3

if [ ! -f "$config_file" ]; then
    echo "OpenMW config file not found. Creating it now..."

    mkdir -p "$(dirname "$config_file")"

    echo "data=$(pwd)" > "$config_file"

    echo "Created OpenMW config file at $config_file"
else
    echo "OpenMW config file already exists at $config_file"
fi

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

mkdir -p "$HOME/.local/bin"

export PATH="$PATH:$HOME/.local/bin"

if ! command_exists morrobroom; then
    echo "Installing Morrobroom..."
    wget -O morrobroom.zip https://github.com/magicaldave/Morrobroom/releases/latest/download/Ubuntu-latest.zip
    tar xvf morrobroom.zip
    chmod +x morrobroom
    mv morrobroom "$HOME/.local/bin/"
    rm morrobroom.zip
else
    echo "Morrobroom is already installed."
fi

if ! command_exists merge_to_master; then
    echo "Installing merge_to_master..."
    wget -O merge_to_master.zip https://github.com/Greatness7/merge_to_master/releases/download/"$MTM_VERSION"/merge_to_master_"$MTM_VERSION"_ubuntu.zip
    unzip merge_to_master.zip -d "$HOME/.local/bin"
    rm merge_to_master.zip
    chmod +x "$HOME/.local/bin/merge_to_master"
else
    echo "merge_to_master is already installed."
fi

echo "Installation check complete. Please ensure $HOME/.local/bin is in your PATH."

for dir in "${directories_to_compile[@]}"; do
    echo "Processing directory: $dir"

    cd "$current_dir/$dir" || { echo "Failed to change to $dir"; continue; }

    if [ -f "$current_dir/compile_all.sh" ]; then
        echo "Running compile_all.sh in $dir"
        bash "$current_dir"/compile_all.sh
    else
        echo "compile_all.sh not found in $dir"
    fi

    cp -R Meshes *.omwaddon "$current_dir"

    rm -rf Meshes *.omwaddon backups

    cd "$current_dir" || { echo "Failed to return to original directory"; exit 1; }

    echo -e "Finished compiling $dir\n"
done

echo "All maps processed, merging plugin groups"

for file in *.omwaddon; do
    if [ -f "$file" ]; then
        if [ "$first_file" = true ]; then
            final_omwaddon="$file"
            first_file=false
        else
            echo "Merging map result" "$file" "into" "$final_omwaddon"
            merge_to_master "$file" "$final_omwaddon"
        fi
    fi
done

for esp in "${base_plugins[@]}"; do
    merge_to_master "$esp" "$final_omwaddon"
    cat merge_to_master.log | sort && rm merge_to_master.log
done

for file in *.omwaddon; do
    if [ "$file" != "$final_omwaddon" ]; then
        rm "$file"
    fi
done

mv "$final_omwaddon" "$final_plugin_name".omwaddon

zip -r9 "$zip_name" "$final_plugin_name".omwaddon "${directories_to_zip[@]}"
