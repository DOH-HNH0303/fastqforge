process EXTRACT_ILLUMINA_READS {
    input:
    path ont_samplesheet
    path meta_fastq_csv
    val runid
    
    output:
    path 'illumina_reads.csv'
    
    script:
    """
    #!/usr/bin/env python3
    
    import csv
    import sys
    from collections import defaultdict
    
    # Read ONT samplesheet to get sample IDs
    ont_samples = set()
    with open('${ont_samplesheet}', 'r') as f:
        reader = csv.DictReader(f, delimiter='\\t')
        for row in reader:
            ont_samples.add(row['sample'])
    
    print(f"Found {len(ont_samples)} ONT samples: {sorted(ont_samples)}")
    
    # Read meta.fastq.csv and find matching Illumina reads
    # Group R1 and R2 by sample ID
    illumina_reads = defaultdict(lambda: {'R1': None, 'R2': None})
    
    with open('${meta_fastq_csv}', 'r') as f:
        reader = csv.DictReader(f, delimiter='\\t')
        
        for row in reader:
            id_alt = row.get('id_alt', '').strip()
            current_path = row.get('current', '').strip()
            file_name = row.get('file', '').strip()
            
            # Check if this sample is in our ONT samples
            if id_alt in ont_samples and current_path:
                # Determine if this is R1 or R2
                if '_R1.fastq.gz' in file_name or '_R1_001.fastq.gz' in file_name:
                    illumina_reads[id_alt]['R1'] = current_path
                elif '_R2.fastq.gz' in file_name or '_R2_001.fastq.gz' in file_name:
                    illumina_reads[id_alt]['R2'] = current_path
    
    # Write output CSV with paired reads
    with open('illumina_reads.csv', 'w') as f:
        f.write("sample\\tfastq_1\\tfastq_2\\n")
        
        for sample_id in sorted(illumina_reads.keys()):
            r1 = illumina_reads[sample_id]['R1']
            r2 = illumina_reads[sample_id]['R2']
            
            if r1 and r2:
                f.write(f"{sample_id}\\t{r1}\\t{r2}\\n")
            elif r1:
                print(f"WARNING: Sample {sample_id} has R1 but missing R2", file=sys.stderr)
                f.write(f"{sample_id}\\t{r1}\\t\\n")
            elif r2:
                print(f"WARNING: Sample {sample_id} has R2 but missing R1", file=sys.stderr)
                f.write(f"{sample_id}\\t\\t{r2}\\n")
    
    # Count matched samples
    matched_count = len(illumina_reads)
    print(f"\\nMatched {matched_count} samples with Illumina reads")
    
    if matched_count == 0:
        print("WARNING: No matching Illumina reads found for any ONT samples", file=sys.stderr)
    
    # Display preview
    print("\\n=== Illumina Reads Preview ===")
    with open('illumina_reads.csv', 'r') as f:
        for i, line in enumerate(f):
            if i < 10:
                print(line.rstrip())
            else:
                break
        if matched_count > 9:
            print(f"... ({matched_count} total samples)")
    """
}
