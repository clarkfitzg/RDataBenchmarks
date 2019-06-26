# This file came from https://github.com/clarkfitzg/phd_research/blob/master/experiments/group_by/two_groupby.R


# Standard greedy algorithm
greedy_assign = function(tasktimes, w)
{
    workertimes = rep(0, w)
    assignments = rep(NA, length(tasktimes))
    for(idx in seq_along(tasktimes)){
        worker = which.min(workertimes)
        workertimes[worker] = workertimes[worker] + tasktimes[idx]
        assignments[idx] = worker
    }
    assignments
}


# Put groups on the 'best' workers, starting with the largest groups and without exceeding a balanced load by epsilon.
# The best workers are those that have relatively more of the same second group already on them.
# Returns an integer vector the same length as P1 that assigns each group to one of the w workers.
first_group = function(P, w)
{
    P1 = rowSums(P)
    P2 = colSums(P)

    epsilon = min(P1)
    full_plus_epsilon = sum(P) / w + epsilon
    avg_load = sum(P) / w

    # These get updated as the assignments are made
    assignments = rep(NA, length(P1))
    times = rep(0, w)

    for(idx in order(P1, decreasing = TRUE)){
        tm = P1[idx]
        newload = P[idx, ]
        g2_loads = worker_g2_loads(assignments, P, w, avg_load)
        bw = find_best_worker(newload, g2_loads, times, epsilon, avg_load)
        assignments[idx] = bw
        times[bw] = times[bw] + tm
    }

    assignments
}


# This computes the load on each worker if the remaining groups of data were distributed evenly 
# according to the space each worker has available.
worker_g2_loads = function(assignments, P, w, avg_load)
{
    free_idx = is.na(assignments)

    # Balance the remainder of the unassigned load according to the relative space each worker has available.
    unassigned = colSums(P[free_idx, , drop = FALSE])

    # Scale the unassigned such that it sums to 1
    unassigned = unassigned / sum(unassigned)

    loads = vector(w, mode = "list")
    for(worker in seq(w)){
        load_idx = which(assignments == worker)
        load = colSums(P[load_idx, , drop = FALSE])
        free = avg_load - sum(load)
        if(0 < free){
            # Assign weight accordingly. 
            # TODO: This may "overassign" some of the free workers, but I'm not too worried about it.
            load = load + free * unassigned
        }
        loads[[worker]] = load
    }
    loads
}


scaled_similarity = function(x, y)
{
    x = x / sqrt(sum(x^2))
    y = y / sqrt(sum(y^2))
    sum(x * y)
}


find_best_worker = function(newload, g2_loads, times, epsilon, avg_load)
{
    candidates = times + sum(newload) < avg_load + epsilon

    # Corner case is when they all exceed it
    if(!any(candidates)) return(which.min(times))

    scores = sapply(g2_loads[candidates], scaled_similarity, y = newload)

    which(candidates)[which.max(scores)]
}


# Count how much data in P had to be moved between workers
proportion_data_movement = function(g1_assign, g2_assign, P)
{
    workers = unique(c(g1_assign, g2_assign))
    moved = sapply(workers, data_moved_per_worker
        , g1_assign = g1_assign, g2_assign = g2_assign, P = P)
    sum(moved) / sum(P)
}


data_moved_per_worker = function(worker, g1_assign, g2_assign, P)
{
    sum(P[g1_assign != worker, g2_assign == worker])
}


# Assign the second group to workers given the first GROUP BY assignments
second_group = function(g1_assign, P, w)
{
    P2 = colSums(P)

    epsilon = min(P2)
    full_plus_epsilon = sum(P) / w + epsilon

    avg_load = sum(P) / w
    times = rep(0, w)

    assignments = rep(NA, length(P2))

    # Start with the largest groups and assign them to the worker that already has the most data for that group.
    for(idx in order(P2, decreasing = TRUE)){
        newtime = P2[idx]
        candidates = times + newtime < avg_load + epsilon
        present_on_worker = tapply(P[, idx], g1_assign, sum)

        best_worker = if(!any(candidates)) 
        {
            which.min(times)
        } else {
            workers_with_most_data_first = order(present_on_worker, decreasing = TRUE)
            # intersect returns result in order of first arg
            intersect(workers_with_most_data_first, which(candidates))[1]
        }
        times[best_worker] = times[best_worker] + newtime
        assignments[idx] = best_worker
    }
    assignments
}


#' Generate and save data for shuffled data group by experiment
#'
#' @param nfiles number of files
#' @param ngroups number of distinct groups in the grouping column
#' @param block_two logical, whether to add two diagonal blocks to the distributions of the files and groups, which means that some groups are more likely to be located in particular files.
#' @param block_multiplier magnitude of block structure
#' @param rand_gen random number generating function
#' @param dir directory to save files
#' @param ... further arguments to gen_table
gen_data_groupby = function(nfiles = 10L, ngroups = 8L
    , block_two = TRUE, block_magnitude = 1
    , rand_gen = runif
    , dir = file.path(default_data_dir(), sprintf("groupby_%ifiles_%igroups", nfiles, ngroups))
    , ...
){
    if(dir.exists(dir)){
        stop("There's already data in this directory.")
    }
    dir.create(dir)

    # Each row of P is a different file
    P = matrix(rand_gen(nfiles * ngroups), nrow = nfiles)

    if(block_two){
        # Add two diagonal blocks to it
        nfiles_b = seq(as.integer(nfiles / 2))
        ngroups_b = seq(as.integer(ngroups / 2))
        block = matrix(0, nrow = nfiles, ncol = ngroups)
        block[nfiles_b, ngroups_b] = block_magnitude
        block[-nfiles_b, -ngroups_b] = block_magnitude

        P = P + block
    }

    for(i in seq(nfiles)){
        fname = file.path(dir, i)
        gen_table(fname = fname, group_probs = P[i ,], ...)
    }
    saveRDS(P, file.path(dir, "P.rds"))

    P
}


data_local_group_assign = function(P)
{

    list(file = , group = )
}
