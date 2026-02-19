process CREATE_ONT_SAMPLESHEET {
    publishDir params.outdir, mode: 'copy', enabled: !params.paired_illumina_reads
    
    input:
    val runid
    val ont_bucket
    
    output:
    path 'ont_samplesheet.csv'
    
    script:
    """
    #!/bin/bash
    set -euo pipefail
    
    runid="${runid}"
    ont_bucket="${ont_bucket}"
    
    # Construct the search path
    search_path="\${ont_bucket}/\${runid}/reads/"
    
    echo "Searching for ONT FASTQ files in: \${search_path}"
    
    # Check if this is an S3 path
    if [[ "\${ont_bucket}" == s3://* ]]; then
        # Use AWS CLI to list S3 objects
        echo "Detected S3 path, using AWS CLI..."
        aws s3 ls "\${search_path}" | grep -E ".*-\${runid}\\.fastq\\.gz\$" | awk '{print \$NF}' > filelist.txt || true
        
        if [ ! -s filelist.txt ]; then
            echo "ERROR: No FASTQ files found matching pattern: *-\${runid}.fastq.gz in \${search_path}"
            exit 1
        fi
        
        # Create samplesheet with S3 paths (CSV format)
        echo "sample,sample_id,fastq" > ont_samplesheet.csv
        while IFS= read -r filename; do
            # Extract sample ID (everything before -runid.fastq.gz)
            sample_id=\$(echo "\${filename}" | sed -E "s/-\${runid}\\.fastq\\.gz\$//")
            sample="\${sample_id}-\${runid}"
            full_path="\${search_path}\${filename}"
            echo "\${sample},\${sample_id},\${full_path}" >> ont_samplesheet.csv
        done < filelist.txt
        
    elif [[ "\${ont_bucket}" == gs://* ]]; then
        # Use gsutil for Google Cloud Storage
        echo "Detected GCS path, using gsutil..."
        gsutil ls "\${search_path}*-\${runid}.fastq.gz" | sed 's|.*/||' > filelist.txt || true
        
        if [ ! -s filelist.txt ]; then
            echo "ERROR: No FASTQ files found matching pattern: *-\${runid}.fastq.gz in \${search_path}"
            exit 1
        fi
        
        # Create samplesheet with GCS paths (CSV format)
        echo "sample,sample_id,fastq" > ont_samplesheet.csv
        while IFS= read -r filename; do
            sample_id=\$(echo "\${filename}" | sed -E "s/-\${runid}\\.fastq\\.gz\$//")
            sample="\${sample_id}-\${runid}"
            full_path="\${search_path}\${filename}"
            echo "\${sample},\${sample_id},\${full_path}" >> ont_samplesheet.csv
        done < filelist.txt
        
    else
        # Local filesystem
        echo "Using local filesystem..."
        find "\${search_path}" -maxdepth 1 -name "*-\${runid}.fastq.gz" -type f > filelist.txt || true
        
        if [ ! -s filelist.txt ]; then
            echo "ERROR: No FASTQ files found matching pattern: *-\${runid}.fastq.gz in \${search_path}"
            exit 1
        fi
        
        # Create samplesheet with full local paths (CSV format)
        echo "sample,sample_id,fastq" > ont_samplesheet.csv
        while IFS= read -r filepath; do
            filename=\$(basename "\${filepath}")
            sample_id=\$(echo "\${filename}" | sed -E "s/-\${runid}\\.fastq\\.gz\$//")
            sample="\${sample_id}-\${runid}"
            echo "\${sample},\${sample_id},\${filepath}" >> ont_samplesheet.csv
        done < filelist.txt
    fi
    
    # Count samples (FIXED: was referencing .tsv instead of .csv)
    sample_count=\$(tail -n +2 ont_samplesheet.csv | wc -l)
    echo "Created ONT samplesheet with \${sample_count} samples"
    
    # Display the samplesheet
    echo ""
    echo "=== ONT Samplesheet Preview ==="
    head -n 10 ont_samplesheet.csv
    if [ \${sample_count} -gt 9 ]; then
        echo "... (\${sample_count} total samples)"
    fi
    """
}
