#' @title Apply a function on a set of time series
#'
#' @name sits_apply
#'
#' @author Rolf Simoes, \email{rolf.simoes@@inpe.br}
#' @author Felipe Carvalho, \email{felipe.carvalho@@inpe.br}
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description
#' Apply a named expression to a sits cube or a sits tibble
#' to be evaluated and generate new bands (indices). In the case of sits
#' cubes, it materializes a new band in `output_dir` using `gdalcubes`.
#'
#' @param data          Valid sits tibble or cube
#' @param memsize       Memory available for classification (in GB).
#' @param multicores    Number of cores to be used for classification.
#' @param output_dir    Directory where files will be saved.
#' @param ...           Named expressions to be evaluated.
#'
#' @return A sits tibble or a sits cube with new bands.
#'
#' @examples
#' # Get a time series
#' # Apply a normalization function
#'
#' point2 <-
#'   sits_select(point_mt_6bands, "NDVI") %>%
#'   sits_apply(NDVI_norm = (NDVI - min(NDVI)) / (max(NDVI) - min(NDVI)))
NULL

#' @rdname sits_apply
#' @export
sits_apply <- function(data, ...) {
    UseMethod("sits_apply", data)
}

#' @rdname sits_apply
#' @export
sits_apply.sits <- function(data, ...) {
    .check_set_caller("sits_apply.sits")

    .sits_fast_apply(data, col = "time_series", fn = dplyr::mutate, ...)
}

