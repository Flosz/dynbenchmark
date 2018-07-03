#' Helper functions for creating new datasets
#'
#' @param dataset_id The ID of the dataset to be used
#' @param dataset Dataset object to save
#' @param filename Custom filename
#' @param relative Whether or not to output relative paths
#' @param lazy_load Whether or not to allow for lazy loading of large objects in the dataset
#'
#' @export
#'
#' @rdname dataset_preprocessing
dataset_preprocessing <- function(dataset_id) {
  # check whether the working directory is indeed the dynbenchmark folder
  dynbenchmark_folder <- get_dynbenchmark_folder()

  # set option
  options(
    dynbenchmark_datasetpreproc_id = dataset_id
  )
}

#' @rdname dataset_preprocessing
#' @export
datasetpreproc_getid <- function() {
  dataset_id <- getOption("dynbenchmark_datasetpreproc_id")
  if (is.null(dataset_id)) {
    stop("No dataset_id found. Did you run dataset_preprocessing(...)?")
  }
  dataset_id
}


# create a helper function
datasetpreproc_subfolder <- function(path) {
  function(filename = "", dataset_id = NULL, relative = FALSE) {
    dyn_fold <- get_dynbenchmark_folder()

    if (relative) {
      dyn_fold = ""
    }

    if (is.null(dataset_id)) {
      dataset_id <- datasetpreproc_getid()
    }

    # determine the full path
    full_path <- paste0(dyn_fold, "/", path, "/", dataset_id, "/")

    # create if necessary
    dir.create(full_path, recursive = TRUE, showWarnings = FALSE)

    # get complete filename
      paste0(full_path, filename)
  }
}

#' @rdname dataset_preprocessing
#' @export
dataset_preproc_file <- datasetpreproc_subfolder("derived/1-datasets_preproc")

#' @rdname dataset_preprocessing
#' @export
dataset_file <- datasetpreproc_subfolder("derived/1-datasets")

#' @rdname dataset_preprocessing
#' @export
save_dataset <- function(dataset, dataset_id = NULL, lazy_load = TRUE) {
  dir.create(dataset_file(filename = "", dataset_id = dataset_id), showWarnings = FALSE)

  if (lazy_load) {
    for (col in c("expression", "counts")) {
      col_file <- dataset_file(filename = paste0(col, ".rds"), dataset_id = dataset_id)
      write_rds(dataset[[col]], col_file)

      env <- new.env(baseenv())
      assign("dataset_id", dataset_id, env)
      assign("col", col, env)
      dataset[[col]] <- function() {
        readr::read_rds(dynbenchmark::dataset_file(paste0(col, ".rds"), dataset_id = dataset_id))
      }
      environment(dataset[[col]]) <- env
    }
  }

  write_rds(dataset, dataset_file(filename = "dataset.rds", dataset_id = dataset_id))
}

#' @rdname load_dataset
list_datasets <- function() {
  dataset_ids <- list.files(
    derived_file("", experiment_id = "1-datasets"),
    "dataset\\.rds",
    recursive = TRUE
  ) %>% dirname()

  tibble(
    dataset_id = dataset_ids,
    dataset_source = gsub("(.*)/[^/]*", "\\1", dataset_ids),
    dataset_name = gsub(".*/([^/]*)", "\\1", dataset_ids)
  )
}

#' Load datasets
#' @export
#' @inheritParams dataset_preprocessing
#' @param as_tibble Return the datasets as a tibble or as a list of datasets?
#'
#' @rdname load_dataset
load_dataset <- function(dataset_id, as_tibble = FALSE) {
  dataset <- read_rds(dataset_file(filename = "dataset.rds", dataset_id = dataset_id))

  if (as_tibble) {
    dataset <- list_as_tibble(list(dataset))
  }

  dataset
}

#' @export
#' @param dataset_ids Character vector of dataset identifiers
#' @rdname load_dataset
load_datasets <- function(dataset_ids = list_datasets()$dataset_id, as_tibble = TRUE) {
  testthat::expect_true(is.character(dataset_ids))

  datasets <- map(dataset_ids, load_dataset)

  if (as_tibble) {
    datasets %>% list_as_tibble()
  } else {
    datasets
  }
  # read_rds(derived_file("tasks.rds", experiment_id = "1-datasets"))
}

#' Download a file and return its location path
#' @param url The url of the file to download
#' @param filename What name to give to the file
#' @param dataset_id An optional dataset_id
#' @export
download_dataset_file <- function(filename, url, dataset_id = NULL) {
  loc <- dataset_preproc_file(dataset_id = dataset_id, filename = filename)

  if (!file.exists(loc)) {
    download.file(url, loc, method = "libcurl")
  }

  loc
}