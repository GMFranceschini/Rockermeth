#' Infer Differential Methylation Status
#'
#' This function classifies CpG sites as hypo-methylated (1), non-differentially
#' methylated (2) or hyper-methylated (3) using a Heterogeneous Hidden Markov Model (HMM).
#'
#' @param input_signal A numeric vector of AUC scores.
#' @param input_pos An integer vector of chromosomal locations
#' @param auc_sd Standard deviation of AUC signal (genome wide).
#' @param pt_start Transition probability of the HSLM.
#' @param normdist Distance normalization parameter of the HSLM.
#' @param ratiosd Fraction between the standard deviation of AUC values of
#' differentially methylated sites and the total standard deviation of AUC
#' values.
#' @param mu Expected mean (AUC) for hypo-methylated state (1-mu is the
#' expected mean for hyper-methylated state).
#' @param use_trunc Use truncated normal distribution (DEBUGGING
#' ONLY).
#' @return An integer vector of methylation states (1,2,3).
#' @importFrom stats pnorm
#' @export
meth_state_finder <- function(input_signal, input_pos, auc_sd, pt_start,
                              normdist, ratiosd, mu, use_trunc) {
    assertthat::assert_that(all(!is.na(input_signal)))
    assertthat::assert_that(is.numeric(input_signal))
    assertthat::assert_that(length(input_signal) == length(input_pos))

    input_pos <- as.integer(input_pos)

    # 2nd state is fixed (no diff methylation)
    muk <- c(mu, .5, 1-mu)
    sepsilon <- rep(auc_sd * ratiosd, length(muk))
    sepsilon[2] <- auc_sd * (1 - ratiosd)

    KS <- length(muk)
    CovPos <- diff(input_pos)
    CovDist <- CovPos/normdist
    CovDist1 <- log(1 - exp(-CovDist))
    W <- length(input_signal)
    NCov <- length(CovDist)
    if (use_trunc) {
        TruncCoef <- c(pnorm(1, mean = muk[1], sd = sepsilon[1])-pnorm(0, mean = muk[1], sd = sepsilon[1]),
                       pnorm(1, mean = muk[2], sd = sepsilon[2])-pnorm(0, mean = muk[2], sd = sepsilon[2]),
                       pnorm(1, mean = muk[3], sd = sepsilon[3])-pnorm(0, mean = muk[3], sd = sepsilon[3]))
    } else  {
        TruncCoef <- rep(1, 3)
    }

    PT <- log(rep(pt_start, KS))
    P <- matrix(data = 0, nrow = KS, ncol = (KS * NCov))
    emission <- matrix(data = 0, nrow = KS, ncol = W)

    #### Calculates Transition and Emission Probabilities ##
    out <- .Fortran("transemisi", as.vector(muk), as.integer(NCov),
                    as.vector(input_signal), as.integer(KS), as.vector(CovDist1),
                    as.vector(sepsilon), as.integer(W), as.matrix(PT), as.matrix(P),
                    as.matrix(emission), as.vector(TruncCoef))
    P <- out[[9]]
    emission <- out[[10]]

    ##### Viterbi Algorithm ####
    etav <- log(rep(1, KS) * (1/KS))
    psi <- matrix(data = 0, nrow = KS, ncol = W)
    path <- as.integer(rep(0, W))

    out2 <- .Fortran("bioviterbii", as.vector(etav), as.matrix(P),
                     as.matrix(emission), as.integer(W), as.integer(KS), as.vector(path),
                     as.matrix(psi))
    meth_states <- out2[[6]]

    return(meth_states)
}
