renv::settings$snapshot.type("implicit")
renv::snapshot(packages = renv::dependencies("src/r-pkg")$Package |> unique())