#' @rdname sits_apply
#' @export
sits_apply.raster_cube <- function(data, ...,
                                   memsize = 1,
                                   multicores = 2,
                                   output_dir = getwd(),
                                   progress = TRUE) {
    .check_set_caller("sits_apply.raster_cube")
    progress <- .check_documentation(progress)

    # Capture dots as a list of quoted expressions
    list_expr <- lapply(substitute(list(...), env = environment()),
                        unlist,
                        recursive = FALSE
    )[-1]

    # check bands names from expression
    .check_lst(list_expr,
               min_len = 1, max_len = 1,
               msg = "invalid expression value"
    )

    # Get out band
    out_band <- toupper(names(list_expr))
    names(list_expr) <- out_band

    # Check output_dir
    output_dir <- path.expand(output_dir)
    .check_file(output_dir,
                msg = "invalid output directory"
    )

    # Define function to give a name to output new file
    out_file_name <- function(tile_name, band, date, output_dir) {
        # Prepare file name
        file_prefix <- paste("cube", tile_name, band, date, sep = "_")
        file_name <- paste(file_prefix, "tif", sep = ".")
        file_path <- paste(output_dir, file_name, sep = "/")
        return(file_path)
    }

    # Define function to return a file_info of created band
    out_file_info <- function(in_fi_fid, band, output_file) {
        tibble::tibble(
            fid = in_fi_fid[["fid"]][[1]],
            date = in_fi_fid[["date"]][[1]],
            band = band,
            xmin = in_fi_fid[["xmin"]][[1]],
            xmax = in_fi_fid[["xmax"]][[1]],
            ymin = in_fi_fid[["ymin"]][[1]],
            ymax = in_fi_fid[["ymax"]][[1]],
            xres = in_fi_fid[["xres"]][[1]],
            yres = in_fi_fid[["yres"]][[1]],
            nrows = in_fi_fid[["nrows"]][[1]],
            ncols = in_fi_fid[["ncols"]][[1]],
            path = output_file
        )
    }


    # Prepare parallelization
    .sits_parallel_start(workers = multicores, log = FALSE)
    on.exit(.sits_parallel_stop(), add = TRUE)

    # Find the tiles that have not been processed yet
    jobs <- .apply_missing_band(
        cube = data,
        band = out_band
    )

    # Already processed?
    if (length(jobs) == 0) {
        return(data)
    }

    # Process bands and tiles in parallel
    images_lst <- .sits_parallel_map(jobs, function(job) {

        # Get parameters from each job
        tile_name <- job[[1]]
        band <- job[[2]]
        fid <- job[[3]]

        # Filter tile
        tile <- dplyr::filter(data, .data[["tile"]] == !!tile_name)

        # Post-condition
        .check_that(
            nrow(tile) == 1,
            local_msg = paste0("no tile '", tile_name, "' found"),
            msg = "invalid tile"
        )

        # Get all input bands in cube data
        in_bands <- .cube_bands(tile)

        # Find which bands are in input expressions
        char_expr <- toupper(deparse(list_expr[[out_band]]))
        used_bands <- purrr::map_lgl(in_bands, grepl, char_expr)

        # Pre-condition
        .check_that(any(used_bands),
                    local_msg = "no valid band was informed",
                    msg = "invalid expression value"
        )

        # Input bands
        in_bands <- in_bands[used_bands]

        # File_info filtered by bands
        in_fi_fid <- .file_info(
            cube = tile,
            bands = in_bands,
            fid = fid
        )

        # Output file name
        out_file_path <- out_file_name(
            tile_name = .cube_tiles(tile),
            band = out_band,
            date = in_fi_fid[["date"]][[1]],
            output_dir = output_dir
        )

        # Does output file exists?
        if (file.exists(out_file_path)) {
            return(out_file_path)
        }

        # Divide the input data in blocks
        blocks <- .apply_raster_blocks(
            nbands = length(in_bands),
            sub_image = .sits_raster_sub_image_default(tile),
            memsize = memsize,
            multicores = multicores
        )

        # Save each output value
        blocks_path <- purrr::map(blocks, function(b) {

            # Load bands data
            in_values <- purrr::map(in_bands, function(band) {

                # Transform file_info columns as bands and values as paths
                in_files <- in_fi_fid %>%
                    dplyr::select(dplyr::all_of(c("band", "path"))) %>%
                    tidyr::pivot_wider(
                        names_from = "band",
                        values_from = "path"
                    )

                # Get the missing values, minimum values and scale factors
                missing_value <-
                    .cube_band_missing_value(tile, band = band)
                minimum_value <-
                    .cube_band_minimum_value(tile, band = band)
                maximum_value <-
                    .cube_band_maximum_value(tile, band = band)

                # Scale the data set
                scale_factor <-
                    .cube_band_scale_factor(tile, band = band)
                offset_value <-
                    .cube_band_offset_value(tile, band = band)

                # Read the values
                values <- .raster_read_stack(in_files[[band]],
                                             block = b
                )

                # Correct NA, minimum, maximum, and missing values
                values[values == missing_value] <- NA
                values[values < minimum_value] <- NA
                values[values > maximum_value] <- NA

                # compute scale and offset
                values <- scale_factor * values + offset_value

                return(values)
            })

            # Set band names
            names(in_values) <- in_bands

            print(lapply(in_values, dim))

            # Evaluate expressions, scale and offset values
            out_values <- eval(list_expr[[out_band]], in_values)

            # Apply scale and offset
            out_values <- out_values /
                .config_get("raster_cube_scale_factor") -
                .config_get("raster_cube_offset_value")

            # Compute block spatial parameters
            params <- .cube_params_block(tile, block = b)

            # New raster
            r_obj <- .raster_new_rast(
                nrows = params[["nrows"]],
                ncols = params[["ncols"]],
                xmin = params[["xmin"]],
                xmax = params[["xmax"]],
                ymin = params[["ymin"]],
                ymax = params[["ymax"]],
                nlayers = 1,
                crs = params[["crs"]]
            )

            # Set values
            r_obj <- .raster_set_values(r_obj, out_values)

            # Define the file name of the raster file to be written
            filename_block <- paste0(
                tools::file_path_sans_ext(out_file_path),
                "_block_", b[["first_row"]], "_", b[["nrows"]], ".tif"
            )

            # Write values
            .raster_write_rast(
                r_obj = r_obj,
                file = filename_block,
                format = "GTiff",
                data_type = .config_get("raster_cube_data_type"),
                gdal_options = .config_gtiff_default_options(),
                overwrite = TRUE
            )

            # Clean memory
            gc()

            return(filename_block)
        })

        # Merge result
        blocks_path <- unlist(blocks_path)

        # Join predictions
        if (!is.null(blocks_path)) {
            .raster_merge(
                in_files = blocks_path,
                out_file = out_file_path,
                format = "GTiff",
                gdal_datatype = .raster_gdal_datatype(
                    .config_get("raster_cube_data_type")
                ),
                gdal_options = .config_gtiff_default_options(),
                overwrite = TRUE,
                progress = progress
            )
        }

        return(out_file_path)
    }, progress = progress, n_retries = 0)

    # Create local cube from files in output directory
    local_cube <- sits_cube(
        source = .cube_source(data),
        collection = .cube_collection(data),
        data_dir = output_dir,
        parse_info = c("x1", "tile", "band", "date"),
        multicores = multicores,
        progress = progress
    )

    # Find the tiles that have not been processed yet
    jobs <- .apply_missing_band(
        cube = data,
        band = out_band
    )

    # Have we finished? inform the user
    if (length(jobs) > 0) {

        # Convert list of missing tiles and bands to a list of vectors
        tiles_bands <- purrr::transpose(jobs)
        tiles_bands <- purrr::map(tiles_bands, unlist)

        # Get missing tiles
        bad_tiles <- unique(tiles_bands[[1]])

        # Get missing bands per missing tile
        msg <- paste(
            bad_tiles,
            purrr::map_chr(bad_tiles, function(tile) {
                paste0(
                    "(",
                    paste0(unique(
                        tiles_bands[[3]][tiles_bands[[1]] == tile]
                    ),
                    collapse = ", "
                    ),
                    ")"
                )
            }),
            collapse = ", "
        )

        # Show message
        message(paste("Could not process new band for tiles", msg))
    }

    return(local_cube)
}

