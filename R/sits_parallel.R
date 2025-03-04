
#' @title Stop all workers of the sits cluster
#' @name .sits_parallel_stop
#' @keywords internal
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
.sits_parallel_stop <- function() {
    if (.sits_parallel_is_open()) {
        tryCatch(
            {
                parallel::stopCluster(sits_env[["cluster"]])
            },
            finally = {
                sits_env[["cluster"]] <- NULL
            }
        )
    }
}

#' @title Check if sits clusters are open or not
#' @name .sits_parallel_is_open
#' @keywords internal
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
.sits_parallel_is_open <- function() {
    tryCatch({
        !is.null(sits_env[["cluster"]]) &&
            socketSelect(list(sits_env[["cluster"]][[1]]$con), write = TRUE)
    },
    error = function(e) FALSE
    )
}

#' @title Start a new sits cluster for parallel processing
#' @name .sits_parallel_start
#' @keywords internal
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#'
#' @param workers   number of cluster to instantiate
#' @param log       a logical indicating if log files must be written
.sits_parallel_start <- function(workers, log) {
    if (!.sits_parallel_is_open() ||
        length(sits_env[["cluster"]]) != workers) {
        .sits_parallel_stop()

        if (workers > 1) {
            sits_env[["cluster"]] <- parallel::makePSOCKcluster(workers)

            # make sure library paths is the same as actual environment
            lib_paths <- .libPaths()
            parallel::clusterExport(
                cl = sits_env[["cluster"]],
                varlist = c("lib_paths", "log"),
                envir = environment()
            )
            parallel::clusterEvalQ(
                cl = sits_env[["cluster"]],
                expr = .libPaths(lib_paths)
            )
            # export debug flag
            parallel::clusterEvalQ(
                cl = sits_env[["cluster"]],
                expr = sits:::.sits_debug(flag = log)
            )
        }
    }
}

#' @title Recreates a cluster worker
#' @name .sits_parallel_reset_node
#' @keywords internal
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#'
#' @param worker_id   id of the cluster work to be recreated
.sits_parallel_reset_node <- function(worker_id) {

    # stop node
    tryCatch({
        if (isOpen(sits_env[["cluster"]][[worker_id]]$con)) {
            close(sits_env[["cluster"]][[worker_id]]$con)
        }
    })

    # create a new node
    sits_env[["cluster"]][[worker_id]] <- parallel::makePSOCKcluster(1)[[1]]
}

#' @title Fault tolerant version of some parallel functions
#' @name sits_parallel_fault_tolerant
#' @keywords internal
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#' @author Derived from the snow package
#'
#' @param x     a given list to be passed to a function
#' @param fn    a function to be applied to each list element
#' @param ...   additional arguments to fn function
.sits_parallel_recv_one_data <- function() {

    # fault tolerant version of parallel:::recvOneData
    cl <- sits_env[["cluster"]]

    # get connections
    socklist <- lapply(cl, function(x) x$con)

    # wait for data in socket
    repeat {
        ready <- socketSelect(socklist)
        if (any(ready)) break
    }
    # which cluster is going to be read
    worker_id <- which.max(ready)

    # fault tolerance change
    value <- tryCatch(
        {
            unserialize(socklist[[worker_id]])
        },
        error = function(e) {

            # catch only errors in connection
            if (grepl("error reading from connection", e$message)) {
                message(paste(
                    "An error has occurred in a node and a recovery",
                    "will be attempted at the end of the process"
                ))
                # reset node
                .sits_parallel_reset_node(worker_id)

                return(list(
                    node = worker_id,
                    value = list(
                        value = structure(list(), class = "retry"),
                        tag = NULL
                    )
                ))
            }
            # otherwise rise error
            stop(e)
        }
    )

    return(list(node = worker_id, value = value))
}

