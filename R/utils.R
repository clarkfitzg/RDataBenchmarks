default_csv_file = function(fname = "data.csv") file.path(default_data_dir(), fname)

default_data_dir = function() "~/data/RDataBenchmarks"


start_time = function(event_name)
{
    times = list()
    times[[event_name]] = Sys.time()
    times
}

record_time = function(event_name, times)
{
    times = stop_time(times)
    times[[event_name]] = Sys.time()
    times
}

stop_time = function(times)
{
    current_time = Sys.time()
    last_index = length(times)
    times[[last_index]] = current_time - times[[last_index]]
    times
}


#' Appends a NULL to the end of a brace so that the result stays on the workers and is not returned to the manager
clusterEvalStay = function(cl, expr)
{
    # Append a NULL to the end of the expression so nothing is returned
    expr = substitute(expr)

    b = rstatic::to_ast(expr)
    stopifnot(is(b, "Brace"))

    b$contents = c(b$contents, list(rstatic::quote_ast(NULL)))

    expr = rstatic::as_language(b)

    clusterCall(cl, eval, expr, env = .GlobalEnv)
}
