#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Parameters
params.runid = null
params.ont_bucket = null
params.outdir = 'results'
params.paired_illumina_reads = false
params.fastq_files = null

/*
 * Import modules
 */
include { CREATE_ONT_SAMPLESHEET } from './modules/local/create_ont_samplesheet'
include { EXTRACT_ILLUMINA_READS } from './modules/local/extract_illumina_reads'
include { MERGE_SAMPLESHEETS } from './modules/local/merge_samplesheets'



/*
 * Main workflow
 */
workflow {
    // Validate required parameters
    if (!params.runid) {
        error "ERROR: --runid parameter is required"
    }
    if (!params.ont_bucket) {
        error "ERROR: --ont_bucket parameter is required"
    }
    if (params.paired_illumina_reads && !params.fastq_files) {
        error "ERROR: --fastq_files parameter is required when --paired_illumina_reads is true"
    }
    
    // Create ONT samplesheet
    ont_ch = CREATE_ONT_SAMPLESHEET(
        params.runid,
        params.ont_bucket
    )
    
    if (params.paired_illumina_reads) {
        // Process Illumina reads if requested
        illumina_ch = EXTRACT_ILLUMINA_READS(
            ont_ch,
            params.fastq_files,
            params.runid
        )
        
        // Merge ONT and Illumina samplesheets
        final_ch = MERGE_SAMPLESHEETS(
            ont_ch,
            illumina_ch
        )
        
        final_ch | view { f -> "Final merged samplesheet created: ${f}" }
    } else {
        // ONT only mode - just display the ONT samplesheet
        ont_ch | view { f -> "ONT samplesheet created: ${f}" }
    }
}
