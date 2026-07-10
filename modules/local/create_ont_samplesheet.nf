process CREATE_ONT_SAMPLESHEET {
    publishDir params.outdir, mode: 'copy', enabled: !params.paired_illumina_reads
    
    input:
    val runid
    val ont_bucket
    
    output:
    path 'ont_samplesheet.csv'
    
    script:
    def runid_val = runid
    def bucket_val = ont_bucket
    """
    #!/usr/bin/env python3
    
    import os
    import re
    import subprocess
    import sys
    from pathlib import Path
    import pandas as pd


    def id_basename(sample_id, delimiter='-'):
        pattern = r"^\\d{2}[A-Za-z]{2}\\d{2}"
        if bool(re.match(pattern, sample_id)):
           sample = "-".join(re.split(pattern, sample_id)[0:1])
        else:
            escaped_delim = re.escape(delimiter)
            pattern = rf"(?<![A-Za-z]){escaped_delim}"
            sample = re.split(pattern, sample_id)[0]
        return sample
    
    
    def run_command(cmd, shell=True):
        '''Execute a shell command and return output and return code.'''
        try:
            result = subprocess.run(
                cmd,
                shell=shell,
                capture_output=True,
                text=True,
                check=False
            )
            return result.stdout.strip(), result.returncode
        except Exception as e:
            print(f"Error running command: {cmd}", file=sys.stderr)
            print(f"Exception: {e}", file=sys.stderr)
            return "", 1
    
    
    def extract_sample_id(filename, runid):
        '''Extract sample ID from filename by removing the runid suffix.'''
        pattern = r"-" + re.escape(runid) + r"\\.fastq\\.gz\$"
        sample_id = re.sub(pattern, "", filename)
        return sample_id
    
    
    def list_s3_files(search_path, runid):
        print("Detected S3 path, using AWS CLI...")
        cmd = f"aws s3 ls {search_path}"
        stdout, returncode = run_command(cmd)
        
        if returncode != 0:
            return []
        
        files = []
        pattern = r".*-" + re.escape(runid) + r"\\.fastq\\.gz\$"
        for line in stdout.split('\\n'):
            if line.strip():
                parts = line.split()
                if len(parts) >= 4:
                    filename = parts[-1]
                    if re.match(pattern, filename):
                        files.append(filename)
        
        return files
    
    
    def list_gcs_files(search_path, runid):
        print("Detected GCS path, using gsutil...")
        pattern = f"{search_path}*-{runid}.fastq.gz"
        cmd = f"gsutil ls {pattern}"
        stdout, returncode = run_command(cmd)
        
        if returncode != 0:
            return []
        
        files = []
        for line in stdout.split('\\n'):
            if line.strip():
                filename = line.strip().split('/')[-1]
                files.append(filename)
        
        return files
    
    
    def list_local_files(search_path, runid):
        print("Using local filesystem...")
        pattern = f"*-{runid}.fastq.gz"
        
        search_dir = Path(search_path)
        if not search_dir.exists():
            return []
        
        files = []
        for filepath in search_dir.glob(pattern):
            if filepath.is_file():
                files.append(str(filepath))
        
        return files
    
    
    def create_samplesheet(runid, ont_bucket):
        search_path = f"{ont_bucket}/{runid}/"
        print(f"Searching for ONT FASTQ files in: {search_path}")
        print(search_path)
        files = []
        is_s3 = ont_bucket.startswith('s3://')
        is_gcs = ont_bucket.startswith('gs://')
        
        if is_s3:
            files = list_s3_files(search_path, runid)
        elif is_gcs:
            files = list_gcs_files(search_path, runid)
        else:
            files = list_local_files(search_path, runid)
        
        if not files:
            print(f"ERROR: No FASTQ files found matching pattern: *-{runid}.fastq.gz in {search_path}", file=sys.stderr)
            sys.exit(1)
        
        data = []
        for file_entry in sorted(files):
            if is_s3 or is_gcs:
                filename = file_entry
                full_path = f"{search_path}{filename}"
            else:
                full_path = file_entry
                filename = os.path.basename(file_entry)
            
            sample_id = extract_sample_id(filename, runid)
            sample = f"{sample_id}-{runid}"
            
            data.append({
                'sample': sample,
                'sample_id': sample_id,
                'fastq': full_path
            })
        
        df = pd.DataFrame(data)
        
        output_file = 'ont_samplesheet.csv'
        df.to_csv(output_file, index=False)
        
        sample_count = len(df)
        print(f"\\nCreated ONT samplesheet with {sample_count} samples")
        
        print("\\n=== ONT Samplesheet Preview ===")
        preview_rows = min(10, sample_count)
        print(df.head(preview_rows).to_string(index=False))
        
        if sample_count > 10:
            print(f"\\n... ({sample_count} total samples)")
        
        return output_file
    
    
    if __name__ == "__main__":
        runid = "${runid_val}"
        ont_bucket = "${bucket_val}"
        
        try:
            create_samplesheet(runid, ont_bucket)
        except Exception as e:
            print(f"ERROR: {e}", file=sys.stderr)
            import traceback
            traceback.print_exc()
            sys.exit(1)
    """
}
