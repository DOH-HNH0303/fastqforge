process MERGE_SAMPLESHEETS {
    publishDir params.outdir, mode: 'copy'
    
    input:
    path ont_samplesheet
    path illumina_reads
    
    output:
    path 'samplesheet.csv'
    
    script:
    """
    #!/usr/bin/env python3
    
import csv
import pandas as pd
import re


# Functions
def id_basename(sample_id, delimiter='-'):
    escaped_delim = re.escape(delimiter)
    pattern = rf"(?<![A-Za-z]){escaped_delim}"
    sample = re.split(pattern, sample_id)[0]
    return sample

# Read ONT samplesheet
ont = pd.read_csv(${ont_samplesheet})
ont['sample_ont'] = ont['sample']
len_ont = len(ont['sample'])
ont['sample'] = ont['sample'].apply(lambda x: id_basename(x))


# Read Illumina reads
illumina = pd.read_csv(${illumina_reads})
illumina['sample_illumina'] = illumina['sample']
len_illumina= len(illumina['sample'])
illumina['sample'] = illumina['sample'].apply(lambda x: id_basename(x))


# Merge and write output
merged = ont.merge(illumina, on="sample", how="outer")
merged['basename'] = merged['sample']
merged['sample'] = merged['sample_ont']+"--" +merged['sample_illumina']
merged = merged.dropna(subset=['fastq_2'])
unique_ont = len(set(merged['sample_ont'].tolist()))
merged = merged[['sample', 'fastq', 'fastq_1', 'fastq_2']]
merged.to_csv('samplesheet.csv', index=False)


# Display result
print( f"\nCreated merged samplesheet with {len(merged['sample'])} samples")
print(f"  - ONT reads: {unique_ont}/{len_ont} sample(s) are paired with illumina reads")
print(f"  - Illumina reads: {len_illumina} sample(s) are paired with ont reads")

    """
}
