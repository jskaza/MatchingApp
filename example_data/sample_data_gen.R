library(datasets)
library(tibble)
library(dplyr)
library(purrr)

df_titanic <- as.data.frame(Titanic)

df_titanic <- lapply(df_titanic, rep, df_titanic$Freq) |>
  as.data.frame() |>
  select(-Freq) |>
  rowid_to_column("id")
  # mutate(Age_Num = case_when(Age == "Child" ~ runif(1, 0, 18), 
  #                             TRUE ~ -99)) |>
df_titanic[sample(nrow(df_titanic)),] |>
  write.table("titanic.txt", sep = "\t",
            col.names = T, row.names = F)


types_map <- list(
  "character" = "String",
  "numeric" = "Float64"
)
as_tibble(Titanic) |> 
  summarise_all(class) |>
  unname() |>
  t() |>
  recode(
    "character" = "String",
    "numeric" = "Float64"
  ) |>
  write.table("coltypes.csv", sep = ",",
              col.names = F, row.names = F, quote = F)

