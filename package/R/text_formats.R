#' A nested github markdown document
#'
#' @inheritParams common_dynbenchmark_format
#' @param ... Parameters for rmarkdown::github_document
#'
#' @export
github_markdown_nested <- function(
  bibliography = paste0(dynbenchmark::get_dynbenchmark_folder(), "manuscript/references.bib"),
  csl = paste0(dynbenchmark::get_dynbenchmark_folder(), "manuscript/nature-biotechnology.csl"),
  ...
) {
  format <- rmarkdown::github_document(...)

  # make sure atx headers are used, for knit_nest
  format$pandoc$args <- c(format$pandoc$args, "--atx-headers")

  # processor before pandoc:
  # - render all equations
  format$pre_processor <- function(metadata, input_file, runtime, knit_meta, files_dir, output_dir) {
    readr::read_lines(input_file) %>%
      render_equations(format = "markdown") %>%
      fix_references_header() %>%
      readr::write_lines(input_file)

    invisible()
  }

  # apply common dynbenchmark format
  format <- common_dynbenchmark_format(format)

  format
}


#' A supplementary note pdf document
#'
#' @inheritParams common_dynbenchmark_format
#' @param ... Parameters for rmarkdown::pdf_document
#'
#' @export
pdf_supplementary_note <- function(
  bibliography = paste0(dynbenchmark::get_dynbenchmark_folder(), "manuscript/references.bib"),
  csl = paste0(dynbenchmark::get_dynbenchmark_folder(), "manuscript/nature-biotechnology.csl"),
  ...
) {
  # setup the pdf format
  format <- rmarkdown::pdf_document(
    ...,
    toc = TRUE,
    includes = rmarkdown::includes(system.file("supplementary_note.sty", package = "dynbenchmark")),
    latex_engine = "xelatex",
    number_sections = FALSE
  )

  format <- common_dynbenchmark_format(
    format,
    bibliography = bibliography,
    csl = csl
  )

  format
}

#' Common dynbenchmark format
#' @param format The format on which to apply common changes
#' @param bibliography Bibliography location
#' @param csl Csl file location
common_dynbenchmark_format <- function(
  format,
  bibliography = paste0(dynbenchmark::get_dynbenchmark_folder(), "manuscript/references.bib"),
  csl = paste0(dynbenchmark::get_dynbenchmark_folder(), "manuscript/nature-biotechnology.csl")
) {
  # allow duplicate labels, needed for nested documents to work
  options(knitr.duplicate.label = 'allow')

  # setup the refs globally
  format$pre_knit <- function(...) {setup_refs_globally()}

  # adapt knitr options
  format$knitr$opts_chunk$echo = FALSE
  format$knitr$opts_chunk$fig.path = ".figures/"

  # activate pandoc citation processing
  format$pandoc$args <- c(
    format$pandoc$args,
    glue::glue("--bibliography={bibliography}"),
    glue::glue("--csl={csl}"),
    "--metadata", "link-citations=true",
    "--metadata", "reference-section-title=References",
    "--filter=/usr/lib/rstudio/bin/pandoc/pandoc-citeproc"
  )

  format
}



#' Knit a child, and add an extra level of headings + fix relative paths. Can be used both for latex and markdown output formats
#'
#' @param file File to knit, can also be a directory in which case the README.Rmd will be knit
#' @export
knit_nest <- function(file) {
  # check if directory -> use README
  if (fs::is_dir(file)) {
    file <- file.path(file, "README.Rmd")
  }
  folder <- fs::path_dir(file) %>% fs::path_rel()

  # stop if file not present
  if (!file.exists(file)) {
    stop(file, " does not exist!")
  }

  # choose between markdown output and latex output
  format <- get_default_format()
  if (format == "markdown") {
    # when markdown, simply include the markdown file, but with some adaptations obviously
    knit <- readr::read_lines(fs::path_ext_set(file, "md"))

    # fix relative paths to links and figures
    knit <- fix_relative_paths(knit, folder)

    # add extra header sublevels & add link
    knit <- knit %>%
      str_replace_all("^(# )(.*)$", paste0("\\1[\\2](", folder, ")")) %>%
      str_replace_all("^#", "##")

    # cat output
    cat(knit %>% glue::glue_collapse("\n"))

    invisible()
  } else if (format == "latex") {
    # make sure duplicated labels are allowed
    options(knitr.duplicate.label = "allow")

    # knit as a child
    knitr::knit_child(
      text = readr::read_lines(file) %>% stringr::str_replace_all("^#", "##"),
      quiet = TRUE
    ) %>% cat()

    invisible()
  }
}


#' Process relative paths to links & figures
#' First extract every link, determine whether it is a relative path and if yes, add folder to the front
#'
#' @param knit Character vector
#' @param folder The relative folder
#' @examples
#' knit <- c(
#' "hshlkjdsljkfdhg [i am a absolute path](/pompompom/dhkjhlkj/) kjfhlqkjsdhlkfjqsdf",
#' "hshlkjdsljkfdhg [i am a relative path](pompompom/dhkjhlkj/) kjfhlqkjsdhlkfjqsdf",
#' "<img src = \"heyho/heyho\">",
#' "<img src = \"/heyho/heyho\">"
#' )
#' dynbenchmark:::fix_relative_paths(knit, "IT WORKED :)")
fix_relative_paths <- function(knit, folder) {
  patterns <- c(
    "(\\[[^\\]]*\\]\\()([^\\)]*)(\\))",
    "(src[ ]?=[ ]?[\"\'])([^\"\']*)([\"\'])"
  )

  for (pattern in patterns) {
    knit <- knit %>%
      str_replace_all(
        pattern,
        function(link) {
          matches <- stringr::str_match(link, pattern)
          prefix <- matches[2]
          file <- matches[3] # contains the file
          suffix <- matches[4]

          # do not fix absolute paths, urls or anchors
          if (fs::is_absolute_path(file) || startsWith(file, "http") || startsWith(file, "#")) {
            link
          } else {
            glue::glue("{prefix}{folder}/{file}{suffix}")
          }
        }
      )
  }

  knit
}


fix_references_header <- function(knit) {
  knit %>% str_replace_all("^#*.*References.*", "#### References")
}