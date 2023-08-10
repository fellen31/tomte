//
// ANALYSE TRANSCRITPS
//

 include { STRINGTIE_STRINGTIE } from '../../modules/nf-core/stringtie/stringtie/main'
 include { GFFCOMPARE          } from '../../modules/nf-core/gffcompare/main'
 include { DROP_COUNTS         } from '../../modules/local/drop_counts'
 //include { DROP_ANNOTATION     } from '../../modules/local/drop_sample_annot'
 include { DROP_SAMPLE_ANNOT   } from '../../modules/local/drop_sample_annot'
 include { DROP_CONFIG_RUN_AE  } from '../../modules/local/drop_config_runAE'

workflow ANALYSE_TRANSCRIPTS {
    take:
        ch_bam               // channel (mandatory): [ val(meta), [ path(bam) ] ]
        ch_gtf               // channel (mandatory): [ path(gtf) ]
        ch_fasta_fai_meta    // channel (mandatory): [ val(meta), [ path(fasta), path(fai) ]
        gene_counts          // channel [val(meta), path(tsv)] 
        reference_count_file // channel [ path(tsv) ]
        ref_annot_file       // channel [ path(tsv) ]
        ref_splice_folder    // channel [ path(folder) ]

    main:
        ch_versions = Channel.empty()

        // DROP
        // Generates count files for samples and merges them with reference count file
        star_count = gene_counts.map{ meta, cnt_file -> cnt_file }.collect()
        star_samp  = gene_counts.map{ meta, cnt_file -> meta }.collect()
        DROP_COUNTS(star_count, star_samp, ch_gtf, reference_count_file)
        ch_drop_counts = DROP_COUNTS.out.processed_gene_counts.collect()
        
        // Generates sample annotation
        ch_bam_files = ch_bam.map{ meta, bam -> bam }.collect()
        DROP_SAMPLE_ANNOT(
            ch_bam_files,
            star_samp,
            ch_drop_counts,
            ref_annot_file,
            ch_gtf
            )

        // Generates  config file and runs Aberrant expression module
        DROP_CONFIG_RUN_AE(
            ch_fasta_fai_meta, 
            ch_gtf, 
            DROP_SAMPLE_ANNOT.out.drop_annot,
            ch_drop_counts
        )
        
        // Generates  config file and runs Aberrant splicing module
        //DROP_CONFIG_RUN_AS(
        //    ch_fasta_fai_meta, 
        //    ch_gtf, 
        //    DROP_SAMPLE_ANNOT.out.drop_annot,
        //    ref_splice_folder
        //)

        // Stringtie
        STRINGTIE_STRINGTIE(
            ch_bam,
            ch_gtf
        )

        // Compare stringtie results to reference
        GFFCOMPARE(
            STRINGTIE_STRINGTIE.out.transcript_gtf,
            ch_fasta_fai_meta,
            ch_gtf.map{ gtf -> [ [id:gtf.simpleName], gtf ] }
        )

        ch_versions = ch_versions.mix(DROP_COUNTS.out.versions)
        ch_versions = ch_versions.mix(DROP_SAMPLE_ANNOT.out.versions)
        ch_versions = ch_versions.mix(DROP_CONFIG_RUN_AE.out.versions)
        ch_versions = ch_versions.mix(STRINGTIE_STRINGTIE.out.versions.first())
        ch_versions = ch_versions.mix(GFFCOMPARE.out.versions.first())

    emit:
        transcript_gtf        = STRINGTIE_STRINGTIE.out.transcript_gtf     // channel: [ val(meta), [ path(transctript_gtf)] ]
        abundance             = STRINGTIE_STRINGTIE.out.abundance          // channel: [ val(meta), [ path(abundance) ] ]
        coverage_gtf          = STRINGTIE_STRINGTIE.out.coverage_gtf       // channel: [ val(meta), [ path(coverage_gtf) ] ]
        annotated_gtf         = GFFCOMPARE.out.annotated_gtf               // channel: [ val(meta), [ path(annotated_gtf) ] ]
        stats_gtf             = GFFCOMPARE.out.stats                       // channel: [ val(meta), [ path(stats) ] ]
        processed_gene_counts = DROP_COUNTS.out.processed_gene_counts      // channel: [ path(tsv) ]
        annotation_drop       = DROP_SAMPLE_ANNOT.out.drop_annot           // channel: [ path(sample_annotation.tsv) ]
        config_drop           = DROP_CONFIG_RUN_AE.out.config_drop         // channel: [ path(confg_file.yml) ]
        drop_ae_out           = DROP_CONFIG_RUN_AE.out.drop_ae_out
        versions              = ch_versions                                // channel: [ path(versions.yml) ]
}
