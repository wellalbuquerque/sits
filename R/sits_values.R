#' @title Return the values of a set of time series
#' @name sits_values
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#'
#' @description This function returns the values of a sits tibble
#' (according a specified format).
#' This function is useful to use packages such as ggplot2, dtwclust, or kohonen
#' that require values that are rowwise or colwise organised.
#'
#' @param  data       A sits tibble with time series for different bands.
#' @param  bands      Bands whose values are to be extracted.
#' @param  format     A string with either "cases_dates_bands"
#'                    or "bands_cases_dates" or "bands_dates_cases".
#'
#' @return A matrix with values.
#' @examples
#' # Retrieve a set of time series with 2 classes
#' data(cerrado_2classes)
#' # retrieve the values split by bands and dates
#' ls1 <- sits_values(cerrado_2classes[1:2, ], format = "bands_dates_cases")
#' # retrieve the values split by cases (occurences)
#' ls2 <- sits_values(cerrado_2classes[1:2, ], format = "cases_dates_bands")
#' #' # retrieve the values split by bands and cases (occurences)
#' ls3 <- sits_values(cerrado_2classes[1:2, ], format = "bands_cases_dates")
#' @export
sits_values <- function(data, bands = NULL, format = "cases_dates_bands") {

    # set caller to show in errors
    .check_set_caller("sits_values")
    .check_chr_within(
        x = format,
        within = c(
            "cases_dates_bands",
            "bands_cases_dates",
            "bands_dates_cases"
        ),
        discriminator = "one_of",
        msg = paste(
            "valid format parameter are 'cases_dates_bands',",
            "'bands_cases_dates' or 'bands_dates_cases'"
        )
    )
    class(format) <- c(format, class(format))
    UseMethod("sits_values", format)
}
#' @export
sits_values.cases_dates_bands <- function(data, bands = NULL, format) {
    if (purrr::is_null(bands)) {
        bands <- sits_bands(data)
    }
    # populates result
    values <- data$time_series %>%
        purrr::map(function(ts) {
            data.matrix(dplyr::select(ts, dplyr::one_of(bands)))
        })
    return(values)
}
#' @export
sits_values.bands_cases_dates <- function(data, bands = NULL, format) {
    if (purrr::is_null(bands)) {
        bands <- sits_bands(data)
    }
    # populates result
    values <- bands %>% purrr::map(function(band) {
        data$time_series %>%
            purrr::map(function(ts) {
                dplyr::select(ts, dplyr::one_of(band))
            }) %>%
            data.frame() %>%
            tibble::as_tibble() %>%
            as.matrix() %>%
            t()
    })
    names(values) <- bands
    return(values)
}
#' @export
sits_values.bands_dates_cases <- function(data, bands = NULL, format) {
    if (purrr::is_null(bands)) {
        bands <- sits_bands(data)
    }
    values <- bands %>% purrr::map(function(band) {
        data$time_series %>%
            purrr::map(function(ts) {
                dplyr::select(ts, dplyr::one_of(band))
            }) %>%
            data.frame() %>%
            tibble::as_tibble() %>%
            as.matrix()
    })

    names(values) <- bands
    return(values)
}
