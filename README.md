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