#' @rdname sits_parallel_fault_tolerant
.sits_parallel_recv_one_result <- function() {

    # fault tolerant version of parallel:::recvOneResult
    cl <- sits_env[["cluster"]]
    # fault tolerant version of parallel:::recvOneData
    v <- .sits_parallel_recv_one_data()

    return(list(value = v$value$value, node = v$node, tag = v$value$tag))
}

#' @rdname sits_parallel_fault_tolerant
.sits_parallel_cluster_apply <- function(x, fn, ..., pb = NULL) {

    # fault tolerant version of parallel::clusterApplyLB
    cl <- sits_env[["cluster"]]
    # number of jobs
    n <- length(x)
    # number of workers
    p <- length(cl)
    if (n > 0 && p) {
        # function to dispatch a job to a node
        submit <- function(node, job) {
            # get hidden object from parallel
            .send_call <- get("sendCall",
                              envir = asNamespace("parallel"),
                              inherits = FALSE
            )
            .send_call(
                con = cl[[node]],
                fun = fn,
                args = c(list(x[[job]]), list(...)),
                return = TRUE,
                tag = job
            )
        }
        # start initial jobs
        for (i in 1:min(n, p)) submit(i, i)
        # prepare result list
        val <- vector("list", n)
        # retrieve results and start jobs
        for (i in seq_len(n)) {
            # fault tolerant version of parallel:::recvOneResult
            d <- .sits_parallel_recv_one_result()
            # next job
            j <- i + min(n, p)
            if (j <= n) {
                submit(d$node, j)
            }
            # organize result
            if (!is.null(d$tag)) {
                val[d$tag] <- list(d$value)
                # update progress bar
                if (!is.null(pb)) {
                    utils::setTxtProgressBar(
                        pb = pb,
                        value = utils::getTxtProgressBar(pb) + 1
                    )
                }
            }
        }
        # get hidden object from parallel
        .check_remote_errors <- get("checkForRemoteErrors",
                                    envir = asNamespace("parallel"),
                                    inherits = FALSE
        )
        .check_remote_errors(val)
    }
}

#' @title Maps a function to a given list in parallel or sequential processing
#' @name .sits_parallel_map
#' @keywords internal
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#'
#' @param x               List to be passed to a function.
#' @param fn              Function to be applied to each list element.
#' @param progress        Show progress bar?
#' @param n_retries       Number of retries before fail.
#' @param sleep           Number in seconds to wait before trying again.
#'
#' @return               List with the function results in the same order
#'                       as the input list
#'
.sits_parallel_map <- function(x, fn, ..., progress = FALSE,
                               n_retries = 3, sleep = 0) {

    # create progress bar
    pb <- NULL
    progress <- progress && (length(x) > 0)
    if (progress) {
        pb <- utils::txtProgressBar(min = 0, max = length(x), style = 3)
    }
    # sequential processing
    if (purrr::is_null(sits_env[["cluster"]])) {
        result <- lapply(seq_along(x), function(i) {
            value <- fn(x[[i]], ...)

            # update progress bar
            if (progress) {
                utils::setTxtProgressBar(
                    pb = pb,
                    value = utils::getTxtProgressBar(pb) + 1
                )
            }
            return(value)
        })
        # close progress bar
        if (progress) {
            close(pb)
        }
        return(result)
    }

    # parallel processing
    values <- .sits_parallel_cluster_apply(x, fn, ..., pb = pb)

    # check for faults
    retry <- vapply(values, inherits, logical(1), "retry")

    # is there any node to be recovered?
    if (any(retry)) {
        # try three times
        for (i in seq_len(n_retries)) {
            # seconds to wait before try again
            Sys.sleep(sleep)
            # retry for faulted values
            values[retry] <- .sits_parallel_cluster_apply(
                x[retry], fn, ...,
                pb = pb
            )
            # check for faults again
            retry <- vapply(values, inherits, logical(1), "retry")
            if (!any(retry)) break
        }
        if (any(retry)) {
            stop("Some or all failed nodes could not be recovered",
                 call. = FALSE
            )
        }
    }
    # close progress bar
    if (progress) {
        close(pb)
    }
    return(values)
}
