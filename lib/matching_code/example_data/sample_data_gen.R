library(MASS)
library(tibble)
library(dplyr)
library(purrr)

extra_control_data <- crabs |> 
  filter(sp == "O") |> 
  sample_n(1000, replace = T) |> 
  mutate(FL = jitter(FL),
         RW = jitter(RW),
         CL = jitter(CL),
         CW = jitter(CW),
         BD = jitter(BD)
  )

crabs |>
  rbind(extra_control_data) |> 
  rowid_to_column("id") |> 
  select(-index) |> 
  write.table("crabs.txt", sep = "\t",
            col.names = T, row.names = F)
# 
# df_titanic <- lapply(df_titanic, rep, df_titanic$Freq) |>
#   as.data.frame() |>
#   select(-Freq) |>
#   rowid_to_column("id")
#   # mutate(Age_Num = case_when(Age == "Child" ~ runif(1, 0, 18), 
#   #                             TRUE ~ -99)) |>
# df_titanic[sample(nrow(df_titanic)),] |>

# 
# 
# types_map <- list(
#   "character" = "String",
#   "numeric" = "Float64"
# )
# as_tibble(Titanic) |> 
#   summarise_all(class) |>
#   unname() |>
#   t() |>
#   recode(
#     "character" = "String",
#     "numeric" = "Float64"
#   ) |>
#   write.table("coltypes.csv", sep = ",",
#               col.names = F, row.names = F, quote = F)
# 
