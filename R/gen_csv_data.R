#' Generate synthetic CSV data
#'
#' @param p number of columns
#' @param n number of rows
#' @param MB size of the data in MB
#' @param sampler function that creates random observations
#' @param prepend_group_column whether to include a 
#' @param group_probs
#' @param ... arguments to \code{data.table:::fwrite}
#'
gen_csv_data = function(p, n
                        , fname = "~/data/r_data_benchmarks/data.csv"
                        , MB = 100
                        , sampler = runif
                        , group_probs = rep(0.1, 10)
                        , prepend_group_column = TRUE
                        , ...)
{
}
