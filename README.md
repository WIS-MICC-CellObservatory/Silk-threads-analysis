# Silk-threads-analysis
We use Fiji, and Ilastik to analyse the structure of silk fibers.
## Overview
Given an image of silk fibers and Roi file indicating reagons of interest and specific fibers of interest we do the following:
1. Use Ilastik to identify the fibers in the image
2. Use Fiji to analyse the fibers within the reagons of interest
3. Use Fiji to do additional analysis on the specific fibers marked by the user
## Ilastik modeling
We trained an auto-context Ilastik model to identify fibrillated structures in an image. To optimize the identification, three independent models were developed for each type of fibrillated structure: for bundles inside and outside a gland, and for the fibers at the nano-fibrlis stage. For each model the training used at least 3 representative images (available in the [Ilastik folder](../../tree/main/Ilastik)).
## Nano-fibrils and nano-bundles analysis

## Appendix - Roi Structure
The roi file provided by the user has the Fiji roi file format and must be stored on disk at the same directory where the related image resides. Following Fiji's convention, the roi file name should be identical to the image file name with "_RoiSet" suffix and a ".zip" extention.

The ROIs within the roi file follow the following naming convention:
1. "RC" prefix indicates a region of interest containg specific fibers to analyze.
2. "RM" prefix indicates a region of interest where automatic fiber analysis is to be conducted
3. "Scale" region: A line ROI that its length is equal to 200 microns - Use to scale the image
4. All other rois in the file are line rois indicating fibers of interest to be further analyzed.
