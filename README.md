# Silk-threads-analysis
We use Fiji and Ilastik to analyse the structure of silk fibers.
![fibers image](https://github.com/WIS-MICC-CellObservatory/Silk-threads-analysis/assets/64706090/30f48944-ae78-4cdf-8f4e-8ef15f0ee13e)
## Overview
Given an image of silk fibers and Roi file indicating regions of interest and specific fibers of interest we do the following:
1. Use Ilastik to identify the fibers in the image
2. Use Fiji to analyse the fibers within the regions of interest
3. Use Fiji to do additional analysis on the specific fibers marked by the user

The Fiji macro orchestrating all these steps is available at the [Fiji folder](../../tree/main/Fiji).

## Ilastik modelling
We trained an auto-context Ilastik model to identify fibrillated structures in an image. To optimize the identification, three independent models were developed for each type of fibrillated structure: for bundles inside and outside a gland, and for the fibers at the nano-fibrlis stage. For each model the training used at least 3 representative images (available in the [Ilastik folder](../../tree/main/Ilastik)).

The Ilastik version used to train and run the models is 1.3.3post3
## Nano-fibrils (Main fibers) and nano-bundles analysis (Connecting fibers)
1. The image is converted to mask by running the Ilastik model to identify the fibers in it
![IlastikMask](https://github.com/WIS-MICC-CellObservatory/Silk-threads-analysis/assets/64706090/f8c05ee3-c0bf-45ee-a03a-c7b440433725)
## Semi-automated-analysis
Here we specifically analyse the line rois provided by the user in the Roi file (see [Appendix](##Appendix-ROI)). These ROIs mark “Connecting fibers” of a specific "ladder" (consecutive fibers between two “Main fibers”). For each “Connecting fiber” in the ladder we calculate its width (min, max and mean) and its distance to the next connecting fiber in the ladder (min, max and mean). To get this information we do the following:
1. first we run "Local thickness" on the image that creates an image where every pixel is replaced by its thickness (the radios of the maximal circle containing the pixel where the circle is fully resides in the image foreground)
![local thickness](https://github.com/WIS-MICC-CellObservatory/Silk-threads-analysis/assets/64706090/2da3f950-d96c-429c-892e-066ba2be4e73)
2. Then, for each ROI in each ladder in each region of interest we extract its min, max and mean width.
3. To get the distance information between each connecting fiber to the next fiber we first create a mask containing only that fiber, and run a distance transform on it, getting the distance of any other pixel in the image to that fiber.
![distance transform](https://github.com/WIS-MICC-CellObservatory/Silk-threads-analysis/assets/64706090/c04b95fc-d760-445f-a52d-d13a075ce8d7)
5. Then, we find the fiber that its mid coordinates are the closest to that fiber. looking at the pixels of that fiber in the distance transform image gives us the desired distance information.

All measurements are scaled to microns using the "Scale" ROI provided by the user(see [Appendix](##Appendix-ROI))
## Appendix-ROI
The ROI file provided by the user has the Fiji ROI file format and must be stored on disk at the same folder where the related image resides. Following Fiji's convention, the ROI file name should be identical to the image file name with "_RoiSet" suffix and a ".zip" extension.

The ROIs within the ROI file follow the following naming convention:
1. "Scale" region: A line ROI that its length is equal to 200 microns - Use to scale the image
2. "RM" prefix indicates a region of interest where automatic fiber analysis is to be conducted
3. "RC" prefix indicates a region of interest that contains a ladder - set of connecting fibers that connects two main fibers.
4. All other ROIs in the file are line ROIs contained within an "RC" ROI marking the fibers of interest to be further analysed (see [Semi-automated-analysis](#Semi-automated-analysis)).
