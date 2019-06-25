#' Time Data.table GROUP BY operation
#'
#' @param fname name of the file to read
group_by_data.table = function(fname = default_csv_file(), threads = 2L, by = "g", group_fun = median)
{
    require(data.table)
    setDTthreads(threads)
    read_time = system.time(DT <- fread(fname))
    split_and_compute_time = system.time(DT[, group_fun(col1), by = by])
    list(read_time = read_time, split_and_compute_time = split_and_compute_time)
}
