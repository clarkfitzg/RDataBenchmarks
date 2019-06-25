#' Time Data.table GROUP BY operation
#'
#' @param fname name of the file to read
group_by_data.table = function(fname = default_csv_file(), threads = 2L, by_col = "g", data_col = "col1", group_fun = median)
{
    require(data.table)
    setDTthreads(threads)
    read_time = system.time(DT <- fread(fname))
    split_and_compute_time = system.time(DT[, group_fun(.SD[, data_col]), by = by_col])
    list(read_time = read_time, split_and_compute_time = split_and_compute_time)
}


#' Time GROUP BY operation
#'
#' @param fname name of the file to read
group_by_tapply = function(fname = default_csv_file(), by_col = "g", data_col = "col1", group_fun = median)
{
    # No point in timing base R's IO functions, I know they're 2 orders of magnitude slower than high performance implementations.
    DT = data.table::fread(fname)
    df = as.data.frame(DT)
    split_and_compute_time = system.time({
        out = tapply(df[, data_col], df[, by_col], group_fun)
    })
    list(split_and_compute_time = split_and_compute_time)
}
