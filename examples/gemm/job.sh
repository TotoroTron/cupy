#!/bin/bash

# https://slurm.schedmd.com/sbatch.html 

# CREATE A NEW LOG DIRECTORY BASED ON PYTHON FILE EXECUTED
# USAGE: ./job.sh filename.py amarel/local
# OR: bash job.sh filename.py amarel/local

# conda env export > "environment.yml"

# CHECK IF FILENAME AND ENVIRONMENT PROVIDED
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Python filename or environment not provided. Exiting."
    exit 1
fi

# EXTRACT THE FILENAME WITHOUT EXTENSION
filename=$(basename -- "$1")
filename="${filename%.*}"

# SET THE ENVIRONMENT
environment="$2"

# CREATE DIRECTORY IF DOESNT EXIST
log_dir="logs/logs_$filename"
mkdir -p "$log_dir"

log_old_dir="$log_dir/old"
mkdir -p "$log_old_dir"

# FIND AND COUNT THE NUMBER OF FILES
file_count=$(ls -1t "$log_dir" | wc -l)
# -1 : one per line, -t : sort by modification time
# wc : word count, -l : line count instead

# IF MORE THAN 6 FILES, MOVE ALL EXCEPT NEWEST 6 TO 'old'
if [ "$file_count" -gt 6 ]; then # -gt 6 : greater than 6
    files_to_move=$(($file_count - 6))

    # List the oldest files and move them to the 'old' subdirectory
    ls -1t "$log_dir" | tail -n "$files_to_move" | while read file; do
        # ls -1 lists one file per line, -t sort by modification time
        # tail (opposite of head) -n <number of lines>
        # loop: read a line from tail into $file
        mv "${log_dir}/${file}" "$log_old_dir"
    done
fi

# SET OUTPUT/ERROR FILE PATHS
output_file="$log_dir/slurm.%j.%N.out"
error_file="$log_dir/slurm.%j.%N.err"

# CALL SBATCH WITH OUTPUT/ERROR FILE PATHS
# PASS IN SLURM SCRIPT AS HERE-DOC
# command --args --args <<DELIMITER (text text) DELIMITER
if [ "$environment" == "amarel" ]; then
    sbatch --output="$output_file" --error="$error_file" <<EOF
#!/bin/bash
#SBATCH --job-name=tutorial
##SBATCH --partition=main
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
##SBATCH --exclude=cuda[001-008]
#SBATCH --ntasks=1
#SBATCH --mem=16000
#SBATCH --time=04:00:00


module purge
module load cuda/11.7.1
source /home/bbc33/anaconda3/bin/activate
conda activate /home/bbc33/anaconda3/envs/cupy

python3 $1
EOF
elif [ "$environment" == "local" ]; then
    # Unique ID number using timestamp in nanoseconds
    id_number=$(date +%s%N)
    # date: display current date and time
    # +%s number of seconds since Unix epoch
    # %N number of nanoseconds

    output_file="$log_dir/bash.${id_number}.local.out"
    error_file="$log_dir/bash.${id_number}.local.err"
    python3 $1 > "$output_file" 2> "$error_file"
else
    echo "Error: Unknown environment specified. Use 'amarel' or 'local'."
    exit 1
fi
