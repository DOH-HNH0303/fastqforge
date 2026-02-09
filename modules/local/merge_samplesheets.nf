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
    
    # Read ONT samplesheet
    ont_data = {}
    with open('${ont_samplesheet}', 'r') as f:
        reader = csv.DictReader(f, delimiter='\\t')
        for row in reader:
            ont_data[row['sample']] = row['fastq']
    
    # Read Illumina reads
    illumina_data = {}
    with open('${illumina_reads}', 'r') as f:
        reader = csv.DictReader(f, delimiter='\\t')
        for row in reader:
            illumina_data[row['sample']] = {
                'fastq_1': row.get('fastq_1', ''),
                'fastq_2': row.get('fastq_2', '')
            }
    
    # Merge and write output
    with open('samplesheet.csv', 'w') as f:
        f.write("sample\\tfastq_ont\\tfastq_1\\tfastq_2\\n")
        
        # Get all samples (union of ONT and Illumina)
        all_samples = sorted(set(ont_data.keys()) | set(illumina_data.keys()))
        
        for sample in all_samples:
            ont_path = ont_data.get(sample, '')
            illumina = illumina_data.get(sample, {'fastq_1': '', 'fastq_2': ''})
            
            f.write(f"{sample}\\t{ont_path}\\t{illumina['fastq_1']}\\t{illumina['fastq_2']}\\n")
    
    # Display result
    print("=== Final Merged Samplesheet ===")
    with open('samplesheet.csv', 'r') as f:
        for i, line in enumerate(f):
            if i < 10:
                print(line.rstrip())
            else:
                break
        if len(all_samples) > 9:
            print(f"... ({len(all_samples)} total samples)")
    
    print(f"\\nCreated merged samplesheet with {len(all_samples)} samples")
    print(f"  - ONT reads: {len(ont_data)} samples")
    print(f"  - Illumina reads: {len(illumina_data)} samples")
    """
}
