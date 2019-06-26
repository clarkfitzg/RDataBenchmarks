#' Time GROUP BY operation
#'
#' @param dir directory where data can be found
group_by_local_shuffle = function(dir, nworkers = 3L, assign_groups = data_local_group_assign, by_col = "g", data_col = "col1", group_fun = median)
{

############################################################
    scheduling_time = system.time({

        # Our "data description", the matrix of the distributions of groups among data chunks.
        # Rows are the files, columns are the groups
        P = readRDS(file.path(dir, "P.rds"))

        s = assign_groups(P)

        # list of length nworkers, where the ith element contains the file names for worker i to read
        files_to_read = 

        # The groups for the GROUP BY computation
        group_by_levels = seq(ncol(P))

        # Assigns the groups to workers
        group_worker_assignment = 
    })

############################################################
    setup_cluster_time = system.time({
        cls = makeCluster(nworkers)

        clusterExport(cls, c("files_to_read", "group_by_levels", "compute_assignments", "group_fun"))
        parLapply(cls, seq(nworkers), function(i) assign("workerID", i, globalenv()))

        clusterEvalQ(cls, {
            library(data.table)
            files_to_read = files_to_read[[workerID]]
        })
    })

############################################################
    initial_load_time = system.time({
        clusterEvalQ(cls, {
            chunks = lapply(files_to_read, readRDS)
            d = data.table::rbindlist(chunks)
            rm(chunks)
        })
    })

############################################################
    intermediate_save_time = system.time({
        clusterEvalQ(cls, {
            d[!(g %in% 
        })

    })

############################################################
    intermediate_load_time = system.time({
    })

############################################################
    compute_time = system.time({
    })


    list(setup_cluster_time = setup_cluster_time
         , initial_load_time = initial_load_time
         , intermediate_save_time = intermediate_save_time
         , intermediate_load_time = intermediate_load_time
         , compute_time = compute_time
         )
}


#' Spin up a local SNOW cluster and prepare the workers to do the computation.
#'
#' @param nworkers number of workers
#' @return cls the prepared cluster
setup_cluster = function(nworkers, files_to_read){

    cls = makeCluster(nworkers)

    clusterExport(cls, files_to_read)
    parLapply(cls, seq(nworkers), function(i) assign("workerID", i, globalenv()))

    clusterEvalQ(cls, {
        library(data.table)
        files_to_read = files_to_read[[workerID]]
    })

    cls
}
