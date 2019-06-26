#' Time GROUP BY operation
#'
#' @param dir directory where data can be found
group_by_local_shuffle = function(dir, nworkers, by_col = "g", data_col = "col1", group_fun = median)
{
    setup_cluster_time = system.time({
        tmp = setup_cluster(nworkers)
    })

    initial_load_time = system.time({
    })

    intermediate_save_time = system.time({
    })

    intermediate_load_time = system.time({
    })

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
setup_cluster = function(nworkers, assignments, file_names){

cls = makeCluster(nworkers)

clusterExport(cls, c("assignments", "file_names"))
parLapply(cls, seq(nworkers), function(i) assign("workerID", i, globalenv()))

    clusterEvalQ(cls, {
        library(data.table)
        file_names = file_names[assignments[[workerID]]]
        chunks = lapply(file_names, readRDS)
        d = rbindlist(chunks)
        rm(chunks)

        # TODO: 
        #saveRDS({{{save_var}}}, file = paste0("{{{save_var}}}_", workerID, ".rds"))
    })



    list(cls = cls)
}
