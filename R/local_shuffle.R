#' Time GROUP BY operation
#'
#' Internally this uses data.table, because it's fast and we want the speed.
#'
#' @param dir directory where data can be found
group_by_local_shuffle = function(dir, nworkers = 3L
    , assign_groups = data_local_group_assign, group_fun = median
){

############################################################
    scheduling_time = system.time({

        # Our "data description", the matrix of the distributions of groups among data chunks.
        # Rows are the files, columns are the groups
        P = readRDS(file.path(dir, "P.rds"))

        s = assign_groups(P)

        datafiles = list.files(dir, pattern = "^[0-9]{1,}$", full.names = TRUE)

        # list of length nworkers, where the ith element contains the file names for worker i to read
        files_to_read = lapply(seq(nworkers), function(i) datafiles[s[["file"]] == i])

        # The groups for the GROUP BY computation
        group_by_levels = seq(ncol(P))

        # Assigns the groups to workers
        group_worker_assignment = s[["group"]]
    })

############################################################
    setup_cluster_time = system.time({
        cls = makeCluster(nworkers)

        clusterExport(cls, c("files_to_read", "group_by_levels", "group_worker_assignment", "group_fun"))
        parLapply(cls, seq(nworkers), function(i) assign("workerID", i, globalenv()))

        clusterEvalQ(cls, {
            library(data.table)
            files_to_read = files_to_read[[workerID]]
            groups_to_compute = group_by_levels[group_worker_assignment == workerID]
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

        dir_intermediate = file.path(dir, "intermediate")
        mkdir(dir_intermediate)
        clusterExport(cls, "dir_intermediate")

        clusterEvalQ(cls, {
            save_intermediate = function(grp){
                fname = file.path(dir_intermediate, sprintf("group%i_worker%i", grp$g[1], workerID))
                # TODO: experiment with high performance intermediate data format, for example fst
                saveRDS(grp, fname)
            }
            # data.table syntax:
            d[!(g %in% groups_to_compute), save_intermediate(.SD), by = g]
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

