# r_data_benchmarks
Experiments evaluating the performance of different data processing techniques in R

```{r}

library(RDataBenchmarks)

# Only need to run this once
gen_csv_data(p = 10)

time_dt = group_by_data.table()
```

Split and compute time in data.table is close to the epsilon = 0.001 seconds for `system.time`.

```{r}
time_tapply = group_by_tapply()
```

For `tapply` in base R it's slower at around 0.1 seconds.

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
