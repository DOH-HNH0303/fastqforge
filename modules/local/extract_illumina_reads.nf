process EXTRACT_ILLUMINA_READS {
    publishDir params.outdir, mode: 'copy'

    input:
    path ont_samplesheet
    path meta_fastq_csv
    val runid
    
    output:
    path 'illumina_reads.csv'
    
    script:
    """
    #!/usr/bin/env python3
    
    import sys
    from collections import defaultdict
    import re
    import pandas as pd
    import numpy as np
    

    ############################
    def id_basename(sample_id, delimiter='-'):
        escaped_delim = re.escape(delimiter)
        pattern = rf"(?<![A-Za-z]){escaped_delim}"
        sample = re.split(pattern, sample_id)[0]
        return sample
 

    df = pd.read_csv('${ont_samplesheet}')
    ont_sample = df['sample'].tolist()
    df['sample_clean'] = df['sample'].apply(lambda x: id_basename(x))
    ont_samples = df['sample_clean'].tolist()


    illumina_reads = defaultdict(lambda: {'R1': None, 'R2': None})
    meta_fastq = pd.read_csv('${meta_fastq_csv}')    

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

    illumina.index.name = "sample"
    illumina = illumina.reset_index()

    # Rename columns to match your desired output
    illumina = illumina.rename(columns={"R1": "fastq_1", "R2": "fastq_2"})

    run_id = []
    for i in illumina['fastq_1'].tolist():
        print(i)
        #print(meta_fastq.columns)
        run_id.append(meta_fastq.loc[meta_fastq['current'] == i, 'run'].tolist()[0])
    illumina['illumina_run_id'] = run_id

    # Emit warnings for missing pairs
    missing_r1 = illumina[illumina["fastq_1"].isna() & illumina["fastq_2"].notna()]
    missing_r2 = illumina[illumina["fastq_2"].isna() & illumina["fastq_1"].notna()]

    

    for sample in missing_r1["sample"]:
        print(f"WARNING: Sample {sample} has R2 but missing R1", file=sys.stderr)

    for sample in missing_r2["sample"]:
        print(f"WARNING: Sample {sample} has R1 but missing R2", file=sys.stderr)

    illumina.to_csv("illumina_reads.csv", sep=",", index=False)

    
    # Count matched samples
    matched_count = len(illumina_reads)
    print(f"\\nMatched {matched_count} samples with Illumina reads")
    
    if matched_count == 0:
        print("WARNING: No matching Illumina reads found for any ONT samples", file=sys.stderr)
    
    # Display preview
    print(f'matched {len(illumina)}) illumina reads to ont')
    """
}
