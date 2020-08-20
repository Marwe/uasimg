
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
<!-- badges: end -->

# Drone Image Utilities

`uasimg` helps manage images taken from an Unmanned Aerial System (i.e.,
drone) that have been collected with the intent to stitch into high
resolution orthomosaics and other data products. The package does
**not** stitch images, but helps you create catalogs of your images,
visualize their locations, export image centroids and estimated
footprints as GIS files, and create world files so individual images can
be viewed in GIS software.

## Applications

`uasimg` was developed to help with the following data management tasks:

1.  Doing a quick check in the field to review the locations of a set of
    images, and the estimated image overlap. Checking for drop-outs and
    overlap, along with spot checking images for blurriness, can help a
    pilot determine if a flight was successful, or needs to be redone.

2.  Subsetting images for further processing with a photogrammetry
    (stitching) program like Pix4D or Agisoft. Omitting images with an
    extreme amount of overlap can improve results and reduce processing
    time.

3.  Creating HTML summary reports for individual flights, to serve as a
    catalog for your image collections.

4.  Creating auxillary world files to view individual images in GIS
    software, using the image EXIF data to model the ground footprint
    and rotation.

**Note**: image locations and footprints are based on the metadata saved
in the image files (e.g., height above the launch point, compass
direction of the camera). Thus they should considered as *estimates
only*.

## Data Requirements

Most functions in `uasimg` use location ifnormation saved in the EXIF
data (header) of image files themselves. This requires the camera to
save the save the location info in the image files, using a GPS location
provided by the drone or the camera itself. To compute footprints, the
package also needs to know the height at which images were taken. Some
drones (including many DJI drones) record the relative flight altitude
(above the launch point) in the image file. Flight height can also be
entered manually as an argument.

Requirements for using the package include:

  - the images must have been taken by a camera that saved the GPS
    coordinates  
  - image files should be grouped in directories folders (typically each
    directory containing the images from one flight)
  - the camera model must be one of the ones known by the `uasimg`
    package (see below)

Additional requirements in order to generate estimated footprints:

  - the height above ground level must be saved in the image files, or
    passed as an argument. If passed as an argument, the assumption is
    that all images were taken from the same height.  
  - it is presumed that images were taken at nadir (camera pointing
    straight down)

## Accuracy of the Estimated GSD and Image Footprints

The estimated image footprints and GSD are based on the recorded height
above ground level (usually taken to be the launch point). If the study
area was flat and the flight lines were at the same elevation, using the
relative altitude from the image headers, or passing the flight height
as an argument, should be relatively accurate. Note however most drones
measure height above the launch point based on changes in barometric
pressure, the accuracy of which varies.

In hilly areas or where the altitude of camera locations was variable,
image footprints and GSD will be over or under estimated. In locations
where the distance from the drone to the ground was bigger than the
altitude above the launch point, the GSD and footprint will be
under-estimated (i.e., smaller than reality). Conversely when the
distance to the ground is smaller than the flight altitude, the
estimated GSD and footprint will be over-estimated.

## Installation

This package is not yet on CRAN, but you can install it from GitHub.

Note: if you’re using a Windows machine, you must have RTools installed
to build packages from source files (which is what you do when you
install from GitHub). RTools is not a R package, rather its a set of
utilities that you install separately. You can download the setup file
from <https://cran.r-project.org/bin/windows/Rtools/>. Alternately, you
can install RTools from within R by running:

``` r
install.packages('installr')
installr::install.Rtools()
```

With RTools installed, you can install `uasimg` with a function from the
devtools package.

``` r
install.packages("devtools") 
devtools::install_github("ucanr-igis/uasimg")
```

If you get an error message about dependent packages not being
available, see the note about dependencies below.

## Dependencies

The package requires several packages, including *sf*, *leaflet*,
*dplyr*, *tidyr*, and *htmltools* (see the DESCRIPTION file for a
complete list). If you get an error message when installing *uasimg*,
install the dependent packages separately (i.e., from the ‘Packages’
pane in RStudio). Then run `remotes::install_github("ucanr-igis/uasimg",
dependencies=FALSE)`.

### Exiftool

To read the EXIF data from the image files, `uasimg` requires an
external free command line tool called ‘exiftool’. This can be installed
in four steps:

1.  download the file from:
    <http://www.sno.phy.queensu.ca/~phil/exiftool/>
2.  uncompress / unzip
3.  rename the executable file from *exiftool(-k).exe* to
    *exiftool.exe*  
    **Note**: if you have file extensions hidden in Windows Explorer,
    you won’t see *.exe* in the filename. In that case, just rename
    ‘*exiftool(-k)*’ to ‘*exiftool*’.
