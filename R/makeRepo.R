#' Downloads packages from CRAN to specified path and creates a local repository.
#'
#' Given a list of packages, downloads these packages to a specified destination folder using the required CRAN folder structure, and finally creates the PACKAGES index file.  Since the folder structure mimics the required structure and files of a CRAN repository, it supports functions like [utils::install.packages()].
#'
#' @section Repo folder structure:
#' The folder structure of a repository
#' \itemize{
#'  \item{Root}
#'  \itemize{
#'    \item{src/contrib}
#'    \itemize{
#'      \item{PACKAGES}
#'    }
#'    \item{bin}
#'    \itemize{
#'      \item{windows/contrib/version}
#'      \itemize{
#'        \item{PACKAGES}
#'      }
#'      \item{macosx/contrib/version}
#'      \itemize{
#'        \item{PACKAGES}
#'      }
#'      \item{macosx/mavericks/contrib/version}
#'      \itemize{
#'        \item{PACKAGES}
#'      }
#'      \item{macosx/leopard/contrib/version}
#'      \itemize{
#'        \item{PACKAGES}
#'      }
#'    }
#'  }
#' }
#'
#' @note Internally makes use of [utils::download.packages()] and [write_PACKAGES()]
#'
#' @inheritParams pkgDep
#'
#' @param pkgs Character vector of packages to download
#'
#' @param path Destination download path. This path is the root folder of your new repository.
#'
#' @param Rversion List with two named elements: `major` and `minor`. If not supplied, defaults to system version of R, using [R.version].  Only used if `type` is not "source"
#'
#' @param download If TRUE downloads packages.
#'
#' @param quiet If TRUE, suppress status messages (if any), and the progress bar during download.
#'
#' @param writePACKAGES If TRUE, calls [write_PACKAGES()] to update the repository PACKAGES file.
#'
#' @export
#' @family update repo functions
#'
#' @importFrom utils download.packages
#'
#' @example /inst/examples/example_makeRepo.R
makeRepo <- function(pkgs, path, repos = getOption("repos"), type = "source",
                     Rversion = R.version, download = TRUE, writePACKAGES = TRUE, quiet = FALSE) {
  if (!file.exists(path)) stop("Download path does not exist")

  downloaded <- lapply(type, function(t) {
    pkgPath <- repoBinPath(path = path, type = t, Rversion = Rversion)
    if (!file.exists(pkgPath)) {
      result <- dir.create(pkgPath, recursive = TRUE, showWarnings = FALSE)
      if (result) {
        if (!quiet) message("Created new folder: ", pkgPath)
      } else {
        stop("Unable to create repo path: ", pkgPath)
      }
    }

    pdb <- pkgAvail(repos = repos, type = t, Rversion = Rversion)

    if (download) {
      download_packages(pkgs, destdir = pkgPath, available = pdb, repos = repos,
                        contriburl = contribUrl(repos, t, Rversion),
                        type = t, quiet = quiet)
    }
  })

  if (download) {
    downloaded <- downloaded[[1]][, 2]

    ## allow for more than one repo
    fromLocalRepos <- grepl("^file://", repos)

    if (any(fromLocalRepos)) {
      # need to copy files to correct folder
      if (sum(fromLocalRepos) > 1)
        warning("More than one local repos provided. Only the first listed will be used.")
      pat <- ifelse(Sys.info()["sysname"] == "Windows", "^file:///", "^file://")
      repoPath <- gsub(pat, "", repos[fromLocalRepos][1])
      repoPath   <- normalizePath(repoPath, winslash = "/")
      path       <- normalizePath(path    , winslash = "/")
      downloaded <- normalizePath(downloaded, winslash = "/")
      newPath  <- gsub(repoPath, path, downloaded)
      file.copy(downloaded, newPath)
      downloaded <- newPath
    }
  }

  if (writePACKAGES) updateRepoIndex(path = path, type = type, Rversion = Rversion)
  if (download) downloaded else character(0)
}



#' @rdname makeRepo
#' @export
updateRepoIndex <- function(path, type = "source", Rversion = R.version) {
  n <- lapply(type, function(t) {
    pkgPath <- repoBinPath(path = path, type = t, Rversion = Rversion)
    if (grepl("mac.binary", t)) t <- "mac.binary"
    write_packages(dir = pkgPath, type = t)
  })
  names(n) <- type
  n
}



#' Deprecated function to download packages to local folder.
#'
#' @inheritParams makeRepo
#' @export
makeLibrary <- function(pkgs, path, type = "source") {
  .Deprecated("makeRepo")
  NULL
}

