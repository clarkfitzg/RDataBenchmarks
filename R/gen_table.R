#' Generate synthetic tabular data
#'
#' @param n number of rows. Specify only one of n or MB.
#' @param p number of columns
#' @param fname name of the file to save
#' @param MB size of the data in MB. An integer group column will make this a little smaller.
#' @param sampler function that creates random observations
#' @param prepend_group_column whether to include a 
#' @param group_probs
#' @param writer function to save generated data. Must have signature (data, fname, ...)
#' @param ... arguments to writer
#' @return d generated data that was written to fname
gen_table = function(n, p = 10
                        , fname = default_csv_file()
                        , MB = 100
                        , sampler = function(n) signif(runif(n))
                        , group_probs = rep(0.1, 10)
                        , prepend_group_column = TRUE
                        , column_names = paste0("col", seq(p))
                        , group_column_name = "g"
                        , writer = data.table::fwrite
                        , ...)
{
    if(missing(n)){
        nsample = 1e3
        bytes_per_element = round(object.size(sampler(nsample)) / nsample)
        oneMB = 2^20
        size_obj_bytes = MB * oneMB
        n = size_obj_bytes / (p * bytes_per_element)
    }

    d = lapply(seq(p), function(...) sampler(n))
    names(d) = column_names
    if(prepend_group_column){
        group_column = sample(length(group_probs), size = n, replace = TRUE, prob = group_probs)
        group_column = list(group_column)
        names(group_column) = group_column_name
        d = c(group_column, d)
    }

    d = do.call(data.frame, d)

    writer(d, fname, ...)
    d
}
