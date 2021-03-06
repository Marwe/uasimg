#' Flight summaries
#'
#' Creates image collection summaries for individual flights (folders)
#'
#' @param x A list of class 'uas_info'
#' @param col Color value(s) of the centroids and/or footprints
#' @param group_img Group images within ~1m of each other into 1 point
#' @param thumbnails Create thumbails
#' @param show_gps_coord Show GPS coordinates of images in the pop-up windows, YN
#' @param show_local_dir Show the local image directory, TF
#' @param report_title Title to appear at the top of the summary
#' @param attachments Supplementary files to create and link to the flight summary, see Details.
#' @param output_dir If NULL, then will be placed in a 'map' sub-directory of the images
#' @param create_dir Create the output directory if it doesn't exist
#' @param output_file	Name of the HTML file. If NULL a default based on the name of the input directory is chosen.
#' @param overwrite_html Overwrite existing HTML files without warning, YN
#' @param open_report Open the HTML file in a browser
#' @param self_contained Make the output HTML file self-contained
#' @param png_map Whether to create a PNG version of the map. May be T/F, or dimensions of the output image in pixels (see Details)
#' @param overwrite_png Overwrite existing PNG files without warning, YN
#' @param png_exp A proportion to expand the bounding box of the PNG map, see Details.
#' @param google_api API key for Google Static Maps, see Details.
#' @param report_rmd Rmd template used to generate the HTML file. See Details.
#' @param quiet TRUE to supress printing of the pandoc command line
#'
#' @details This will generate HTML report(s) of the images in the UAS metadata object based.
#'
#' \code{group_img} determinies whether images at the same location are represented by a single point on the map. This is common with multi-spectral sensors that take generate multiple images per location. 'Same location' is determined by looking at the 5th decimal place of the x and y geographic coordinates (~1m),
#'
#' If no value for \code{output_dir} is passed, the report will be saved in a sub-directory of the image directory
#' called 'map'. This sub-directory will be created if \code{create_dir = TRUE}.
#'
#' \code{self_contained} determines whether the HTML file(s) created will have all the JavaScript and CSS files
#' embedded in the HTML file itself, or saved in a subdirectory called 'libs'. If saving several reports to one output directory,
#' If saving multiple HTML reports to the same output directory, passing \code{self_contained = FALSE} is more efficient
#'
#' The HTML report is generated from a RMarkdown file. If you know how to edit RMarkdown, you can modify the default template and pass the filename
#' of your preferred template using the \code{report_rmd} argument.
#'
#' \code{png_map} controls whether a PNG version of the map will be created in \code{output_dir}.
#' If TRUE, a PNG file at the default dimensions (480x480) will be created. If a single integer
#' is passed, it will be taken to be the width and height on the PNG file in pixels.
#' \code{png_exp} is a percentage of the points bounding box that will be used as a buffer
#' for the background map. If the map seems too cropped, or you get a warning message about rows
#' removed, try increasing it. By default, the background image will be a satellite photo from
#' Google Maps. However this requires a valid API Key for the Google Maps Static service, which you
#' pass with \code{google_api} (for
#' details see \url{https://developers.google.com/maps/documentation/maps-static/}. Alternately you
#' can save your API key with \code{ggmap::register_google()}, after which it will be read automatically.
#' If a Google API key is not found, a terrain map from Stamen will be substituted.
#'
#' \code{attachment} specifies which supplementary files to create and link to the flight summary. Choices are
#' \code{ctr_kml} and \code{mcp_kml} for KML versions of the camera locations and MCP (minimum convex
#' polygon around all images). These KML files will be created in the same output directory as the flight
#' summary.
#'
#' @return The HTML file name(s) of the flight summaries generated
#'
#' @seealso \code{\link{uas_info}}, \code{\link{uas_exp_kml}},
#'
#' @importFrom crayon green yellow bold
#' @importFrom grDevices dev.off png rainbow
#' @importFrom utils browseURL packageVersion
#' @importFrom tools file_path_sans_ext file_ext
#' @importFrom rmarkdown render
#' @importFrom methods is
#'
#' @export

