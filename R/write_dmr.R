#' Generate files from a set of DMR
#'
#' For a quick visualization using a genome browser like IGV, this function
#' generates [BED](https://bit.ly/1hdVNjA) and [SEG](https://bit.ly/2J2WZdZ)
#' files of statistically significant hyper-methylated and hypo-methylated
#' DMRs.
#'
#' BED files (hyper- and hypo-methylated DMRs separately) report genomic
#' location and fdr (in form of -log10(q)).
#' SEG files report average beta differences between tumor and normal/control
#' samples at each DMR.
#'
#' NOTE: BED files have 0-based coordinates while SEG files have 1-based
#' coordinates.
#'
#' @param dmr_table A data.frame generated by [find_dmrs].
#' @param path A string including absolute or relative path which prefixes are added to
#' ("_hyper.bed", "_hypo.bed", ".seg")
#' @param qvalue_thr A numerical threshold. Report only DMRs with a fdr
#' lower than threshold.
#' @return Nothing. Only saves output tables.
#' @examples
#' \dontrun{
#' auc <- compute_AUC(tumor_example, control_example)
#' dmr_set <- find_dmrs(tumor_example, control_example, auc, reference_example, min_sites = 10)
#' compute_z_scores(tumor_example, control_example, dmr_set,reference_example)
#' write_dmr(dmr_set, "dmr_set")
#' }
#' @importFrom utils write.table
#' @export
write_dmr <- function(dmr_table, path, qvalue_thr = 0.05){
    # check parameters
    assertthat::assert_that(is.data.frame(dmr_table))
    assertthat::assert_that(qvalue_thr > 0)

    dmr_table <- dplyr::filter(dmr_table, fdr < qvalue_thr)
    if (nrow(dmr_table) == 0){
        warning("No DMRs with significant fdr retrieved: no output produced.")
        return(NULL)
    }

    # write bed files
    out_table_bed_hypo <- dmr_table
    out_table_bed_hypo <- dplyr::filter(out_table_bed_hypo, state == 1)
    out_table_bed_hypo <- dplyr::mutate(out_table_bed_hypo, start = start - 1, fdr = -log10(fdr))
    out_table_bed_hypo <- dplyr::select(out_table_bed_hypo, chr, start, end, nsites, fdr)

    out_table_bed_hyper <- dmr_table
    out_table_bed_hyper <- dplyr::filter(out_table_bed_hyper, state == 3)
    out_table_bed_hyper <- dplyr::mutate(out_table_bed_hyper, start = start - 1, fdr = -log10(fdr))
    out_table_bed_hyper <- dplyr::select(out_table_bed_hyper, chr, start, end, nsites, fdr)

    out_table_seg <- dmr_table[, c("chr", "start", "end", "nsites", "mean_beta_diff")]
    out_table_seg <- data.frame(ID = basename(path), out_table_seg)

    write.table(out_table_bed_hyper,
                file = paste0(path.expand(path), "_hyper.bed"),
                sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)
    write.table(out_table_bed_hypo,
                file = paste0(path.expand(path), "_hypo.bed"),
                sep = "\t", quote = FALSE, row.names = FALSE, col.names = FALSE)
    write.table(out_table_seg,
                file = paste0(path.expand(path), ".seg"),
                sep = "\t", quote = FALSE, row.names = FALSE)
}
