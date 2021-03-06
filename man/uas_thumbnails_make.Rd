% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/uas_thumbnails_make.R
\name{uas_thumbnails_make}
\alias{uas_thumbnails_make}
\title{Create image thumbnails}
\usage{
uas_thumbnails_make(
  x,
  img_dir = NULL,
  output_dir = NULL,
  tb_width = 400,
  overwrite = FALSE,
  use_magick = FALSE,
  quiet = FALSE
)
}
\arguments{
\item{x}{A list of class 'uas_info'}

\item{img_dir}{Image folders in x to process (NULL to process all)}

\item{output_dir}{Output directory}

\item{tb_width}{Thumbnail width}

\item{overwrite}{Overwrite existing files}

\item{use_magick}{Use the ImageMagick command line tool}

\item{quiet}{Suppress messages}
}
\value{
A named list (one element for each directory processed) of thumbnail files created in the output directory
}
\description{
Move UAS images into sub-directories by group
}
\details{
This will create thumbnail images for the drone images in \code{x}. \code{img_dir} allows you to specify a subset of folders
in \code{x} to process. The default output folder is a sub-directory of each image
folder called \emph{map/tb}, which will be created if needed. This location can be overridden with \code{output_dir}.
The dimensions of the thumbnails is determined by \code{tb_width}, from which the height is set automatically.

Thumbnail files will be given an 8-character suffix that looks random but is actually generated from the image contents.
This is to prevent clashes when thumnbail files from different flights are 'gathered' into a single folder attached to
a Table of Contents folder (see \code{\link{uas_toc}}).

If \code{use_magick = TRUE}, the function will create the thumbnail images using the ImageMagick command
line tool (\emph{magick.exe}). This is a slightly faster way to generate thumbnails, which may help when you're
creating thumbnails for 1000s of images. However you don't get the benefit of a progress bar. This option requires you to have \href{https://imagemagick.org/}{ImageMagick} installed.
When installing the software, be sure to check the box that says 'Add application directory to your system path'.
Note you'll have to restart RStudio after you install ImageMagick. You can test whether the command line tool is
available to R by running \code{findonpath("magick.exe")} (MacOS users should omit the .exe extension).
}
\seealso{
\link{uas_report}
}
