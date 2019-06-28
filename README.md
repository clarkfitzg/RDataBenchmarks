```{r}

library(RDataBenchmarks)

```

# RDataBenchmarks

Experiments evaluating the performance of different data processing techniques in R

## Experiment 1- base case

This is how we would process the data in an ideal case, when the data is on the same machine and it all fits in memory.

```{r}


# Only need to run this once
gen_table(p = 10)

time_dt = group_by_data.table()

```

For 100 MB the split and compute time in data.table is close to the epsilon = 0.001 seconds for `system.time`.
Reading the data is a couple orders of magnitude slower at 0.24 seconds.

```{r}
time_tapply = group_by_tapply()
```

For `tapply` in base R the computation is slower at around 0.1 seconds.

```{r}

time_tapply = group_by_split_lapply()

$split_time
   user  system elapsed
  0.219   0.013   0.059

$lapply_time
   user  system elapsed
  0.026   0.004   0.030

$split_time
   user  system elapsed
  0.204   0.010   0.055

$lapply_time
   user  system elapsed
  0.110   0.005   0.030
```

I'm surprised that data.table is faster than `lapply`.
I understand that it would be faster for the splitting, since it's highly optimized for that.
But once the data is split `lapply` should be pretty fast.


## Experiment 2- split data


I'm testing if we can measure any difference in using a more data local algorithm to assign groups and files to workers.
I'll start with a case where it theoretically will matter more- when there is some block structure in the groups and the files.
For three workers, 10 initial chunks of data, and 10 groups, the improved data local algorithm moved about 16% less of the total data.
Let's see if this also translates to a real speedup.

The actual speedup depends on relatively how expensive each step is- data loading, transfer, and computation.
The ideal case is when the data transfer is the bottleneck, which may be realistic on a distributed platform where workers must communicate over a slow network.

These three steps are not independent.
The heuristic I wrote is designed purely to decrease data transfer time, without affecting data loading and computation time too much.
We may reduce data transfer time at the expense of increasing the data loading and computation time because of worse load balancing.
So we do need to measure every step for each case.
It's not a bad thing that the steps all depend on each other.
Indeed, it shows that for this particular code pattern we might take a completely different choice in how to compute a result depending on the characteristics of the data and the platform.


Generate some data:
```{r}
gen_data_groupby(p = 1
    , MB = 50
    , writer = saveRDS
    , nfiles = 10L
    , ngroups = 8L
    , block_two = TRUE
)
```

Evaluate the performance.

Data local algorithm:
```{r}

out = group_by_local_shuffle(dir = "~/data/RDataBenchmarks/groupby_10files_8groups", nworkers = 3L)

$time
$time$scheduling
Time difference of 0.004473925 secs

$time$setup_cluster
Time difference of 0.7160969 secs

$time$initial_load
Time difference of 2.552251 secs

$time$intermediate_save
Time difference of 9.078969 secs

$time$intermediate_load
Time difference of 0.09745407 secs

$time$compute_result
Time difference of 0.654726 secs
```

Greedy algorithm:

```{r}

out2 = group_by_local_shuffle(dir = "~/data/RDataBenchmarks/groupby_10files_8groups", nworkers = 3L, assign_groups = greedy_group_assign)
out2$time

```

Let's try it a few times to get a better idea of performance.

```{r}

wrapper = function(i, ...){
    out = group_by_local_shuffle(...)
    out = lapply(out[["time"]], as.numeric)
    out = data.frame(out)
    out$total = rowSums(out)
    out
}

summarize_shuffle = function(nreps = 5, ...)
{
    results = lapply(seq(nreps), wrapper, ...)
    do.call(rbind, results)
}

out_greedy = summarize_shuffle(dir = "~/data/RDataBenchmarks/groupby_10files_8groups"
    , nworkers = 3L
    , assign_groups = greedy_group_assign
)
out_greedy$scheduler = "greedy"


out_data_local = summarize_shuffle(dir = "~/data/RDataBenchmarks/groupby_10files_8groups"
    , nworkers = 3L
    , assign_groups = data_local_group_assign
)
out_data_local$scheduler = "data_local"

out = rbind(out_greedy, out_data_local)

```

So which is faster?
Scheduling takes on the order of 1ms for the data local version, vs. 0.1 ms for the simpler greedy algorithm.
Setting up the cluster and the initial loadings are about the same.
For the intermediate save and intermediate load I hoped to see some improvements for the data local algorithm.

```{r}

stripchart(intermediate_save ~ scheduler, data = out)

stripchart(intermediate_load ~ scheduler, data = out)

stripchart(compute_result ~ scheduler, data = out)

stripchart(total ~ scheduler, data = out)

```

Well, it's just the opposite.
The greedy algorithm does about 20% better for the intermediate load.
The greedy algorithm also does about 10% better for computing the final result.
I expected this last item, because the load balancing should be a bit better.

For total time the greedy algorithm seems to do on the order of 1% better, but there's a lot of variability here.

### Questions

The intermediate save takes around 4 seconds and the intermediate load a little under 0.1 seconds.
That's 40 times slower.
Why?
Is that to be expected?

The intermediate load is much faster without compressing the data.
Part of this may come from generating random data without any structure at all.
In contrast, real data often has repeated values or lower precision that could help compression.

One issue with the way I've implemented it is that the program will wait until all workers have finished each step before proceeding to the next step.
This allows us to time each step, and determine which is most expensive.
The downside is that the slowest worker is the bottleneck for that step.
This means that if one worker has twice as much work as all the others, then that one worker will hold up the whole step.
It doesn't matter if the total data transferred was small.
In other words, it's necessary to minimize the maximum time every worker spends in each step.


### Summary

The real bottlenecks in this distributed GROUP BY come from loading and saving the data.
We load and save the data on disk as a mechanism for workers on a shared file system to communicate.
Any differences that came from scheduling and our particular algorithm for considering data locality were small relative to the real bottlenecks.