#' @rdname sits_apply
#' @keywords internal
.apply_across <- function(data, fn, ...) {

    # Define function to show in case of error
    .check_set_caller(".apply_across")

    fn_across <- fn
    .sits_fast_apply(data, col = "time_series", fn = function(x, ...) {
        dplyr::mutate(x, dplyr::across(
            dplyr::matches(sits_bands(data)),
            fn_across, ...
        ))
    }, ...)
}


#' @title Finds the missing bands in a cube
#'
#' @name .apply_missing_band
#' @keywords internal
#'
#' @param cube       Data cube.
#' @param band       Band name.
#'
#' @return           List of combination among tiles, bands, and dates
#'                   that are missing from the cube.
#'
.apply_missing_band <- function(cube, band) {

    # Define function to show in case of error
    .check_set_caller(".apply_missing_band")

    # Pre-condition
    .check_length(band, len_min = 1, len_max = 1)

    tile_band_fid <- unlist(slider::slide(cube, function(tile) {
        tl <- sits_timeline(tile)
        fi <- .file_info(tile)
        fi_band <- fi[fi[["band"]] == band, ]
        missing_dates <- tl[!tl %in% fi_band[["date"]]]
        fi <- fi[fi[["date"]] %in% missing_dates, ]
        if (nrow(fi) == 0) {
            return(NULL)
        }
        purrr::cross3(.cube_tiles(tile), band, unique(fi[["fid"]]))
    }), recursive = FALSE)

    return(tile_band_fid)
}


#' @title Define a reasonable block size to process an image subset
#' @name .apply_raster_blocks
#' @keywords internal
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description Defines the size of the block of an image to be read.
#' For example, a Raster Brick with 500 rows and 500 columns
#' and 400 time instances will have a total pixel size
#' of 800 Mb if pixels are 64-bit.
#'
#' @param  nbands     Number of bands to open.
#' @param  sub_image  Bounding box of the ROI.
#' @param  memsize    Memory available for classification (in GB).
#' @param  multicores Number of cores to process the time series.
#' @return            List with three attributes: n (number of blocks),
#'                    rows (list of rows to begin),
#'                    nrows (number of rows to read at each iteration).
#'
.apply_raster_blocks <- function(nbands, sub_image, memsize, multicores) {

    # Define function to show in case of error
    .check_set_caller(".apply_raster_blocks")

    # Get the number of blocks
    nblocks <- .apply_raster_blocks_estimate(
        nbands = nbands,
        sub_image = sub_image,
        memsize = memsize,
        multicores = multicores
    )

    blocks <- .sits_raster_block_list(
        nblocks = nblocks,
        sub_image = sub_image
    )

    return(blocks)
}
#' @title Estimate the number of blocks
#' @name .sits_raster_blocks_estimate_apply
#' @keywords internal
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description Defines the number of blocks of a Raster Brick
#'              to be read into memory.
#'
#' @param  nbands     Number of bands to open.
#' @param  sub_image  Area of interest in the image.
#' @param  memsize    Memory available for classification (in GB).
#' @param  multicores Number of cores to process the time series.
#' @return            Number of blocks to be read.
.apply_raster_blocks_estimate <- function(nbands,
                                          sub_image,
                                          memsize,
                                          multicores) {

    # Define function to show in case of error
    .check_set_caller(".apply_raster_blocks_estimate")

    # Number of bytes per pixel
    nbytes <- 8
    # Estimated processing bloat
    proc_bloat <- as.numeric(.config_processing_bloat())
    if (proc_bloat == 0) proc_bloat <- multicores

    # Number of rows and cols
    nrows <- sub_image[["nrows"]]
    ncols <- sub_image[["ncols"]]
    # Single instance size
    output_data_size <- nrows * ncols * nbytes
    # Total size including all bands
    input_data_size <- output_data_size * nbands

    # Number of output instances is the same as input
    # Estimated size of the data for apply
    class_data_size <- (input_data_size + output_data_size) * proc_bloat

    # Number of passes to read the full data sets
    nblocks <- ceiling(class_data_size * 1e-09 / memsize * multicores)

    return(nblocks)
}
