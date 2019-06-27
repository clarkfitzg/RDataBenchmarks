#' Time GROUP BY operation
#'
#' Internally this uses data.table, because it's fast and we want the speed.
#'
#' @rdname group_by
#' @param dir directory where data can be found
#' @param nworkers number of workers
#' @param assign_groups function to assign files and groups to workers, signature must match default
#' @param group_fun function to apply to each group
group_by_local_shuffle = function(dir, nworkers = 3L
    , assign_groups = data_local_group_assign, group_fun = median
){

############################################################
    tm = start_time("scheduling")
############################################################

    # Our "data description", the matrix of the distributions of groups among data chunks.
    # Rows are the files, columns are the groups
    P = readRDS(file.path(dir, "P.rds"))

    s = assign_groups(P, nworkers)

    datafiles = list.files(dir, pattern = "^[0-9]{1,}$", full.names = TRUE)

    # list of length nworkers, where the ith element contains the file names for worker i to read
    files_to_read = lapply(seq(nworkers), function(i) datafiles[s[["file"]] == i])

    # The groups for the GROUP BY computation
    group_by_levels = seq(ncol(P))

    # Assigns the groups to workers
    group_worker_assignment = s[["group"]]


############################################################
    tm = record_time("setup_cluster", tm)
############################################################

    cls = makeCluster(nworkers)

    clusterExport(cls, c("files_to_read", "group_by_levels", "group_worker_assignment", "group_fun")
                  , envir = environment())

    # Use workerID globally all over the place in the code that follows
    parLapply(cls, seq(nworkers), function(i) assign("workerID", i, globalenv()))

    clusterEvalStay(cls, {
        library(data.table)
        files_to_read = files_to_read[[workerID]]
        groups_to_compute = group_by_levels[group_worker_assignment == workerID]
    })


############################################################
    tm = record_time("initial_load", tm)
############################################################

    load_and_combine = function(files_to_read){
        chunks = lapply(files_to_read, readRDS)
        data.table::rbindlist(chunks)
    }

    clusterExport(cls, "load_and_combine"
                  , envir = environment())

    # d is the name of the large data set on all the workers.
    clusterEvalStay(cls, {
        d = load_and_combine(files_to_read)
    })


############################################################
    tm = record_time("intermediate_save", tm)
############################################################

    dir_intermediate = file.path(dir, "intermediate")
    dir.create(dir_intermediate)

    save_intermediate = function(grp){
        fname = file.path(dir_intermediate, sprintf("group%i_worker%i", grp$g[1], workerID))
        # TODO: experiment with high performance intermediate data format, for example fst
        saveRDS(grp, fname)
    }

    clusterExport(cls, c("dir_intermediate", "save_intermediate")
                  , envir = environment())

    clusterEvalStay(cls, {
        # data.table syntax:
        # Must have the "g" in the .SDcols or else it will be dropped because it is the grouping column
        d[!(g %in% groups_to_compute), save_intermediate(.SD), by = g, .SDcols = c("col1", "g")]

        # Drop everything that we no longer need.
        d = d[g %in% groups_to_compute, ]
    })


############################################################
    tm = record_time("intermediate_load", tm)
############################################################

    intermediate_files = list.files(dir_intermediate, full.names = TRUE)

    intfile_groups = gsub("(group|_worker.*)", "", intermediate_files)
    #intfile_groups = as.integer(intfile_groups)

    clusterExport(cls, c("intermediate_files", "intfile_groups")
                  , envir = environment())

    clusterEvalStay(cls, {
        int_files_to_read = intermediate_files[intfile_groups %in% groups_to_compute]

        d_from_others = load_and_combine(int_files_to_read)
        d = rbind(d, d_from_others)
    })


############################################################
    tm = record_time("compute_result", tm)
############################################################

    dir_result = file.path(dir, "result")
    dir.create(dir_result)

    clusterExport(cls, "dir_result"
                  , envir = environment())

    clusterEvalStay(cls, {
        result = d[, group_fun(col1), by = g]
        saveRDS(result, file.path(dir_result, workerID))
    })

    results = load_and_combine(list.files(dir_result, full.names = TRUE))

    tm = stop_time(tm)

    stopCluster(cls)

    list(results = results, time = tm)
}