4.  move the executable file to a directory on the path (e.g.,
    c:\\windows). Note: putting it in c:\\windows\\system32 does *not*
    seem to work.

# Usage

## Supported Cameras

To see a list of known cameras (sensors), run `uas_cameras()` with no
arguments. If your camera is not listed, you may submit an issue on
GitHub to have it added, or pass the camera parameters in as a csv file.
See the help page (`?uas_cameras`) or contact the package author for
details.

There are three main functions you’ll use to manage your image data:

`uas_info()` returns a ‘metadata object’ for one or more directories of
images. You always start with this.

`uas_report()` takes a metadata object and generates a HTML report(s).

`uas_exp()` takes a metadata object and exports the image centroids and
footprints as Shapefiles.

For more info about arguments and options for each function, see their
help pages.

## Example

The general usage is to first create a metadata object for one or more
directories of images using the *uas\_info()* function, saving the
result to a variable.

``` r
library(uasimg)
mydir <- "c:/Drone_Projects/Hastings/Flt01_1443_1446_250ft"
file.exists(mydir)
hasting_imgs <- uas_info(mydir)
hasting_imgs
```

Once an image collection metadata object has been created, you can
generate outputs.

``` r
## Generate an HTML report of the images in the catalog
uas_report(hasting_imgs)

## Export image centroid, footprints, and minimum convex polygon
uas_exp(hasting_imgs)

## Generate estimated world files so the images can be imported into ArcGIS or QGIS
uas_worldfile(hasting_imgs)
```

# Details

## Image Collection Metadata

You create an image collection metadata object with `uas_info()`.
Multiple image collections (directories) can be combined in a single
metadata object if you pass a vector of directories to `uas_info()`

If the altitude above the launch point is not saved in the images
themselves, you can pass it with the `alt_agl` argument. This assumes
that all images were taken at the same altitude.

You can cache the EXIF data for an image collection by passing
cache=TRUE (see help for additional options). Cached EXIF data is
connected to a directory of images based on the directory name and total
size of all image files. Hence if images are added or removed from the
directory, the cache will be automatically rebuilt the next time you run
`uas_info()`.

Image Collection metadata includes information extracted from the image
files, such as the date flown and camera type. Additionally, you can
record things like the pilot, a short description, data URL, contact
person, etc. These optional fields can be passed as arguments to
`uas_info()`, or put in a text file in the same directory as the images
(recommended). See help page for details.

## Image Collection Summary Report

`uas_report()` creates a summary report of an image collection in HTML
format. The report includes an embedded interactive leaflet map
([sample](https://ucanr-igis.github.io/webassets/hrec_watershed1_rpt.html)),
as well as summary statistics of the estimated above ground height and
overlap.

`uas_report()` includes an option to generate a thumbnail image of the
camera locations. The thumbnail image does not appear in the HTML
report, but is useful for other types of previews, including markdown
and the master table of contents (below). To create a thumbnail with a
satellite image background, you must pass a Google Maps API key to
`uas_report()`. Alternately the thumbnail will contain a background
terrain map from Stamen. See the help page for details.

## Creating a Master Table of Contents

Whereas `uas_report()` creates HTML summaries for individual directories
(flights), `uas_toc()` creates a master table of contents of those
summaries. The main argument in `uas_toc()` is a vector of HTML file
names.

Options in `uas_report()` include gathering (i.e., copying) the HTML
files to a single directory. You can also provide a custom title for the
TOC, as well as a header and footer for branding purposes.

## Exporting Image Collection Geometry

You can export the geometry of an image collection metadata object with
`uas_exp()`, including image centroids, the (estimated) footprints, and
MCP (minimum convex polygon). Layers are exported as Shapefiles, a
common format for GIS data.

## World Files

Drone images typically save the coordinates of the camera, but do not
include the width, length, or compass angle. A “world file” is a small
external file that contains these additional parameters, so that when
you import an individual image into a GIS program like ArcGIS or QGIS,
the image will appear in its approximate footprint on the ground.

You can create world files, readable by ArcGIS and QGIS, with
`uas_worldfile()`. `uas_worldfile()` can create three types of world
files, including `aux.xml`, `jpw` and `tfw`, and `prj` files. `aux.xml`
is the most recognized format and the default. See the function help
page for details.

# Bugs, Questions, and Feature Requests

To add your camera to the package, report a bug, or suggest a new
feature, please create an
[issue](https://github.com/ucanr-igis/uasimg/issues) on GitHub, or
contact the package author.
