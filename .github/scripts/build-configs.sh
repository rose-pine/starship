#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

CONFIG_JSON="./src/configs.json"
MODULE_DIR="./src/modules"
PALETTE_DIR="./src/themes"
OUT_DIR="./examples"
mkdir -p "$OUT_DIR"

# list of language modules (order preserved)
lang_modules=(c elixir elm golang haskell java julia nodejs nim rust scala python)

# Add prompts here
prompt1="[󱞪](fg:THEME) \\"

# palettes
palettes=("rose-pine" "rose-pine-moon" "rose-pine-dawn")

# Hard reset everything
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# iterate configs safely
while read -r cfg; do
  name=$(jq -r '.name' <<<"$cfg")
  if [ -z "$name" ] || [ "$name" = "null" ]; then
    echo "⚠️ Skipping invalid config: $cfg" >&2
    continue
  fi

  output="$OUT_DIR/$name"
  rm -rf "$output"
  mkdir -p "$output"

  # read modules for this config
  modules=()
  colours=()
  while read -r mod; do
    mname=$(jq -r '.name' <<<"$mod")
    mcolour=$(jq -r '.colour // "iris"' <<<"$mod")
    modules+=("$mname")
    colours+=("$mcolour")
  done < <(jq -c '.modules[]' <<<"$cfg")

  # build format_parts
  format_parts=()

  for i in "${!modules[@]}"; do
    mod="${modules[$i]}"
    accent="${colours[$i]}"
  
    if [ "$mod" = "languages" ]; then
      for lang in "${lang_modules[@]}"; do
        format_parts+=("\$${lang}")
      done
    elif [ "$mod" = "prompt1" ]; then
      replaced="${prompt1//THEME/$accent}"
      format_parts+=("$replaced")
    elif [ "$mod" = "newline" ]; then
      format_parts+=("\n")
    else
      format_parts+=("\$${mod}")
    fi
  done

  # loop over palettes
  for pal in "${palettes[@]}"; do
    outputp="$output/$pal.toml"
    : > "$outputp"

    cat > "$outputp" <<EOF
"\$schema" = 'https://starship.rs/config-schema.json'

format = """
$(printf "%s\\\n" "${format_parts[@]}")
"""
EOF

    pal_file="$PALETTE_DIR/$pal"
    if [ -f "$pal_file" ]; then
      cat "$pal_file" >> "$outputp"
      echo >> "$outputp"
    else
      echo "⚠️ Warning: $pal_file not found, skipping" >&2
    fi

    # append each module, replacing ACCENT with its colour
    for i in "${!modules[@]}"; do
      mod="${modules[$i]}"
      colour="${colours[$i]}"
      file="$MODULE_DIR/$mod"
      if [ -f "$file" ]; then
        sed "s/ACCENT/$colour/g" "$file" >> "$outputp"
        echo >> "$outputp"
      else
        echo "⚠️ Warning: $file not found, skipping" >&2
      fi
    done

    echo "✅ Built $outputp"
  done
done < <(jq -c '.[]' "$CONFIG_JSON")
