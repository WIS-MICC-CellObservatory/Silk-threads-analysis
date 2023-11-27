# Silk-threads-analysis
We use Fiji, and Ilastik to analyse the structure silk fibers.
## Overview
Given an image of silk fibers and Roi indicating reagons of interest and specific fibers of interest we do the following:
1. Use Ilastik to identify the images in the image
2. Use Fiji to analyse the fibers within the reagon of interest
3. Use Fiji to do additional analysis on the specific fibers marked by the user
## Ilastik modeling
We trained an auto-context Ilastik model to identify fibrillated structures in an image. To optimize the identification, three independent models were developed for each type of fibrillated structure: for bundles inside and outside a gland, and for the fibers at the nano-fibrlis stage. For each model the training used at least 3 representative images (available in the [Ilastik folder](../../tree/main/Ilastik))..
Use Cellpose to identify cells
Use StarDist/Cellpose to identify the LDs
Use Fiji to count and measure the LDs in each cell
Use Fiji’s SSIDC cluster indicator plugin to identify LD clusters
Use Ilastik to identify the mitochondria
Use Excel to categorize cells according to the LDs clustering and the size of the mitochondria.
All analysis is done on a Max intensity projection of the Z stack except the mitochondria segmentation. There we used the middle slice (4th slice out of 7). The Fiji macro orchestrating all these steps is available at the Fiji folder.
**Fiber identification**: We trained an auto-context Ilastik model which we "toaght" the software to identify fibrillated structures in an image. To optimize the segmentation, an independent model was developed for each type of fibrillated structure: bundels inside a fland, outside a gland and for the nano-fibrlis stage. In each model the training used at least 3 repersentative images
,  to optimize the auto-segmentation A two-stage process was done to specify and teach the software to identify the "fibers" (nano-fibrillated structures) on at least three images. The FIJI script then uses the "skeletonize" method and defines a segment to be a part of the skeleton between two adjacent fiber intersections. Two types of fiber segments are defined by determining their orientation: "Main fibers" are the fibrillated structures formed in the direction of the silk feedstock flow, and "Connecting fibers" (only for nano-bundles), are small nano-fibrils roughly perpendicular to the main fibers and connect them. Local thickness32 is calculated for the binary mask and measured along the center line of the skeleton. "
