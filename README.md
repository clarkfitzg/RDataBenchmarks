# RDataBenchmarks

Experiments evaluating the performance of different data processing techniques in R

## Experiment 1- base case

This is how we would process the data in an ideal case, when the data is on the same machine and it all fits in memory.

```{r}

library(RDataBenchmarks)

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

gen_data_groupby(p = 1, MB = 50, writer = saveRDS)


```

