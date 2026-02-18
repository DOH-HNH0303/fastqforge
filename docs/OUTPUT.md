# fastqforge Output Documentation

This document describes all outputs produced by the fastqforge pipeline.

## Table of Contents

- [Pipeline Outputs](#pipeline-outputs)
- [Output Files by Mode](#output-files-by-mode)
- [Pipeline Reports](#pipeline-reports)
- [Using Output Files](#using-output-files)

## Pipeline Outputs

All outputs are written to the directory specified by `--outdir` (default: `results/`).

### Directory Structure

#### ONT-only Mode
```
results/
├── ont_samplesheet.csv          # Main output: ONT samplesheet
└── pipeline_info/                # Execution reports
    ├── execution_report_*.html
    ├── execution_timeline_*.html
    ├── execution_trace_*.txt
    └── pipeline_dag_*.html
```

#### Hybrid Mode
```
results/
├── ont_samplesheet.csv           # ONT samples only
├── illumina_reads.csv            # Illumina paired reads matched to ONT samples
├── samplesheet.csv               # Main output: Merged samplesheet
└── pipeline_info/                 # Execution reports
    ├── execution_report_*.html
    ├── execution_timeline_*.html
    ├── execution_trace_*.txt
    └── pipeline_dag_*.html
```

## Output Files by Mode

### ONT-only Mode

#### `ont_samplesheet.csv`

**Description:** CSV samplesheet containing ONT sample names and FASTQ file paths.

**Format:**
```csv
sample,fastq
sample001-20240215_run01,s3://bucket/path/sample001-20240215_run01.fastq.gz
sample002-20240215_run01,s3://bucket/path/sample002-20240215_run01.fastq.gz
sample003-20240215_run01,s3://bucket/path/sample003-20240215_run01.fastq.gz
```

**Columns:**
- `sample`: Sample identifier extracted from FASTQ filename (format: `<id>-<runid>`)
- `fastq`: Full path to ONT FASTQ file (S3, GCS, or local path)

**Use cases:**
- Input for nf-core/nanoseq
- Input for nf-core/rnaseq (ONT mode)
- Input for custom ONT analysis pipelines
- Input for de novo genome assembly workflows

**Example usage with nf-core/nanoseq:**
```bash
nextflow run nf-core/nanoseq \
   -profile docker \
   --input results/ont_samplesheet.csv \
   --protocol DNA \
   --outdir nanoseq_results
```

### Hybrid Mode

#### `ont_samplesheet.csv`

Same as ONT-only mode output. Contains only ONT samples.

#### `illumina_reads.csv`

**Description:** CSV file containing Illumina paired-end reads matched to ONT sample basenames.

**Format:**
```csv
sample,fastq_1,fastq_2
sample001,s3://bucket/illumina/sample001_R1_001.fastq.gz,s3://bucket/illumina/sample001_R2_001.fastq.gz
sample002,s3://bucket/illumina/sample002_R1_001.fastq.gz,s3://bucket/illumina/sample002_R2_001.fastq.gz
```

**Columns:**
- `sample`: Sample basename (extracted from ONT sample by splitting on first hyphen)
- `fastq_1`: Path to Illumina R1 (forward) reads
- `fastq_2`: Path to Illumina R2 (reverse) reads

**Notes:**
- Only samples with both R1 and R2 reads are included in the final merged samplesheet
- Warnings are emitted for samples with incomplete pairs (R1 without R2 or vice versa)

#### `samplesheet.csv` (Main Output)

**Description:** Merged samplesheet combining ONT long reads with Illumina paired-end reads for each sample.

**Format:**
```csv
sample,fastq,fastq_1,fastq_2
sample001-20240215_run01--sample001,s3://bucket/ont/sample001-20240215_run01.fastq.gz,s3://bucket/illumina/sample001_R1_001.fastq.gz,s3://bucket/illumina/sample001_R2_001.fastq.gz
sample002-20240215_run01--sample002,s3://bucket/ont/sample002-20240215_run01.fastq.gz,s3://bucket/illumina/sample002_R1_001.fastq.gz,s3://bucket/illumina/sample002_R2_001.fastq.gz
```

**Columns:**
- `sample`: Combined sample identifier (format: `<ont_sample>--<illumina_sample>`)
- `fastq`: Path to ONT long reads
- `fastq_1`: Path to Illumina R1 reads
- `fastq_2`: Path to Illumina R2 reads

**Use cases:**
- Input for Unicycler hybrid assembly
- Input for SPAdes hybrid assembly mode
- Input for custom hybrid assembly workflows
- Polishing long-read assemblies with short reads

**Example usage with Unicycler:**
```bash
# Extract paths from samplesheet for a single sample
SAMPLE_ROW=$(grep "sample001" results/samplesheet.csv)
ONT=$(echo $SAMPLE_ROW | cut -d',' -f2)
R1=$(echo $SAMPLE_ROW | cut -d',' -f3)
R2=$(echo $SAMPLE_ROW | cut -d',' -f4)

# Run Unicycler
unicycler -l $ONT -1 $R1 -2 $R2 -o unicycler_output
```

**Sample matching:**
The pipeline matches ONT and Illumina samples using a basename extraction algorithm:
- ONT sample: `bacterial-isolate-001-20240215_run01` → basename: `bacterial-isolate-001`
- Illumina sample: `bacterial-isolate-001` → matches ONT basename
- Final merged sample: `bacterial-isolate-001-20240215_run01--bacterial-isolate-001`

## Pipeline Reports

All execution reports are stored in `<outdir>/pipeline_info/`.

### `execution_report_*.html`

**Description:** Comprehensive HTML report with pipeline execution statistics.

**Contents:**
- Workflow summary (duration, success/failure status)
- Resource usage by process (CPU, memory, time)
- Task completion rates
- Error summaries (if any)

**Use for:**
- Monitoring pipeline performance
- Identifying resource bottlenecks
- Troubleshooting failed runs

### `execution_timeline_*.html`

**Description:** Visual timeline of all process executions.

**Contents:**
- Gantt chart showing when each task started and completed
- Task duration visualization
- Parallel execution overview

**Use for:**
- Understanding pipeline parallelization
- Identifying slow processes
- Optimizing resource allocation

### `execution_trace_*.txt`

**Description:** Tab-delimited text file with detailed trace of all executed tasks.

**Format:**
```
task_id hash    native_id   name    status  exit    submit  duration    realtime    %cpu    peak_rss    peak_vmem   rchar   wchar
1       a1/b2c3 12345       CREATE_ONT_SAMPLESHEET  COMPLETED   0   2024-02-15 10:15:30 5s  4.5s    95.2%   125 MB  256 MB  1.2 GB  15 MB
```

**Use for:**
- Detailed performance analysis
- Debugging task-specific issues
- Custom reporting and analysis

### `pipeline_dag_*.html`

**Description:** Directed Acyclic Graph (DAG) visualization of the pipeline workflow.

**Contents:**
- Visual representation of process dependencies
- Data flow between processes
- Channel connections

**Use for:**
- Understanding pipeline structure
- Documenting workflow logic
- Identifying data dependencies

## Using Output Files

### Example 1: Counting Samples

```bash
# Count ONT samples (exclude header)
tail -n +2 results/ont_samplesheet.csv | wc -l

# Count hybrid samples
tail -n +2 results/samplesheet.csv | wc -l
```

### Example 2: Extracting Sample Lists

```bash
# Get list of all ONT sample IDs
tail -n +2 results/ont_samplesheet.csv | cut -d',' -f1 > sample_ids.txt

# Get list of all FASTQ paths
tail -n +2 results/ont_samplesheet.csv | cut -d',' -f2 > fastq_paths.txt
```

### Example 3: Validating File Paths

```bash
# Check if S3 paths exist (requires AWS CLI)
while IFS=',' read -r sample fastq; do
    if [ "$sample" != "sample" ]; then  # Skip header
        aws s3 ls "$fastq" && echo "$sample: OK" || echo "$sample: MISSING"
    fi
done < results/ont_samplesheet.csv
```

### Example 4: Converting to Different Format

```bash
# Convert CSV to TSV
sed 's/,/\t/g' results/ont_samplesheet.csv > ont_samplesheet.tsv

# Convert to YAML (requires yq)
cat results/ont_samplesheet.csv | \
    tail -n +2 | \
    awk -F',' '{print "- sample: " $1 "\n  fastq: " $2}' > ont_samplesheet.yaml
```

### Example 5: Filtering Specific Samples

```bash
# Extract specific samples from hybrid samplesheet
grep -E "sample001|sample002" results/samplesheet.csv > selected_samples.csv

# Add header back
(head -n 1 results/samplesheet.csv && grep -E "sample001|sample002" results/samplesheet.csv) > selected_samples.csv
```

### Example 6: Batch Processing with Loop

```bash
# Process each sample from ONT samplesheet
while IFS=',' read -r sample fastq; do
    if [ "$sample" != "sample" ]; then  # Skip header
        echo "Processing $sample"
        # Your analysis command here
        # Example: fastqc $fastq -o qc_results/
    fi
done < results/ont_samplesheet.csv
```

### Example 7: Integration with nf-core Pipelines

#### With nf-core/nanoseq
```bash
nextflow run nf-core/nanoseq \
   -profile docker \
   --input results/ont_samplesheet.csv \
   --protocol DNA \
   --outdir nanoseq_output
```

#### With nf-core/bacass (bacterial assembly)
```bash
nextflow run nf-core/bacass \
   -profile docker \
   --input results/ont_samplesheet.csv \
   --outdir assembly_output
```

## Quality Checks

### Recommended Post-Pipeline Checks

1. **Verify sample count:**
   ```bash
   echo "Expected samples: <count>"
   echo "Found samples: $(tail -n +2 results/ont_samplesheet.csv | wc -l)"
   ```

2. **Check for duplicate samples:**
   ```bash
   cut -d',' -f1 results/ont_samplesheet.csv | sort | uniq -d
   ```

3. **Validate file paths exist:**
   ```bash
   # For S3 paths
   tail -n +2 results/ont_samplesheet.csv | cut -d',' -f2 | while read path; do
       aws s3 ls "$path" > /dev/null 2>&1 || echo "Missing: $path"
   done
   ```

4. **Check for complete Illumina pairs (hybrid mode):**
   ```bash
   # Check for empty fastq_1 or fastq_2 columns
   awk -F',' 'NR>1 && ($3=="" || $4=="") {print "Incomplete pair:", $1}' results/samplesheet.csv
   ```

5. **Verify output format:**
   ```bash
   # Check CSV format (should have no errors)
   csvlint results/ont_samplesheet.csv
   ```

## Troubleshooting Output Issues

### Empty Samplesheet

**Symptom:** Samplesheet has only header row

**Causes:**
- No FASTQ files found matching pattern
- Incorrect `--runid` parameter
- Wrong `--ont_bucket` path

**Solution:**
Check pipeline logs for "ERROR: No FASTQ files found" messages

### Missing Illumina Matches

**Symptom:** `illumina_reads.csv` is empty or has fewer samples than expected

**Causes:**
- Sample ID mismatch between ONT and Illumina data
- Incorrect Illumina metadata CSV format
- Missing R1/R2 pattern in filenames

**Solution:**
- Verify `id_alt` column matches ONT sample basenames
- Check filename patterns contain `_R1` and `_R2`

### Incomplete Merged Samplesheet

**Symptom:** `samplesheet.csv` has fewer samples than `ont_samplesheet.csv`

**Cause:** Only samples with complete Illumina pairs are included in merged output

**Expected behavior:** Samples without matching Illumina reads are filtered out

**Solution:**
- Check `illumina_reads.csv` to see which samples have Illumina data
- Review warnings in pipeline logs for missing pairs

## Output File Specifications

### File Encoding
- All CSV files use UTF-8 encoding
- Line endings: Unix-style (LF)
- No byte order mark (BOM)

### CSV Format
- Delimiter: comma (`,`)
- Quote character: none (paths contain no special characters)
- Header row: always present
- Empty values: not allowed in final merged samplesheet

### Path Formats
- S3: `s3://bucket-name/path/to/file.fastq.gz`
- GCS: `gs://bucket-name/path/to/file.fastq.gz`
- Local: `/absolute/path/to/file.fastq.gz`

## Further Reading

- [Main README](../README.md)
- [Usage Guide](../USAGE.md)
- [Troubleshooting](../README.md#troubleshooting)
