#!/usr/bin/env python3

import sys
from collections import defaultdict
import re
import pandas as pd
import numpy as np


def id_basename(sample_id, delimiter='-'):
    print(sample_id)

    #sample = re.split(r'(?<=[A-Za-z])-', sample_id)[0]
    escaped_delim = re.escape(delimiter)
    pattern = rf"(?<![A-Za-z]){escaped_delim}"
    sample = re.split(pattern, sample_id)[0]
    print(sample)
    return sample

modifier = True
# Read ONT samplesheet to get sample IDs
#ont_samples = set()
df = pd.read_csv('results/ont_samplesheet_old.csv')
print(df.columns)
ont_sample = df['sample'].tolist()
df['sample_clean'] = df['sample'].apply(lambda x: id_basename(x))
ont_samples = df['sample_clean'].tolist()
# with open('results/ont_samplesheet_old.csv', 'r') as f:
#     reader = csv.DictReader(f, delimiter='\t')
#     for row in reader:
#         ont_samples.add(row['sample'])

print(f"Found {len(ont_samples)} ONT samples: {sorted(ont_samples)}")

# Read meta.fastq.csv and find matching Illumina reads
# Group R1 and R2 by sample ID
illumina_reads = defaultdict(lambda: {'R1': None, 'R2': None})
meta_fastq = pd.read_csv('/mnt/c/Users/HNH0303/Downloads/meta.fastq.csv')
#if not set(ont_samples).issubset(meta_fastq[id_alt])


illumina = (
    meta_fastq
    .assign(
        id_alt=lambda df: df['id_alt'].str.strip(),
        current=lambda df: df['current'].str.strip(),
        file=lambda df: df['file'].str.strip(),
        read=lambda df: np.select(
            [
                df['file'].str.contains('_R1.fastq.gz|_R1_001.fastq.gz'),
                df['file'].str.contains('_R2.fastq.gz|_R2_001.fastq.gz')
            ],
            ['R1', 'R2'],
            default=''
        )
    )
    .query("id_alt in @ont_samples and current != '' and read != ''")
    .pivot_table(index='id_alt', columns='read', values='current', aggfunc='first')
    .reindex(columns=['R1', 'R2'])
)

illumina_reads = illumina.to_dict(orient='index')
print(illumina_reads)
#exit(1)

# with open('/mnt/c/Users/HNH0303/Downloads/meta.fastq.csv', 'r') as f:
#     reader = csv.DictReader(f)
    
#     for row in reader:
#         id_alt = row.get('id_alt', '').strip()
#         current_path = row.get('current', '').strip()
#         file_name = row.get('file', '').strip()
        
#         # Check if this sample is in our ONT samples
#         if id_alt in ont_samples and current_path:
#             # Determine if this is R1 or R2
#             if '_R1.fastq.gz' in file_name or '_R1_001.fastq.gz' in file_name:
#                 illumina_reads[id_alt]['R1'] = current_path
#             elif '_R2.fastq.gz' in file_name or '_R2_001.fastq.gz' in file_name:
#                 illumina_reads[id_alt]['R2'] = current_path


import pandas as pd
import sys

# Convert illumina_reads dict → DataFrame
#df = pd.DataFrame.from_dict(illumina_reads, orient='index')
illumina.index.name = "sample"
illumina = illumina.reset_index()

# Rename columns to match your desired output
illumina = illumina.rename(columns={"R1": "fastq_1", "R2": "fastq_2"})

# Emit warnings for missing pairs
missing_r1 = illumina[illumina["fastq_1"].isna() & illumina["fastq_2"].notna()]
missing_r2 = illumina[illumina["fastq_2"].isna() & illumina["fastq_1"].notna()]

for sample in missing_r1["sample"]:
    print(f"WARNING: Sample {sample} has R2 but missing R1", file=sys.stderr)

for sample in missing_r2["sample"]:
    print(f"WARNING: Sample {sample} has R1 but missing R2", file=sys.stderr)

# Write comma-separated CSV
illumina.to_csv("illumina_reads.csv", sep=",", index=False)


# Write output CSV with paired reads
# with open('illumina_reads.csv', 'w') as f:
#     f.write("sample\tfastq_1\tfastq_2\n")
    
#     for sample_id in sorted(illumina_reads.keys()):
#         r1 = illumina_reads[sample_id]['R1']
#         r2 = illumina_reads[sample_id]['R2']
        
#         if r1 and r2:
#             f.write(f"{sample_id}\t{r1}\t{r2}\n")
#         elif r1:
#             print(f"WARNING: Sample {sample_id} has R1 but missing R2", file=sys.stderr)
#             f.write(f"{sample_id}\t{r1}\t\n")
#         elif r2:
#             print(f"WARNING: Sample {sample_id} has R2 but missing R1", file=sys.stderr)
#             f.write(f"{sample_id}\t\t{r2}\n")

# Count matched samples
matched_count = len(illumina_reads)
print(f"\nMatched {matched_count} samples with Illumina reads")

if matched_count == 0:
    print("WARNING: No matching Illumina reads found for any ONT samples", file=sys.stderr)

# Display preview
print("\n=== Illumina Reads Preview ===")
with open('illumina_reads.csv', 'r') as f:
    for i, line in enumerate(f):
        if i < 10:
            print(line.rstrip())
        else:
            break
    if matched_count > 9:
        print(f"... ({matched_count} total samples)")