uas_report <- function(x, col = NULL, group_img = TRUE, thumbnails = FALSE, show_gps_coord = FALSE,
                       show_local_dir = TRUE, report_title = "Flight Summary",
                       attachments = c("mcp_kml", "ctr_kml")[0],
                       output_dir = NULL, create_dir = TRUE, output_file = NULL, overwrite_html = FALSE,
                       open_report = FALSE, self_contained = TRUE, png_map = FALSE, png_exp = 0.2,
                       overwrite_png = FALSE, google_api = NULL, report_rmd = NULL,
                       quiet = FALSE) {

  ## THE MAGICK.EXE option has been disabled pending testing.
  ## When asked to process a folder of >1000 images, it quit after ~700 (consistently)
  ## @param use_magick Use ImageMagick command line tool to create the image thumbnails.
  ## use_magick = FALSE,

  if (!inherits(x, "uas_info")) stop("x should be of class \"uas_info\"")

  ## Get the Rmd template
  if (is.null(report_rmd)) {
    report_rmd <- system.file("report/uas_report.Rmd", package="uasimg")
  }
  if (!file.exists(report_rmd)) stop("Cant find the report template")

  ## Validate value(s) of kml
  if (is.null(attachments)) attachments <- character(0)
  if (length(attachments) > 0) {
    if (FALSE %in% (attachments %in% c("ctr_kml", "mcp_kml"))) stop("Unknown value(s) for `attachments`")
  }


  ## Set the size of the PNG map
  make_png <- FALSE
  if (identical(png_map, TRUE)) {
    png_dim <- c(480,480)
    make_png <- TRUE
  } else if (is.numeric(png_map)) {
    if (length(png_map)==1) png_map <- rep(png_map,2)
    if (length(png_map)!=2) stop("Invalid value for png_map")
    png_dim <- png_map
    make_png <- TRUE
  }

  if (make_png) {
    #if (!requireNamespace("ggmap", quietly = TRUE)) stop("Package ggmap required to make the png map")
    if (!require("ggmap", quietly = TRUE)) stop("Package ggmap required to make the png map")
    if (packageVersion("ggmap") < '3.0.0') stop("Please update ggmap package")
  }

  report_fn_vec <- NULL

  ## Start the loop
  for (i in 1:length(x)) {
    img_dir <- names(x)[i]

    if (identical(x[[img_dir]]$pts, NA)) {
      warning(paste0("Centroids not found for ", img_dir, ". Skipping report."))
      next
    }

    ## Get the output dir
    if (is.null(output_dir)) {
      output_dir_use <- file.path(img_dir, "map")
      if (!file.exists(output_dir_use) && create_dir) {
        if (!quiet) message(green("Creating", output_dir_use))
        if (!dir.create(output_dir_use, recursive = TRUE)) stop(paste0("Unable to create ", output_dir_use))
      }
    } else {
      output_dir_use <- output_dir
    }
    if (!file.exists(output_dir_use)) stop("Could not find report output directory")

    ## Get a filename base (to use for the HTML report, PNG, and KML files)
    if (is.na(x[[img_dir]]$metadata$name_short %>% null2na())) {
      fnbase <- x[[img_dir]]$id
    } else {
      fnbase <- x[[img_dir]]$metadata$name_short
    }

    ##################################################################
    ## Make the PNG map
    if (make_png) {

      ## Construct the map.png filename
      if (is.null(output_file)) {
        map_fn <- paste0(fnbase, "_map.png")

      } else {
        map_fn <- paste0(file_path_sans_ext(basename(output_file)), ".png")
      }

      if (overwrite_png || !file.exists(file.path(output_dir_use, map_fn))) {

        ## Lets make a png map

        ## Compute colors for the pts
        ## Note for the PNG map, there is no spatial grouping, but that shouldn't matter
        if (is.null(col)) {
          col_use <- rainbow(nrow(x[[img_dir]]$pts), end=5/6)
        } else {
          col_use <- col
        }

        # Define the extent and center point of the flight area
        pts_ext <- x[[img_dir]]$pts %>% sf::st_transform(4326) %>% st_bbox() %>% as.numeric()
        lon_idx <- c(1, 3)
        lat_idx <- c(2, 4)
        ctr_ll <- c(mean(pts_ext[lon_idx]), mean(pts_ext[lat_idx]))

        ## Compute the Zoom level (use a minimum of 18)
        zoom_lev <- min(18, ggmap::calc_zoom(lon = range( pts_ext[lon_idx]),
                                             lat = range( pts_ext[lat_idx]),
                                             adjust=as.integer(-1)))

        if (is.null(google_api) && !ggmap::has_google_key()) {
          ## Grab a Stamen map
          if (!quiet) message(yellow("Downloading a PNG image from STAMEN"))
          dx <- diff(pts_ext[lon_idx]) * png_exp
          dy <- diff(pts_ext[lat_idx]) * png_exp
          pts_ext <- pts_ext + c(-dx, -dy, dx, dy)
          m <- ggmap::get_stamenmap(bbox=pts_ext, zoom=zoom_lev, maptype="terrain")

        } else {
          ## Grab a Google Maps Static image
          if (!is.null(google_api)) {
            ggmap::register_google(key=google_api)
          }
          if (!quiet) message(yellow("Downloading a PNG image from GOOGLE"))
          m <- try(ggmap::get_googlemap(center=ctr_ll, zoom=zoom_lev,
                                        format="png8", maptype="satellite"))
          if (is(m, "try-error")) {
            warning("Failed to retrieve static map from Google Maps, check your API key. To use Stamen, don't pass google_api (if you saved it, run Sys.unsetenv('GGMAP_GOOGLE_API_KEY') )")
            m <- NULL
          }
        }

        if (!is.null(m)) {

          # Create the ggmap object and save to a variable
          pts_ggmap <- ggmap::ggmap(m) +
            geom_point(data = x[[img_dir]]$pts %>% sf::st_drop_geometry(),
                       aes(gps_long, gps_lat),
                       colour = col_use,
                       show.legend = FALSE,
                       size = 3) +
            theme_void()

          ## Open the PNG driver
          png(filename = file.path(output_dir_use, map_fn), width = png_dim[1], height = png_dim[2])

          ## Print the map to the PNG drive
          print(pts_ggmap)

          ## Close the PNG driver
          dev.off()

        }

      } else {
        if (!quiet) message(yellow(map_fn, "already exists. Skipping."))
      }


    } else {
      map_fn <- ""
    } ## if png_make
    ###########################################


    ##################################################################
    ## Create image thumbnails
    if (thumbnails) {

      ## Get the output folder
      tb_dir_use <- file.path(output_dir_use, "tb")
      if (!file.exists(tb_dir_use)) {
        if (!(dir.create(tb_dir_use))) {
          thumbails <- FALSE
          warning("Could not create thumbnail direcotry")
        }
      }

      if (thumbnails) {

        ## Call uas_thumbnails()
        tb_fn_lst <- uas_thumbnails_make(x, img_dir = img_dir, output_dir = tb_dir_use,
                                         tb_width = 400)

        # , use_magick = use_magick

        ## Save the base name of the thumbnail in the attribute table for the points, so it can be
        ## used in the leaflet map
        x[[img_dir]]$pts$tb_fn <- basename(tb_fn_lst[[img_dir]])

      }

    }  ## if thumbnails = TRUE

    ## If thumbnails is (still) FALSE, fill the column with NA
    if (!thumbnails) x[[img_dir]]$pts$tb_fn <- NA

    ## Get the HTML report output filename
    if (is.null(output_file)) {
      output_file_use <- paste0(fnbase, "_report.html")
    } else {
      output_file_use <- output_file
    }

    if (overwrite_html || !file.exists(file.path(output_dir_use, output_file_use))) {

      ## In order to create HTML output which is *not* self-contained, we must
      ## manually copy the css file to the output dir. We must also
      ## temporarily copy the RMd file to the output dir, because knitr
      ## creates the lib_dir relative to the location of the Rmd file (with no
      ## other arguments or options)

      if (self_contained) {
        output_options <- list()
        report_rmd_use <- report_rmd

      } else {
        ## Copy the Rmd file to the output_dir (temporarily)
        ## If output_dir is specfied, only need to do this on the first pass
        if (is.null(output_dir) || i == 1) {
          file.copy(from=report_rmd, to=output_dir_use, overwrite = FALSE)
          report_rmd_use <- file.path(output_dir_use, basename(report_rmd))

          ## Copy the CSS file to the output_dir (permanently)
          report_css <- system.file("report/uas_report.css", package="uasimg")
          file.copy(from=report_css, to=output_dir_use, overwrite = FALSE)

          ## Create a list of output options that specify not self contained
          output_options <- list(self_contained=FALSE, lib_dir="libs")
        }
      }

      ## Compute colors for the pts and fp
      if (is.null(col)) {
        # col_use <- rainbow(nrow(x[[img_dir]]$pts), end=5/6)
        col_use <- NA
      } else {
        col_use <- col
      }

      ## Generate a KML file with the MCP
      if ("mcp_kml" %in% attachments) {
        kml_mcp_fn <- paste0(fnbase, "_mcp.kml")
        if (!file.exists(file.path(output_dir_use, kml_mcp_fn))) {
          uas_exp_kml(x, mcp = TRUE, output_dir = output_dir_use, img_dir = img_dir, out_fnbase = fnbase)
        }
      } else {
        kml_mcp_fn <- NA
      }

      ## Generate a KML file with the centers
      if ("ctr_kml" %in% attachments) {
        kml_ctr_fn <- paste0(fnbase, "_ctr.kml")
        if (!file.exists(file.path(output_dir_use, kml_ctr_fn))) {
          uas_exp_kml(x, ctr = TRUE, output_dir = output_dir_use, img_dir = img_dir, out_fnbase = fnbase)
        }
      } else {
        kml_ctr_fn <- NA
      }

      ## Render the HTML file
      report_fn <- render(input = report_rmd_use,
                          output_dir = output_dir_use, output_file = output_file_use,
                          output_options = output_options,
                          params = c(x[[img_dir]], list(col = col_use, img_dir = img_dir,
                                                        group_img = group_img,
                                                        show_local_dir = show_local_dir,
                                                        map_fn = map_fn,
                                                        thumbnails = thumbnails,
                                                        show_gps_coord = show_gps_coord,
                                                        kml_mcp_fn = kml_mcp_fn,
                                                        kml_ctr_fn = kml_ctr_fn,
                                                        report_title = report_title
                                                        )
                                              )
                                     )

      ## Add the filename to report_fn_vec which will eventually be returned
      report_fn_vec <- c(report_fn_vec, report_fn)

      ## If not self-contained, delete the temporary copy of the Rmd file
      if (!self_contained) {
        if (is.null(output_dir) || i == length(x)) {
          file.remove(report_rmd_use)
        }
      }


    } else {
      message(yellow(output_file_use, "already exists. Skipping."))

      ## If the HTML file already exists (but wasn't overwritten), return it just the same
      if (file.exists(file.path(output_dir_use, output_file_use))) {
        report_fn_vec <- c(report_fn_vec, file.path(output_dir_use, output_file_use))
      }


    }

  }

  message(green("Done."))

  ## Open the file(s)
  if (open_report) {
    for (report_fn in report_fn_vec) {
      browseURL(report_fn)
    }
  }

  ## Return the filename(s) of the HTML file(s) (invisibly)
  invisible(report_fn_vec)
}

