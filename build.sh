#! /usr/bin/env bash

set -eu

temp_dir="${TMP_DIR:-$(mktemp -d)}"
build_dir="out"
code_pro_url="https://github.com/adobe-fonts/source-code-pro/releases/download/2.038R-ro%2F1.058R-it%2F1.018R-VAR/OTF-source-code-pro-2.038R-ro-1.058R-it.zip"
code_pro_src_file="SourceCodePro-Regular.otf"
code_pro_dst_file="SourceCodePro.otf"
han_url="https://github.com/adobe-fonts/source-han-serif/raw/release/SubsetOTF/SourceHanSerifJP.zip"
han_src_file="SourceHanSerifJP/SourceHanSerifJP-Regular.otf"
han_dst_file="SourceHanSerif.otf"
han_kr_url="https://github.com/adobe-fonts/source-han-serif/raw/release/SubsetOTF/SourceHanSerifKR.zip"
han_kr_src_file="SourceHanSerifKR/SourceHanSerifKR-Regular.otf"
han_kr_dst_file="SourceHanSerifKR.otf"
hanamin_url="https://github.com/bellkev/glyphwiki-afdko/releases/download/2021-07-12/HanaMin.zip"
hanamin_src_file="HanaMin/HanaMinA.otf"
hanamin_dst_file="HanaMinA.otf"
blocks_url="https://www.unicode.org/Public/UNIDATA/Blocks.txt"

# Args: url, src-file, dst-file
fetch_and_unzip() {
  zip_name="$(basename $1)"
  if [[ ! -f $temp_dir/$zip_name ]]; then
    echo "Fetching $zip_name..."
    curl -L -o "$temp_dir/$zip_name" "$1"
    unzip -q "$temp_dir/$zip_name" -d "$temp_dir"
  fi
  cp "$temp_dir/$2" "$build_dir/$3"
}

# Args: alias-file-name, block-file-name, cmap-file-name...
generate_alias_file() {
  (cd "$build_dir" && ../mapping.py "../$2" "${@:3}" > "$1")
}

mkdir -p "$build_dir"
fetch_and_unzip "$code_pro_url" "$code_pro_src_file" "$code_pro_dst_file"
fetch_and_unzip "$han_url" "$han_src_file" "$han_dst_file"
fetch_and_unzip "$han_kr_url" "$han_kr_src_file" "$han_kr_dst_file"
fetch_and_unzip "$hanamin_url" "$hanamin_src_file" "$hanamin_dst_file"
fetch_and_unzip "$hanamin_url" HanaMin/HanaMinA.cmap HanaMinA.cmap

echo "Extracting cmap tables from source fonts..."
for f in "$code_pro_dst_file" "$han_dst_file" "$han_kr_dst_file" HanaMinA.otf; do
  ttx -q -t cmap -o "$build_dir/${f}.cmap" "$build_dir/$f"
done

echo "Fetching Blocks.txt..."
curl -L -o "$build_dir/Blocks.txt" "$blocks_url"

echo "Generating glyph alias files..."
generate_alias_file hanamin_alias hanamin_blocks HanaMinA.otf.cmap
echo '0 0' >> "$build_dir/hanamin_alias"
generate_alias_file code_pro_alias code_pro_blocks \
  HanaMinA.otf.cmap "${code_pro_dst_file}.cmap"
generate_alias_file han_alias han_blocks \
  HanaMinA.otf.cmap "${han_dst_file}.cmap"
generate_alias_file han_kr_alias han_kr_blocks \
  HanaMinA.otf.cmap "${han_kr_dst_file}.cmap"

echo "Merging fonts..."
(
  cd "$build_dir"
  mergefonts -cid ../KageConsole.cidinfo KageConsoleA.raw \
    hanamin_alias HanaMinA.otf \
    code_pro_alias "$code_pro_dst_file" \
    han_alias "$han_dst_file" \
    han_kr_alias "$han_kr_dst_file"
)

echo "Building final OTF font..."
makeotf -ch "$build_dir/HanaMinA.cmap" \
  -f "$build_dir/KageConsoleA.raw" \
  -o "$build_dir/KageConsoleA.otf"
