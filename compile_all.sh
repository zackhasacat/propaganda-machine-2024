#!/bin/bash

for input_file in *; do
    if [[ -f $input_file && $input_file == *.map ]]; then
        base_name=$(basename "$input_file" .${input_file##*.})

        output_file="${base_name}.omwaddon"

        echo "Compiling" $(pwd)/$input_file "into" $output_file

        morrobroom --map "$(pwd)/$input_file" --scale 3.0 --out ./$output_file

    fi
done

first_file=""
previous_file=""

for file in *.omwaddon; do
    if [ -z "$first_file" ]; then
        first_file="$file"
        previous_file="$file"
    else
        echo "Merging categorical map output"
        merge_to_master "$previous_file" "$file"
        cat merge_to_master.log | sort && rm "$previous_file" merge_to_master.log

        previous_file="$file"
    fi
done
