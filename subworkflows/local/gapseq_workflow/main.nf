/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    GAPSEQ WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Full gapseq metabolic reconstruction workflow with customizable parameters.
    Supports both simplified 'doall' mode and advanced customization via individual
    subworkflows (find, find-transport, draft, medium, fill).

    Workflow selection:
    - If any custom args are provided (gapseq_find_args, gapseq_findtransport_args, etc.),
      the custom workflow is automatically used for full parameter control
    - Otherwise, uses the simplified 'doall' approach (recommended for most users)

    Addresses two key requirements:
    1. Database pre-download to prevent race conditions in parallel execution
    2. Full parameter customization for advanced users
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GAPSEQ_REQUESTDB      } from '../../../modules/nf-core/gapseq/requestdb/main'
include { GAPSEQ_DOALL          } from '../../../modules/nf-core/gapseq/doall/main'
include { GAPSEQ_FIND           } from '../../../modules/nf-core/gapseq/find/main'
include { GAPSEQ_FINDTRANSPORT  } from '../../../modules/nf-core/gapseq/findtransport/main'
include { GAPSEQ_DRAFT          } from '../../../modules/nf-core/gapseq/draft/main'
include { GAPSEQ_MEDIUM         } from '../../../modules/nf-core/gapseq/medium/main'
include { GAPSEQ_FILL           } from '../../../modules/nf-core/gapseq/fill/main'

workflow GAPSEQ_WORKFLOW {

    take:
    ch_genomes       // channel: [ val(meta), path(fasta) ]
    options          // map: gapseq_find_args, gapseq_findtransport_args, gapseq_draft_args,
                     //      gapseq_medium_args, gapseq_fill_args - see workflows/bacmodel.nf

    main:

    ch_versions = Channel.empty()

    // Automatically detect if custom workflow should be used based on parameters
    def use_custom = options.gapseq_find_args || options.gapseq_findtransport_args ||
                     options.gapseq_draft_args || options.gapseq_medium_args || options.gapseq_fill_args

    //
    // Download gapseq reference sequence database once before parallel execution
    // This prevents race conditions when hundreds of reconstructions start simultaneously
    //
    GAPSEQ_REQUESTDB('Bacteria')
    ch_seqdb = GAPSEQ_REQUESTDB.out.db

    // Prepare input channel with medium information.
    // medium_gapseq_csv (a file path) and medium_gapseq (a built-in name like
    // LB/M9) are mutually exclusive per sample: a custom CSV is passed as a
    // file input here, while a built-in name is handled separately via
    // ext.args in doall mode (see conf/modules.config).
    ch_gapseq_input = ch_genomes.map { meta, fasta ->
        if (meta.medium_gapseq && meta.medium_gapseq_csv) {
            error "Sample '${meta.id}': provide either 'medium_gapseq' (a built-in medium name) or 'medium_gapseq_csv' (a custom medium CSV file) in the samplesheet, not both."
        }
        def medium = meta.medium_gapseq_csv ? file(meta.medium_gapseq_csv) : []
        [ meta, fasta, medium ]
    }

    if (use_custom) {
        //
        // Custom workflow: Full control over each gapseq subworkflow
        // Allows advanced users to customize find, find-transport, draft, medium, and fill separately
        //

        // Step 1: Find pathways (uses sequence database)
        ch_find_input = ch_gapseq_input.map { meta, fasta, medium ->
            [ meta, fasta ]
        }
        GAPSEQ_FIND(ch_find_input, ch_seqdb)

        // Step 2: Find transporters (does NOT use sequence database)
        ch_findtransport_input = ch_gapseq_input.map { meta, fasta, medium ->
            [ meta, fasta ]
        }
        GAPSEQ_FINDTRANSPORT(ch_findtransport_input)

        // Step 3: Create draft model (uses results, not sequence database)
        // Combine find and findtransport outputs
        ch_draft_input = GAPSEQ_FIND.out.reactions
            .join(GAPSEQ_FINDTRANSPORT.out.tbl, by: 0)
            .join(GAPSEQ_FIND.out.pathways, by: 0)
        GAPSEQ_DRAFT(ch_draft_input)

        // Step 4: Medium definition (does NOT use sequence database)
        // If the sample provides its own medium file via medium_gapseq_csv, use it as-is
        // (gapseq has no notion of "combining" media - it only lets you add/remove
        // individual compounds on top of its own prediction via -c, so a user-supplied
        // file and the auto-prediction are mutually exclusive per sample).
        // Otherwise, predict the medium with gapseq, optionally tweaking specific
        // compounds via gapseq_medium_args (e.g. '-c "cpd00007:0"').
        ch_medium_branch = GAPSEQ_DRAFT.out.draft
            .join(GAPSEQ_FIND.out.pathways, by: 0)
            .join(ch_gapseq_input.map { meta, fasta, medium -> [ meta, medium ] }, by: 0)
            .branch { meta, draft, pathways, medium ->
                own_medium: !(medium instanceof List)
                    return [ meta, medium ]
                predict_medium: true
                    return [ meta, draft, pathways ]
            }

        GAPSEQ_MEDIUM(ch_medium_branch.predict_medium)

        ch_medium = ch_medium_branch.own_medium.mix(GAPSEQ_MEDIUM.out.medium)

        // Step 5: Gap-filling (does NOT use sequence database)
        ch_fill_input = GAPSEQ_DRAFT.out.draft
            .join(ch_medium, by: 0)
        GAPSEQ_FILL(ch_fill_input)

        // Outputs from custom workflow
        ch_model = GAPSEQ_FILL.out.filled
        ch_xml = GAPSEQ_FILL.out.xml
        ch_pathways = GAPSEQ_FIND.out.pathways
        ch_transporters = GAPSEQ_FINDTRANSPORT.out.tbl

    } else {
        //
        // Simplified workflow: Use gapseq doall (uses sequence database)
        // Recommended for most users - runs entire pipeline in one step
        //
        ch_doall_input = ch_gapseq_input

        GAPSEQ_DOALL(ch_doall_input, ch_seqdb)

        // Outputs from doall workflow
        ch_model = GAPSEQ_DOALL.out.model
        ch_xml = GAPSEQ_DOALL.out.xml
        ch_pathways = GAPSEQ_DOALL.out.tbl.map { meta, tbl_files ->
            // tbl_files may be a single path or a list; normalise to list
            def files = tbl_files instanceof List ? tbl_files : [ tbl_files ]
            def pathways_tbl = files.find { it.name.contains('Pathways') }
            [ meta, pathways_tbl ]
        }
        ch_transporters = GAPSEQ_DOALL.out.tbl.map { meta, tbl_files ->
            def files = tbl_files instanceof List ? tbl_files : [ tbl_files ]
            def transport_tbl = files.find { it.name.contains('Transporter') }
            [ meta, transport_tbl ]
        }
    }

    emit:
    model        = ch_model        // channel: [ val(meta), path(RDS) ]
    xml          = ch_xml          // channel: [ val(meta), path(xml) ]
    pathways     = ch_pathways     // channel: [ val(meta), path(tbl) ]
    transporters = ch_transporters // channel: [ val(meta), path(tbl) ]
    versions     = ch_versions     // channel: [ path(versions.yml) ]
}
