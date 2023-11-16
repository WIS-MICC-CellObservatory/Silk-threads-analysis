/***
1.	For each file and its corresponding rois
1.1.	run ilastik model to identify fibers
1.2.	Run local thickness on the fiber mask to get the width of each fiber
1.3.	Load the rois related to the file with specific regions and fibers of interest
1.4.	Measure the Min, Max, and avergae thickness of each fiber of interest in the ROI 
1.5.	Calculate the orientation of each fiber of interest
1.5.1.	looking at the horizontal fibers in each region, sort them according to their center of mass from the lowest to the heighst in the image
1.5.2.	for each horizintal fiber - calculate the ditance of the next (heighr) horizontal fiber to it - giving - min, max and average values
***/

//#@ String(label="Process Mode", choices=("singleFile", "wholeFolder", "AllSubFolders"), style="list") iProcessMode
var iProcessMode = "singleFile";
//#@ String(label="File Extension",value=".nd2", persist=true, description="eg .tif, .nd2") iFileExtension


#@ File(label="Ilastik, executable",value="C:\\Program Files\\ilastik-1.3.3post3\\ilastik.exe", persist=true, description="Ilastik executable") iIlastikExe
#@ File (label="Fiber Ilastik model path",value="A:\\UserData\\ehuds\\Projects\\Sabita\\Mitochondria_LD\\Mito.ilp", persist=true, description="Ilastik model path") iIlastikModelPath

#@ Boolean(label="Ilastik, use previous run",value=true, persist=true, description="for quicker runs, use previous Ilastik results, if exists") iUseIlastikPrevRun
#@ Integer(label="Main fiber direction (0 - 179)", value=90, persist=true, description="90 if vertical") iMainGeneralOrientation
#@ Integer(label="Main fiber variance (0 - 90)",value="20", persist=true, description="angles relative to main fiber still considered to be main") iMainAngleVariance
#@ Integer(label="Skeleton segment min. length (nano-microns)",value="5", persist=true, description="Small fiber segments will be ignored") iMinSkeletonLength
#@ Integer(label="Scale roi length (nano-microns)",value="200", persist=true, description="Expect 'Scale...' ROI") iScaleRoiNanoMicronLength
#@ Boolean (label="Dynamic connecting fiber truncation",value=true, persist=true, description="Exclude from connecting fiber calculation the junction thickness") iTruncateConnectingFiber



//----Macro parameters-----------
var pMacroName = "SilkLedders";
var pMacroVersion = "1.0.1";

var gMainFiberColor = "blue";
var gConnectingFiberColor = "red";
var gRCcolor = "yellow";
var gRMcolor = "pink";
var gUserFiberColor = "green";
var gFibersOutlineColor = "Magenta";

//----- global variables-----------
/*var gMitoChannel = 3;
var gLDChannel = 1;
var gCellsLabelsImageId = -1;
var gLDsLabelsImageId = -1;
var gMitoZimageId = -1;
var gTempROIFile = "tempROIs.zip";
var gNumCells = -1;
var gStarDistWindowTitle = "Label Image";
var gLDZimageId = -1;
var gManualRoi = false;
var gFirstClusterRoi = true;
var gFibersMaskImageId = -1;

var gCellposeExtRunSubdir = "/Segmentation/";
var gCellposeExtRunFileSuffix = "_cp_masks.tif";
var gRoiLineSize = 2;
var gCellsColor = "yellow";
var gLDsColor = "red";
var gClustersColor = "blue";
var gMitoColor = "pink";

var gLDRois = "LDs_rois";
var gCellsRois = "Cells_rois";
var gClustersRois = "Clusters_rois";
var gMitoRois = "Mito_rois";
var gLDCellposeModel = "LDCellpose";
var gMitoCellposeModel = "MitoCellpose";
*/
var gIlastikSegmentationExtention = "_Segmentations Stage 2.h5"; // "_Segmentations.h5"

var gSaveRunDir = "SaveRun"
var gFileFullPath = "uninitialized";
var gFileNameNoExt = "uninitialized";
var gResultsSubFolder = "uninitialized";
var gImagesResultsSubFolder = "uninitialized";
var gMainDirectory = "uninitialized";
var gSubFolderName = "";
var gRoisSuffix = "_RoiSet"
var gImageId = -1;

var gScale = 1.0;

var	gCompositeTable = "CompositeResults";
var	gAllCompositeTable = "allCompositeTable";
var gAllCompositeResults = 0; // the comulative number of rows in allCompositeTable

var width, height, channels, slices, frames;
var unit,pixelWidth, pixelHeight;
/***


var gH5OpenParms = "datasetname=[/data: (1, 1, 1024, 1024, 1) uint8] axisorder=tzyxc";
var gImsOpenParms = "autoscale color_mode=Default view=Hyperstack stack_order=XYCZT series_"; //bioImage importer auto-selection

var gROIMeasurment = "area centroid perimeter fit integrated display";
//------ constants--------
var GAUSSIAN_BLUR = 0;

var CD35_CHANNEL = 4
var CD23_CHANNEL = 2
var DAPI_CHANNEL = 1
var TCELLS_CHANNEL = 3
var	gHemiNames = newArray("Left","Top","Right","Bottom");
var gChannels = newArray("None","Dapi","CD23","T Cells","CD35");
//-------macro specific global variables
var gCD35ImgId = 0;
var gCD23ImgId = 0;
var gTCellsImgId = 0;
var gDapiImgId = 0;
var gTCellsBitmapImgId = 0;
var gCD35SmoothImgId = 0;

var hHorizontal = -1;
var hVertical = -1;
var gLineWidth = -1;
var rAngle = -1;
var sinAngle = -1;
var cosAngle = -1;
var cX = -1;
var cY = -1;
var switch;
***/

//-----debug variables--------
var gDebugFlag = false;
var gBatchModeFlag = false;
//------------Main------------
Initialization();

//iMainAngleVariance *= PI/180;
//iMainGeneralOrientation *= PI/180;
if(LoopFiles())
{
	SaveParms(gResultsSubFolder);
	print("Macro ended successfully");
}
else
	print("Macro failed");
CleanUp(true);
waitForUser("=================== Done ! ===================");

	
function ProcessFile(directory) 
{
	setBatchMode(gBatchModeFlag);
	//initVariables();
	
	if(!openFile(gFileFullPath))
		return false;
	gFileNameNoExt = File.getNameWithoutExtension(gFileFullPath);
	roiPath = File.getDirectory(gFileFullPath)+gFileNameNoExt+gRoisSuffix;
	if(!openROIsFile(roiPath,true))
		print("Warning: could not find ROI file " + roiPath + ".roi");
	
	ScaleImageByRoi();	
//	gImagesResultsSubFolder = gResultsSubFolder + "/" + gFileNameNoExt;	
	gImagesResultsSubFolder = gResultsSubFolder + gFileNameNoExt;	
	File.makeDirectory(gImagesResultsSubFolder);
	File.makeDirectory(gImagesResultsSubFolder+"/"+gSaveRunDir);
	run("Select None");
	gImageId = getImageID();
	run("Duplicate...", "title=Fibers Image");
	//rename(gFileNameNoExt);
	imageId = getImageID();
	
	// done in checkinput in openfile
	//getDimensions(width, height, channels, slices, frames);
	//getPixelSize(unit,pixelWidth, pixelHeight);	
	
	//prepare image for Ilastik and cellpose

	//gMitoZimageId = DupChannelAndZProject(imageId,gMitoChannel);
	//Get Mitochondria mask using Ilastik
	fibersImageId = GetFibers(imageId);
	run("Duplicate...", "title=ToThickness1");
	dupImageId = getImageID();

	thicknessImageId = GenerateThicknessTable(fibersImageId);

	AnalyzeMainFibers(dupImageId, thicknessImageId);
	
	// add fibers outline as roi
	GenerateFibersOutline(fibersImageId);
	
	GenerateOutput();
	return true;

}
function ScaleImageByRoi()
{
	roiIndex = SelectRoiByPrefix("Scale");

	if(roiIndex < 0)
	{
		("Error: could not find scale roi. hence all values are provided in pixels");
		gScale = 1.0;
		return;
	}
	//extract nano-micron length from roi name
	scaleMicronLen = 
	roiManager("Select", roiIndex);
	run("Clear Results");
	run("Measure");
	len = Table.get("Perim.",0, "Results");
	gScale =  iScaleRoiNanoMicronLength / len;
}

function GenerateFibersOutline(fibersImageId)
{
	selectImage(fibersImageId);
	run("Create Selection");
	roiManager("Add");
	roiManager("Select", roiManager("count")-1);
	roiManager("Rename", "Fibers_Outline");
	roiManager("Set Color", gFibersOutlineColor);
	roiManager("Set Line Width", 0);	
}
function GenerateOutput()
{
	cellsRoiPath = gImagesResultsSubFolder+"/RoiSet.zip";
	roiManager("deselect");
	roiManager("save", cellsRoiPath);
	
	selectImage(gImageId);
	roiManager("show all without labels");
	saveAs("Tiff",gImagesResultsSubFolder+"/Rois overlay.tif");
	run("Flatten");
	saveAs("Jpeg", gImagesResultsSubFolder+"/Rois.jpg");
}
function GetFibers(imageId)
{
	gFibersMaskImageId = RunIlastikModel(imageId);
	// generate rois and save them for image output
	selectImage(gFibersMaskImageId);
	//ClearRoiManager();	
	// turn the fiber mask into local thickness map (2 is the value of the fiber in the mask and 1 is the background)
	//waitForUser("before threshold");
	setThreshold(2, 255, "raw");
	run("Convert to Mask");
	return getImageID();
}


function AnalyzeMainFibers(ImageId, thicknessImageId)
{
	regionsIndexes = GenerateRegionsIndexesArray("RM", gRMcolor);
	if(regionsIndexes.length <= 0)
	{
		print("No 'RM' roi found - no main fiber analysis is deployed");
		return;
	}
	print("Skeletonizing fibers, that might take a few minutes...");
	//combine all "RM" regions to one
	roiManager("Select", regionsIndexes);
	roiManager("Combine");
	roiManager("Add");
	n = roiManager("count");
	allRMroiIndex = n - 1;
	
	selectImage(ImageId);
	run("Skeletonize (2D/3D)");
	//run("Skeleton Analyser", "prune_junctions min_length="+iMinMainFiberLength+" show_node_map show_table");
	run("Skeleton Analyser", "  min_length="+iMinSkeletonLength/gScale+" show_node_map show_table");
	// Skeleton Analyser generates an RGB image where red is the fiber, the green is the interscetion of fibers and blue the endpoints of separate fibers

	//first turn it to RGB stuck: channel 1: red, 2: green, 3: blue
	//waitForUser("check rgb stack");
	run("RGB Stack");
	run("Stack to Images");
	// OR the blue channel to the red to add the end-points of each isolated fiber
	imageCalculator("Or", "Red","Blue");
	// Dilate the green chnnel and invert it and AND it with the red channel to diconnect fibers (without Dilate fibers may remain connected)
	selectWindow("Green");
	run("Dilate", "slice");
//	run("Dilate", "slice"); // do it twice to shorten connecting fibers for better thickness calculation
	
	run("Invert");
	imageCalculator("And", "Red","Green");
	//turn the red image to rois 

	run("Analyze Particles...", "size="+iMinSkeletonLength/gScale+"-Infinity add"); 	
	//for each added roi, check if it is "main" or "connecting" and calculate the evargae thickness speratly of the two types


	roiManager("Select", allRMroiIndex);
	roiManager("rename", "RMAll");


	col = newArray(gMainFiberColor,gConnectingFiberColor);
	prefix = newArray("M_","C_");
	n = roiManager("count");
	for(i = n-1; i>allRMroiIndex;i--)
	{
		//for each added roi, check if it is "main" or "connecting" and calculate the evargae thickness speratly of the two types
		roiManager("select", i);
		Roi.getCoordinates(xpoints, ypoints);
		if(ArrayMax(xpoints) - ArrayMin(xpoints) > ArrayMax(ypoints) - ArrayMin(ypoints))
		{
			iS = ArrayMinIndex(xpoints); 
			iE = ArrayMaxIndex(xpoints);					
		}
		else {
			iS = ArrayMinIndex(ypoints); 
			iE = ArrayMaxIndex(ypoints);					
		}
		roiManager("select", allRMroiIndex);
		if(Roi.contains((xpoints[iS]+xpoints[iE])/2,(ypoints[iS]+ypoints[iE])/2))
		{
			fiberTypeInd = 0;

			//s="";
			//for(k=0;k<xpoints.length;k++)
			//	s += ",("+xpoints[k]+","+ypoints[k]+")";
			orientation = GetFiberOrientation(xpoints[iS], ypoints[iS], xpoints[iE], ypoints[iE]);
			if(matches(orientation, "Connecting fiber"))
				fiberTypeInd = 1;
			roiManager("select", i);
			Roi.setFillColor(col[fiberTypeInd]);
			Roi.setStrokeColor(col[fiberTypeInd]);
			//Roi.setName(prefix[fiberTypeInd]+"_"+(i-n+1));
			roiManager("rename", prefix[fiberTypeInd]+Roi.getName);
		}
		else {
			roiManager("select", i);
			roiManager("delete");	
		}
	}
	selectImage(gImageId);
	roiManager("Show None");
	roiManager("Show All without labels");
	waitForUser("Now its time to double check automatic fiber calssification\n"+
				"Change fibers clasification, delete them all together or add new ones,\n"+
				"by setting the Roi prefix, " + prefix[0] +" for main fiber and " + prefix[1] + " for connecting fiber\n"+
				"Seleck OK button when done.");				
	selectImage(thicknessImageId);
	//generate roi results table
	//Table.reset("Results");
	//roiManager("deselect");
	//roiManager("measure");
	
	rawDataTable = "Raw Data";
	Table.create(rawDataTable+0);
	Table.create(rawDataTable+1);
	numPixels = newArray(0,0); numSegments = newArray(0,0); sumThickness = newArray(2); minThickness = newArray(2); maxThickness = newArray(2);
	n = roiManager("count");
	setBatchMode(true);
	for(i = allRMroiIndex+1; i<n;i++)
	{	
		fiberTypeInd = 0;
		roiManager("select", i);
		if(!startsWith(Roi.getName,prefix[fiberTypeInd]))
			fiberTypeInd = 1;
		Roi.setFillColor(col[fiberTypeInd]);
		Roi.setStrokeColor(col[fiberTypeInd]);		
		
		//Roi.getCoordinates(xpoints, ypoints);
		Roi.getContainedPoints(xpoints, ypoints);
		if(iMainGeneralOrientation <= 135 && iMainGeneralOrientation >= 45)
			Array.sort(xpoints, ypoints);
		else
			Array.sort(ypoints, xpoints);

		firstPixelIndex = 0; lastPixelIndex = xpoints.length-1;
		if(fiberTypeInd == 1 && iTruncateConnectingFiber)
		{
			//in case of connecting fiber ignore segment that is still inside the main segment
			selectWindow("Blue");
			firstPixelState = getPixel(xpoints[0], ypoints[0]);
			lastPixelState = getPixel(xpoints[lastPixelIndex], ypoints[lastPixelIndex]);
			selectImage(thicknessImageId);
			if(firstPixelState <= 0) // not a loose end
			{
				w = getPixel(xpoints[0], ypoints[0]);
				firstPixelIndex = Math.ceil(w/2);
			}
			if(lastPixelState <= 0) // not a loose end
			{
				w = getPixel(xpoints[lastPixelIndex], ypoints[lastPixelIndex]);
				lastPixelIndex = lastPixelIndex - Math.ceil(w/2);
			}
			//if remaining segment is shorter than minimal segment, ignore it
			if(	lastPixelIndex - firstPixelIndex <  iMinSkeletonLength/gScale)
			{
				continue;
			}
		}
		for(j=firstPixelIndex; j<=lastPixelIndex;j++)
		{
			localThickness = getPixel(xpoints[j], ypoints[j]);
			if(isNaN(localThickness) || localThickness == 0)
			{
//				waitForUser("localThickness: " + localThickness +"xpoints[j]: "+xpoints[j]+", ypoints[j]: "+ypoints[j]);
				continue;
			}	
			if(numPixels[fiberTypeInd] <= 0)
			{
				numPixels[fiberTypeInd] = 0; sumThickness[fiberTypeInd] = localThickness; 
				minThickness[fiberTypeInd] = localThickness; maxThickness[fiberTypeInd] = localThickness;
			}
			else 
			{			
				sumThickness[fiberTypeInd] += localThickness;
				if(localThickness < minThickness[fiberTypeInd])
					minThickness[fiberTypeInd] = localThickness;
				if(localThickness > maxThickness[fiberTypeInd])
					maxThickness[fiberTypeInd] = localThickness;
			}
			Table.set("X", numPixels[fiberTypeInd], xpoints[j],rawDataTable+fiberTypeInd);
			Table.set("Y", numPixels[fiberTypeInd], ypoints[j],rawDataTable+fiberTypeInd);
			Table.set("Thickness", numPixels[fiberTypeInd], gScale * localThickness,rawDataTable+fiberTypeInd);
			Table.set("Roi label", numPixels[fiberTypeInd], Roi.getName, rawDataTable+fiberTypeInd);
			numPixels[fiberTypeInd]++;
		}
		numSegments[fiberTypeInd]++;
		
	}
	setBatchMode(false);
	Table.save(gImagesResultsSubFolder+"/Main thickness.csv",rawDataTable+0);
	Table.save(gImagesResultsSubFolder+"/Connecting thickness.csv",rawDataTable+1);
	tName = "Fiber Analysis";
	Table.create(tName);
	Table.set("Num Main fiber pixels", 0, numPixels[0], tName);
	Table.set("Mean Main fiber thickness", 0, gScale * sumThickness[0]/numPixels[0], tName);
	Table.set("Min Main fiber thickness", 0, gScale * minThickness[0], tName);
	Table.set("Max Main fiber thickness", 0, gScale * maxThickness[0], tName);
	Table.set("Main No. segments", 0, numSegments[0], tName);
	Table.set("Num Connecting fiber pixels", 0, numPixels[1], tName);
	Table.set("Mean Connecting fiber thickness", 0, gScale * sumThickness[1]/numPixels[1], tName);
	Table.set("Min Connecting fiber thickness", 0, gScale * minThickness[1], tName);
	Table.set("Max Connecting fiber thickness", 0, gScale * maxThickness[1], tName);
	Table.set("Connecting No. segments", 0, numSegments[1], tName);
	fullPath = gImagesResultsSubFolder+"/"+tName+".csv";
	Table.save(fullPath,tName);	
	print("End Skeletonizing fibers");
}
function ArrayMin(arr)
{
	min = arr[0];
	for(i = 1;i<arr.length;i++)
	{
		if(arr[i] < min)
			min = arr[i];
	}
	return min;
}
function ArrayMax(arr)
{
	max = arr[0];
	for(i = 1;i<arr.length;i++)
	{
		if(arr[i] > max)
			max = arr[i];
	}
	return max;
}
function ArrayMinIndex(arr)
{
	min = 0;
	for(i = 1;i<arr.length;i++)
	{
		if(arr[i] < arr[min])
			min = i;
	}
	return min;
}
function ArrayMaxIndex(arr)
{
	max = 0;
	for(i = 1;i<arr.length;i++)
	{
		if(arr[i] > arr[max])
			max = i;
	}
	return max;
}
function SelectChannel(imageId, channel)
{
	selectImage(imageId);
	Stack.setChannel(channel);
	//also setSlice(channel);
}
function GenerateThicknessTable(imageId)
{
	selectImage(imageId);
	run("Local Thickness (complete process)", "threshold=2");
	thicknessImageId = getImageID(); 
	run("Duplicate...", "title=For Distance calculations");

	
	Table.create(gCompositeTable);
	roiManager("deselect");
	run("Clear Results");
	roiManager("measure");
	rowIndex = 0;


	regionsIndexes = GenerateRegionsIndexesArray("RC", gRCcolor);
	n = roiManager("count");	
	for(i=0;i<n;i++)
	{
		roiManager("select", i);
		if(!startsWith(Roi.getName, "R")) // a connecting fiber region
		{
			Table.set("Roi index", rowIndex, i, gCompositeTable);
			Table.set("Roi label", rowIndex, Roi.getName, gCompositeTable);
			Roi.getCoordinates(xpoints, ypoints);
			Roi.setStrokeColor(gUserFiberColor);
			Roi.setFillColor(gUserFiberColor);
			li = xpoints.length-1;
			orientation = GetFiberOrientation(xpoints[0], ypoints[0], xpoints[li], ypoints[li]);	
			Table.set("Fiber type", rowIndex, orientation,gCompositeTable);
			if(matches(orientation, "Connecting fiber"))
			{
				regionIndex = SelectContainingRegion((xpoints[0]+xpoints[li])/2,(ypoints[0]+ypoints[li])/2, regionsIndexes);
				if(regionIndex == -1)
				{
					Table.set("Fiber type", rowIndex, "Unregional Connecting fiber",gCompositeTable);
				}
				else {
					regionName = Roi.getName;
					Table.set("Region", rowIndex, regionName,gCompositeTable);
					Table.set("Region index", rowIndex, regionIndex, gCompositeTable);
				}
			}
			Table.set("Min thickness", rowIndex, gScale * Table.get("Min",i,"Results"),gCompositeTable);
			Table.set("Max thickness", rowIndex, gScale * Table.get("Max",i,"Results"),gCompositeTable);
			Table.set("Mean thickness", rowIndex, gScale * Table.get("Mean",i,"Results"),gCompositeTable);

			Table.set("Mid. x", rowIndex, (xpoints[0]+xpoints[li])/2,gCompositeTable);
			Table.set("Mid. y", rowIndex, (ypoints[0]+ypoints[li])/2,gCompositeTable);
			rowIndex++;		
		}		
	}
	SetClosestFiber(rowIndex);
	setBatchMode(true);
	CalcDistanses(imageId,rowIndex);
	setBatchMode(false);
	fullPath = gImagesResultsSubFolder+"/"+gCompositeTable+".csv";
	Table.save(fullPath,gCompositeTable);	
	return thicknessImageId;
}
function CalcDistanses(imageId,numRows)
{
	for(i = 0;i<numRows;i++)
	{
		selectImage(imageId);
		closestRoiinedx = Table.get("Closest Roi (fiber) index", i, gCompositeTable);		
		if(closestRoiinedx >= 0)
		{
			roiIndex = Table.get("Roi index", i, gCompositeTable);
			//turn the line roi to a polygon
			GeneratePolygonSelection(roiIndex);
			//prepare the image for distance transform by making the polygon inside white and the outside black
			run("Create Mask");
			//run distance transform
			run("Distance Transform 3D");
			close("Mask");
			// now measure the values of the closest roi fiber
			CloseTable("Results");
			roiManager("select", closestRoiinedx);
			roiManager("measure");
			minDistance = Table.get("Min",0,"Results");
			maxDistance = Table.get("Max",0,"Results");
			meanDistance = Table.get("Mean",0,"Results");
			Table.set("closest fiber label", i, Roi.getName,gCompositeTable);
			Table.set("Min Distance to closest fiber", i, gScale * minDistance,gCompositeTable);
			Table.set("Max Distance to closest fiber", i, gScale * maxDistance,gCompositeTable);
			Table.set("Mean Distance to closest fiber", i, gScale * meanDistance,gCompositeTable);		
		}
	}
}

function GeneratePolygonSelection(roiIndex)
{
	roiManager("select", roiIndex);
	// to create the distance transform we replace the line with a polygon
	Roi.getCoordinates(xpoints, ypoints);
	px = newArray(xpoints.length+2);
	py = newArray(ypoints.length+2);
	for(j=0;j<xpoints.length;j++)
	{
		px[j] = xpoints[j];
		py[j] = ypoints[j];
	}
	px[xpoints.length] = px[xpoints.length-1];
	py[ypoints.length] = py[xpoints.length-1]+2;
	px[xpoints.length+1] = px[0];
	py[ypoints.length+1] = py[0]+2;
	makeSelection("Polygon", px, py);
}
function SetClosestFiber(numRows)
{
	closestIndexes = newArray(numRows);
	for(i = 0;i<numRows;i++)
	{
		closestRoiIndex = -1;
		orientation = Table.getString("Fiber type", i,gCompositeTable);
		//waitForUser(orientation);
		if(matches(orientation, "Connecting fiber"))
		{
			//print(i+ ": horizontal fiber")
			closestY = -1;
			regionIndex = Table.get("Region index", i, gCompositeTable);
			midY = Table.get("Mid. y", i, gCompositeTable);
			for(j = 0;j<numRows;j++)
			{
				//print("\tChecking"+j); 					
				if(i == j)
					continue;
				jRegionIndex = Table.get("Region index", j, gCompositeTable);
				if(jRegionIndex != regionIndex)
					continue;
				//print("\t\tSame region"); 					
				jOrientation = Table.getString("Fiber type", j,gCompositeTable);
				if(jOrientation != "Connecting fiber")
					continue;	
				//print("\t\tHorizontal"); 					
				jMidY = Table.get("Mid. y", j, gCompositeTable);
				if(jMidY > midY)
					continue;
				if(jMidY > closestY)
				{
					closestY = jMidY;
					closestRoiIndex = Table.get("Roi index", j, gCompositeTable);
				}				
			}			
		}
		Table.set("Closest Roi (fiber) index", i, closestRoiIndex, gCompositeTable);
	}
	
}

function GetFiberOrientation(x0, y0, x1, y1)
{

	rOrientation = Math.atan((y1-y0)/(x1-x0));

	dOrientation = 	180 - rOrientation * 180/PI; //because Y is reversed we need the complementry angle

	if(dOrientation >= 180)
	{
		dOrientation -= 180;
	}
	if(dOrientation < 0)
		dOrientation += 180;
	
//	waitForUser("dOrientation: "+ dOrientation+", iMainGeneralOrientation: "+iMainGeneralOrientation+", iMainAngleVariance: "+iMainAngleVariance);
	
	
	if(dOrientation < iMainGeneralOrientation - iMainAngleVariance ||  dOrientation > iMainGeneralOrientation + iMainAngleVariance){
		return "Connecting fiber"; 
	}
	else
	{
		return "Main fiber";
	}

}
function SelectContainingRegion(x,y,regionsIndexes)
{
	for(i=0;i<regionsIndexes.length;i++)
	{
		roiManager("select", regionsIndexes[i]);
		if(Roi.contains(x, y))
			return regionsIndexes[i];
	}
	print("Error: Could not find region containing fiber with centorid: ("+x+","+y+"). Will be ignored");
	return -1;
}

function GenerateRegionsIndexesArray(startWith, roiColor)
{
	n = roiManager("count");
	numRegions = 0;
	regionIndexes = newArray();
	for(i=0;i<n;i++)
	{
		roiManager("select", i);
		if(startsWith(Roi.getName, startWith))
		{
			Roi.setStrokeColor(roiColor);			
			regionIndexes[numRegions] = i;
			numRegions++;
		}
	}
	return regionIndexes;
}
function initVariables()
{
	gFirstClusterRoi = true;
}

function GetCellsRois()
{
	gManualRoi = false;
	manualRoiPath = gImagesResultsSubFolder+"/"+gCellsRois+"_Manual.zip";
	if(File.exists(manualRoiPath))
	{
		print("Warning: Using user generated cells rois");
		gManualRoi = true;
		roiManager("open", manualRoiPath);
		return;
	}

	gCellsLabelsImageId = RunCellposeModel(gMitoZimageId, gMitoCellposeModel);
	gNumCells = GenerateROIsFromLabelImage(gCellsLabelsImageId,"Cell",0);
	if(gNumCells <= 0)
	{
		title = getTitle();
		print("WARNING!!!: Cellpose did not identify any cell/object in " + title);
	}
	StoreROIs(gImagesResultsSubFolder,gCellsRois);	
}


function GetLDsRois()
{
	gLDsLabelsImageId = RunCellposeModel(gLDZimageId, gLDCellposeModel);
	gNumLDs = GenerateROIsFromLabelImage(gLDsLabelsImageId,"",0);
	if(gNumLDs <= 0)
	{
		print("WARNING!!!: Cellpose did not identify any LD in " + getTitle());
	}
	StoreROIs(gImagesResultsSubFolder,gLDRois);	
}



function SetCompositeTables(colName,rowId,colValue)
{
	Table.set(colName,rowId,colValue,gCompositeTable);
	if(!matches(iProcessMode, "singleFile"))
		Table.set(colName,gAllCompositeResults+rowId,colValue,gAllCompositeTable);
}


function ClearRoiManager()
{
	roiManager("reset");
	/*if(roiManager("count") <= 0)
		return;
	roiManager("deselect");
	roiManager("delete");*/
}



function ScaleImage(imageId, scaleFactor)
{
	s = "x="+scaleFactor
	+" y="+scaleFactor
	//+" width="+width*scaleFactor
	//+" height="+height*scaleFactor
	+" interpolation=None create";
	run("Scale...",s);
	return getImageID();
}

function SaveROIs(fullPath)
{
	if(roiManager("count") <= 0)
		return false;
	roiManager("deselect");
	roiManager("save", fullPath);	
	return true;
}

function UsePrevRun(title,usePrevRun,restoreRois)
{
	if(!usePrevRun)
		return false;

	savePath = gImagesResultsSubFolder + "/"+gSaveRunDir+"/";
	labeledImageFullPath = savePath + title +".tif";
	labeledImageRoisFullPath = savePath + title +"_RoiSet.zip";

	if(!File.exists(labeledImageFullPath))
		return false;
	
	if(restoreRois && !File.exists(labeledImageRoisFullPath))
		return false;
		
	open(labeledImageFullPath);
	rename(title);
	id = getImageID();
	if(restoreRois)
		openROIs(labeledImageRoisFullPath,true);
	selectImage(id);
	//print("Using stored "+title+" labeled image");
	return true;;
}


function StoreRun(title,storeROIs)
{
	//waitForUser("store title: "+title);
	savePath = gImagesResultsSubFolder + "/"+gSaveRunDir+"/";
	//waitForUser("store gImagesResultsSubFolder: "+gImagesResultsSubFolder);
	//waitForUser("store savePath: "+savePath);
	
	labeledImageFullPath = savePath + title +".tif";
	
	selectWindow(title);
	saveAs("Tiff", labeledImageFullPath);
	rename(title);
	if(storeROIs)
	{
		labeledImageRoisFullPath = savePath + title +"_RoiSet.zip";
		SaveROIs(labeledImageRoisFullPath);
	}
}

function RunStarDistModel(imageId)
{
	labelImageId = -1;


//	labeledImageFullPath = gImagesResultsSubFolder + "/" + StarDistWindowTitle +".tif";
//	labeledImageRoisFullPath = gImagesResultsSubFolder + "/" + StarDistWindowTitle +"_RoiSet.zip";

	if(UsePrevRun(gStarDistWindowTitle,iUseStarDistPrevRun,true))
	{
		print("Using StarDist stored labeled image");
		labelImageId = getImageID();
	}
	else 
	{
		starDistModel = "'Versatile (fluorescent nuclei)'";
		nmsThresh = 0.4;
		
		print("Progress Report: StarDist started. That might take a few minutes");	
		selectImage(imageId);
		title = getTitle();
		run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], args=["
		+"'input':'"+title+"'"
		+", 'modelChoice':"+starDistModel
		+", 'normalizeInput':'true', 'percentileBottom':'1.0', 'percentileTop':'99.8'"
		+", 'probThresh':'"+iSDprobThreshold+"'"
		+", 'nmsThresh':'"+nmsThresh+"'"
		+", 'outputType':'Both', 'nTiles':'4', 'excludeBoundary':'2', 'roiPosition':'Automatic', 'verbose':'false', 'showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]");		

		labelImageId = getImageID();
		StoreRun(gStarDistWindowTitle,true);
		print("Progress Report: StarDist ended.");	
		if(roiManager("count") <= 0)
		{
			print("WARNING!!!: Stardist did not identify any cell/object in " + title);
		}
		print("num lds: "+roiManager("count"));
	}
	return labelImageId;
}
function RunIlastikModel(imageId)
{
	selectImage(imageId);
	title = getTitle();
	found = false;
	IlastikSegmentationOutFile = title+gIlastikSegmentationExtention;
	IlastikOutFilePath = gImagesResultsSubFolder+"/"+gSaveRunDir+"/";
	if (iUseIlastikPrevRun)
	{
		if (File.exists(IlastikOutFilePath+IlastikSegmentationOutFile))
		{
			print("Reading existing Ilastik AutoContext output ...");
			//run("Import HDF5", "select=[A:\yairbe\Ilastic Training\Cre off HD R.h5] datasetname=/data axisorder=tzyxc");
			//run("Import HDF5", "select=["+resFolderSub+IlastikSegmentationOutFile+"] datasetname=/exported_data axisorder=yxc");
			run("Import HDF5", "select=["+IlastikOutFilePath+IlastikSegmentationOutFile+"] datasetname=/data axisorder=tzyxc");

			//rename("Segmentation");
			rename(IlastikSegmentationOutFile);
						
			found = true;
		}
	}
	if (!found)
	{
		setBatchMode(false);
		print("Progress Report: Ilastik AutoContext classifier started. That might take a few minutes");	
		//run("Run Autocontext Prediction", "projectfilename=[A:\\yairbe\\Ilastic Training\\CreOFF-Axon-Classifier_v133post3.ilp] 
		//    inputimage=[A:\\yairbe\\Ilastic Training\\Cre off HD R.h5\\data] autocontextpredictiontype=Segmentation");

		run("Run Autocontext Prediction", "projectfilename=["+iIlastikModelPath+"] inputimage=["+title+"] autocontextpredictiontype=Segmentation");
		//rename("Segmentation");
		rename(IlastikSegmentationOutFile);

		// save Ilastik Output File
		selectWindow(IlastikSegmentationOutFile);
		print("Saving Ilastik autocontext classifier output...");
		//run("Export HDF5", "select=["+resFolder+IlastikProbOutFile1+"] exportpath=["+resFolder+IlastikProbOutFile1+"] datasetname=data compressionlevel=0 input=["+IlastikProbOutFile1+"]");	
		run("Export HDF5", "select=["+IlastikOutFilePath+IlastikSegmentationOutFile+"] exportpath=["+IlastikOutFilePath+IlastikSegmentationOutFile+"] datasetname=data compressionlevel=0 input=["+IlastikSegmentationOutFile+"]");	
		print("Progress Report: Ilastik ended.");	
		setBatchMode(gBatchModeFlag);
	}	
	rename(IlastikSegmentationOutFile);
	//setVoxelSize(width, height, depth, unit); multiplying area size instead
	return getImageID();
}

function RunCellposeModel(imageId, cellposeModel)
{

	if(cellposeModel == gLDCellposeModel)
	{
		cellposeModelPath = iLDCellposeModelPath; cellposeExtRunDir = iLDCellposeExtRunDir; useCellposePrevRun = iLDUseCellposePrevRun; cellposeCellDiameter = iLDCellposeCellDiameter; cellposeProbThreshold = iLDCellposeProbThreshold; cellposeFlowThreshold = iLDCellposeFlowThreshold;
	}
	else if(cellposeModel == gMitoCellposeModel)
	{
		cellposeModelPath = iMitoCellposeModelPath; cellposeExtRunDir = iMitoCellposeExtRunDir; useCellposePrevRun = iMitoUseCellposePrevRun; cellposeCellDiameter = iMitoCellposeCellDiameter; cellposeProbThreshold = iMitoCellposeProbThreshold; cellposeFlowThreshold = iMitoCellposeFlowThreshold;
	}
	else
	{
		print("Error: Unidentified Cellpose model: "+cellposeModel);
		return -1;
	}
	selectImage(imageId);
	title = getTitle();
	CellposeWindowTitle = "label image - ";
	
	//if cellpose was used externaly to generate the label map of the cells
	//it will be stored in the input directory under Cellpose/Segmentation
	if(UseExternalRun("Cellpose", CellposeWindowTitle, cellposeModel))
	{
		print("Using "+cellposeModel+ "Cellpose external run generated labeled image");
		labelImageId = getImageID();
	}
	else if(UsePrevRun(CellposeWindowTitle,useCellposePrevRun,false))
	{
		print("Using "+cellposeModel+ " Cellpose stored labeled image");
		labelImageId = getImageID();
	}
	else 
	{
		print("Progress Report: "+cellposeModel+ " started. That might take a few minutes");	

		run("Cellpose Advanced (custom model)", "diameter="+cellposeCellDiameter
			+" cellproba_threshold="+cellposeProbThreshold
			+" flow_threshold="+cellposeFlowThreshold
			+" anisotropy=1.0 diam_threshold=12.0"
			+" model_path="+File.getDirectory(cellposeModel)
			+" model="+cellposeModelPath
			+" nuclei_channel=0 cyto_channel=0 dimensionmode=2D stitch_threshold=-1.0 omni=false cluster=false additionnal_flags=");
		labelImageId = getImageID();
		rename(CellposeWindowTitle);
		//waitForUser("title:"+title);
		StoreRun(CellposeWindowTitle,false);
		print("Progress Report: "+cellposeModel+ " ended.");	
	}	
	return labelImageId;
}

function UseExternalRun(app, title, cellposeModel)
{
	if(app == "Cellpose")
	{
		subDir = gCellposeExtRunSubdir;
		fileSuffix = gCellposeExtRunFileSuffix;
	}
	else{
		print("Warning: Wrong app: " + app + ". Ignored");
		return false;
	}
	labeledImageFullPath = File.getDirectory(gFileFullPath)+cellposeModel+subDir+gFileNameNoExt+fileSuffix;

	if(File.exists(labeledImageFullPath))
	{
		open(labeledImageFullPath);
		rename(title);
		id = getImageID();
		selectImage(id);	
		return true;	
	}
	return false;
}

function GenerateROIsFromLabelImage(labelImageId,type,filterMinAreaSize)
{
	nBefore = roiManager("count");
	selectImage(labelImageId);
	run("Label image to ROIs");
	nAfter = roiManager("count");
	if(filterMinAreaSize > 0)
	{
		run("Clear Results");
		roiManager("measure");
		for(i=nAfter-1;i>=nBefore;i--)
		{
			area = Table.get("Area",i, "Results");
			if(area < filterMinAreaSize)
			{
				roiManager("select", i);
				roiManager("delete");
				nAfter--;
			}
		}
	}
	if(type != "")
	{
		for(i=nBefore;i<nAfter;i++)
		{
			roiManager("select", i);
			roiManager("rename", type+"_"+(i-nBefore+1));
		}
	}
	return nAfter - nBefore;
}
function DupChannelAndZProject(imageId, channel)
{
	selectImage(imageId);
	//1. prepare image for Cellpose: duplicate the 3rd channel and z-project it
	run("Duplicate...", "duplicate channels="+channel);
	run("Z Project...", "projection=[Max Intensity]");
	return getImageID();	
}

function RemoveArtifacts(imgId,spotThreshold,channel)
{
	roiManager("Deselect");
	run("Clear Results");
	run("Select None");
	
	selectImage(imgId);	
	Stack.setChannel(channel);
	run("Set Measurements...", "mean min display redirect=None decimal=3");
	run("Measure");
	meanIntensity = Table.get("Mean",0, "Results");
	run("Macro...", "code=if(v>" + spotThreshold + ")v=" + meanIntensity); //Notice: no spaces allowed in macro
	run("Clear Results");
}
/*
function RemoveArtifacts(imgId,spotThreshold)
{
	selectImage(imgId);	
	title = getTitle();
	
	maskWindow = "tempMaskWindow";
	roiManager("Deselect");
	run("Clear Results");

	maskImgId = dupChannel(imgId, 1, maskWindow);
	selectImage(maskImgId);	
	run("Set Measurements...", "mean min display redirect=None decimal=3");
	run("Measure");
	meanIntensity = Table.get("Mean",0, "Results");
	setThreshold(0,spotThreshold);
	setOption("BlackBackground", false);
	run("Convert to Mask");	
	run("Create Selection");
	run("Select None");
	run("Divide...", "value=255");

	run("Image Calculator...", "image1="+title+" operation=Multiply image2="+ maskWindow);	
	selectImage(maskImgId);
	run("HiLo");
	run("Macro...", "code=v=1-v");
	run("16-bit");
	run("Multiply...", meanIntensity);
	imageCalculator("Add", title, maskWindow);

	
	
	selectImage(maskImgId);
	close();
	run("Clear Results");
	waitForUser("mean: "+meanIntensity);
}
*/
function StoreROIs(path,fileName)
{
	SaveROIs(path +"/" + fileName+".zip");
}
function compositeAreas(imageId)
{
	selectImage(imageId);

	// set the B/C of CD35 and CD25 channels
	Stack.setChannel(CD35_CHANNEL);
	setMinAndMax(0, iCD35MaxPixelDisplayValue);
	Stack.setChannel(CD23_CHANNEL);
	setMinAndMax(0, iCD23MaxPixelDisplayValue);
	
	//make a composite image of the two channels
	channels = newArray(4);
	channels[CD35_CHANNEL-1] = 1;
	channels[CD23_CHANNEL-1] = 1;	
	Stack.setDisplayMode("composite");
	Stack.setActiveChannels(String.join(channels,""));

	
	run("Select None");
	roiManager("Show None");
	
	// show CD23, CD35 and GC on the composite image and flatten them on it
	rois = newArray(SelectRoiByName("GC"),SelectRoiByName("CD35"),SelectRoiByName("CD23"));
	colors = newArray(iGCColor,iCD35Color,iCD23Color);

	prevImgId = 0;
	for(i=0;i<rois.length;i++)
	{
		roiManager("Select", rois[i]);
		RoiManager.setGroup(0);
		RoiManager.setPosition(0);	
		roiManager("Set Color", colors[i]);
		roiManager("Set Line Width", iROILineWidth);
		prevImgId = imageId;
		run("Flatten");	
		imageId = getImageID();
		if(i > 0)
		{
			selectImage(prevImgId);
			close();
			selectImage(imageId);						
		}
	}
	saveAs("Jpeg", gImagesResultsSubFolder+"/"+"CD35nCD23."+"jpeg");
	return imageId;
}


function GenerateLineHistogram(imageId,title, normalizeY, convertToMicrons)
{

	selectImage(imageId);
	SelectRoiByName("Line");
	run("Plot Profile");	
	saveAs("Jpeg", gImagesResultsSubFolder+"/"+title+"_LineHistogram.jpg");
	//now save as csv file as well
  	Plot.getValues(x, y);
  	if(convertToMicrons)
  	{
		for(i=0;i<x.length;i++)
			x[i] *= pixelWidth;
  	}
  	run("Close") ;
  	tableName = title+"_Histogram_values";
  	Array.show(tableName, x, y);
  	//Table.save(gResultsSubFolder+"/"+tableName+".csv", tableName);
  	Table.save(gImagesResultsSubFolder + "/"+tableName+".csv", tableName);
  	run("Close") ;
  	//save normalized table as well
  	normalizeXArray(x,iLineMargin);
  	if(normalizeY)
 		normealizeYArray(y,title);
   	//Table.save(gResultsSubFolder+"/"+tableName+".csv", tableName);
  	tableName = title+"_Histogram_values_normalized";
  	Array.show(tableName, x, y);
  	Table.save(gImagesResultsSubFolder + "/"+tableName+".csv", tableName);
	run("Close") ;
}


function CountWhitePixelsInROI(BitmapImgId,RoiId)
{
	selectImage(BitmapImgId);
	run("Set Measurements...", "area limit display redirect=None decimal=3");
	roiManager("Select", RoiId);
	setAutoThreshold("Default dark no-reset");
	setThreshold(1, 255);
	run("Measure");
	run("Clear Results");
	roiManager("Measure");
	count = Table.get("Area",0, "Results");
	return count;
}


function normealizeYArray(y,title)
{
	max = y[0];
	for(i=1;i<y.length;i++)
	{
		if(y[i] > max)
			max = y[i];
	}
	print("Normalizing " + title + ": Dividing all values by ("+max+")/100");
	v = max/100;
	for(i=0;i<y.length;i++)
		y[i] /= v;
}
//input:
//1. x: array of increasing numbers
//2. margin: a number between 0 and 100 specifing the precentage of the numbers 
//        of the array at the begining and end that belong to the margins
//returns: the array x where the values are normalized betwin -margin and +margin
function normalizeXArray(x,margin)
{
	shift = x[0];
	Xmax = x[x.length-1];
	for(i=0;i<x.length;i++)
	{
		x[i] = (x[i]-shift)	* (2*margin + 100)/Xmax - margin;	
	}
}

function RunThreshold(from, to)
{
	//run("Threshold...");
	setThreshold(from, to, "raw");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	return getImageID();
}

function drawAutoLine(hemiId, widthP, marginP)
{
	//Left or Right
	if(hemiId%2 == 0)
	{
		gLineWidth = 2*hVertical*widthP/pixelHeight;
		margin = 2*hHorizontal*marginP;
		if(hemiId == 2) // line right to left
			switch *= -1;
		//find start and end points
		fromX = (cX - switch*sinAngle*(hHorizontal+margin))/pixelWidth;
		fromY = (cY - switch*cosAngle*(hHorizontal+margin))/pixelHeight;
		toX = (cX + switch*sinAngle*(hHorizontal+margin))/pixelWidth;
		toY = (cY + switch*cosAngle*(hHorizontal+margin))/pixelHeight;
	}
	else // Top or bottom
	{
		gLineWidth = 2*hHorizontal*widthP/pixelWidth;
		margin = 2*hVertical*marginP;
		//updateDisplay();		
		if(hemiId == 3) // line Bottom to Top
			switch *= -1;
		//find start and end points
		fromX = (cX - switch*cosAngle*(hVertical+margin))/pixelWidth;
		fromY = (cY + switch*sinAngle*(hVertical+margin))/pixelHeight;
		toX = (cX + switch*cosAngle*(hVertical+margin))/pixelWidth;
		toY = (cY - switch*sinAngle*(hVertical+margin))/pixelHeight;
	}

	makeLine(fromX, fromY, toX, toY,gLineWidth);
	updateDisplay();
	roiManager("Add");
	selectLastROI();
	roiManager("Rename", "Line");

	
}
function drawUserLine(imageId, marginP)
{
	selectImage(imageId);
	roiManager("select", SelectRoiByName("Line"));
	waitForUser("If you want to change the Line:\n"+
			"Draw a new line from the side of the GC where CD23 is located to the other side using the 'Straight Line' icon.\n"+
			"Notice: Margins and width will be generated automaticaly.\n"+
			"Then, add the new line to the ROI manger (By pressing 't')\n"+
			"and rename it there to 'NewLine'.\n"+
			"Once done (even if you choose to do nothing), press the OK button");

	run("Set Measurements...", "centroid perimeter fit integrated display redirect=None decimal=3");
	run("Clear Results");
	if(SelectRoiByName("NewLine") != -1)
	{
		switch = 1;

		roiManager("measure");
		angle = Table.get("Angle",0, "Results");
		cX = Table.get("X",0, "Results");
		cY = Table.get("Y",0, "Results");
		hPerimeter = Table.get("Perim.",0, "Results")/2;
		
		margin = 2*hPerimeter*marginP;
		rAngle = toRadians(angle);
		cosAngle = Math.cos(rAngle);
		sinAngle = Math.sin(rAngle);
		
		fromX = (cX - switch*cosAngle*(hPerimeter+margin))/pixelWidth;
		fromY = (cY + switch*sinAngle*(hPerimeter+margin))/pixelHeight;
		toX = (cX + switch*cosAngle*(hPerimeter+margin))/pixelWidth;
		toY = (cY - switch*sinAngle*(hPerimeter+margin))/pixelHeight;
	
		makeLine(fromX, fromY, toX, toY, gLineWidth);
		roiManager("Add");
		SelectRoiByName("Line");
		roiManager("Rename", "AutoLine");
		selectLastROI();
		roiManager("Rename", "Line");
	}
}
function GenerateDarkRoi()
{
	SelectRoiByName("GC");
	run("Create Mask");
	rename("CD Mask");
	mask1 = getImageID();
	SelectRoiByName("CD35");
	run("Create Mask");
	rename("CD35 Mask");
	mask2 = getImageID();
	imageCalculator("subtract", mask1, mask2);
	run("Create Selection");	
	roiManager("Add");
	selectLastROI();
	roiManager("Rename", "Dark");
}
function drawLine(hemiId, widthP, marginP)
{
	//Left or Right
	if(hemiId%2 == 0)
	{
		lineWidth = 2*hVertical*widthP/pixelHeight;
		margin = 2*hHorizontal*marginP;
		if(hemiId == 2) // line right to left
			switch *= -1;
		//find start and end points
		fromX = (cX - switch*sinAngle*(hHorizontal+margin))/pixelWidth;
		fromY = (cY - switch*cosAngle*(hHorizontal+margin))/pixelHeight;
		toX = (cX + switch*sinAngle*(hHorizontal+margin))/pixelWidth;
		toY = (cY + switch*cosAngle*(hHorizontal+margin))/pixelHeight;
	}
	else // Top or bottom
	{
		lineWidth = 2*hHorizontal*widthP/pixelWidth;
		margin = 2*hVertical*marginP;
		//updateDisplay();		
		if(hemiId == 3) // line Bottom to Top
			switch *= -1;
		//find start and end points
		fromX = (cX - switch*cosAngle*(hVertical+margin))/pixelWidth;
		fromY = (cY + switch*sinAngle*(hVertical+margin))/pixelHeight;
		toX = (cX + switch*cosAngle*(hVertical+margin))/pixelWidth;
		toY = (cY - switch*sinAngle*(hVertical+margin))/pixelHeight;
	}

	makeLine(fromX, fromY, toX, toY,lineWidth);
	updateDisplay();
}
function FindGCOrientation()
{
	// intersect  CD35 ROI with each of the hemiSpheres to find orientation
	maxArea = 0;
	hemiID = -1;

	SelectRoiByName("CD35");
	run("Create Mask");
	rename("CD35 Mask");
	mask1 = getImageID();
	for(i=0;i<4;i++)
	{
		SelectRoiByName(gHemiNames[i]);
		run("Create Mask");	
		mask2 = getImageID();	
		rename(gHemiNames[i]+" Mask");
		imageCalculator("AND", mask2, mask1);
		run("Create Selection");	
		roiManager("Add");
		selectLastROI();
		roiManager("Rename", gHemiNames[i]+" Intersection");
		run("Clear Results");
		roiManager("Measure");
		roiManager("delete");
		hemiArea = Table.get("Area",0, "Results");
		if(hemiArea > maxArea)
		{
			maxArea = hemiArea;
			hemiID = i;
		}
		SelectRoiByName(gHemiNames[i]);
		roiManager("delete");
	}
//	print("hemiID = " + hemiID + ", area = " + maxArea);
	return hemiID;
}


function GetRoiArea(roiIndex)
{
	roiManager("Select", roiIndex);
	run("Clear Results");
	run("Measure");
	area = Table.get("Area",0, "Results");
	return area;	
}

function generateSmoothImage(imageId, smoothType, parm1, parm2, duplicateImage)
{
	selectImage(imageId);
	if(duplicateImage)
	{		
		smoothImageId = dupChannel(imageId, 1, getTitle()+"_Smoothed");
	}
	else 
		smoothImageId = imageId;
	if(smoothType == GAUSSIAN_BLUR)
	{
		run("Gaussian Blur...", "sigma="+parm1);
	}
	else 
	{
		print("FATAL ERROR: Unknown smoothing operation");
	}
	return smoothImageId;
}
function dupChannel(imageId,channel,newTitle)
{
	selectImage(imageId);
	run("Select None");
	roiManager("deselect");
	run("Duplicate...", "title=["+newTitle+"] duplicate channels="+channel);
	return getImageID();
}

function SelectRoiByName(roiName) { 
	nR = roiManager("Count"); 
	roiIdx = newArray(nR); 
	 
	for (i=0; i<nR; i++) { 
		roiManager("Select", i); 
		rName = Roi.getName(); 
		if (matches(rName, roiName) ) { 
			roiManager("Select", i);	
			return i;
		} 
	} 
	print("Fatal Error: Roi " + roiName + " not found");
	return -1; 
} 
function SelectRoiByPrefix(prefix) { 
	nR = roiManager("Count"); 
	roiIdx = newArray(nR); 
	 
	for (i=0; i<nR; i++) { 
		roiManager("Select", i); 
		rName = Roi.getName(); 
		if (startsWith(toUpperCase(rName), toUpperCase(prefix)) ) { 
			roiManager("Select", i);	
			return i;
		} 
	} 
	return -1; 
} 
function selectLastROI()
{
	n = roiManager("count");
	roiManager("Select", n-1);
}
// GenerateFittingElipse
// generates an ellipse fitting to the GC and its 4 hemisphers (left, up, right, bottom)
function GenerateFittingElipse()
{
	run("Set Measurements...", gROIMeasurment + " redirect=None decimal=3");
	imageXBorders = newArray(0,width,0,width);
	imageYBorders = newArray(0,0,height,height);
	// generate "Ellipse" roi and measure it 
	SelectRoiByName("GC");
	run("Fit Ellipse");
	roiManager("Add");
	selectLastROI();
	roiManager("Rename", "Ellipse");
	run("Clear Results");
	roiManager("Measure");
	
	// given the ellipse dimensions generae the 4 hemisperes
	hemiNames = newArray("Left","Top","Right","Bottom");
	switch = 1;
	cX = Table.get("X",0, "Results");
	cY = Table.get("Y",0, "Results");
	hVertical = Table.get("Major",0, "Results")/2;
	hHorizontal = Table.get("Minor",0, "Results")/2;
	angle = Table.get("Angle",0, "Results");
	if (angle <= 45 || angle > 135)
	{
		temp = hVertical;
		hVertical = hHorizontal;
		hHorizontal = temp;
		if(angle <= 45)
			switch = -1;
		angle = 270 + angle;
	}
	//waitForUser(angle);
	rAngle = toRadians(angle);
	cosAngle = Math.cos(rAngle);
	sinAngle = Math.sin(rAngle);
	// handle "standing" ellipses
	//if (angle > 45 && angle <= 135)
	//{
		//GenerateROIFromPoints(hemiNames[(0+nameShift)%4],newArray(cX - cosAngle*hVertical, cX - sinAngle*hHorizontal, cX + cosAngle*hVertical), newArray(cY + sinAngle*hVertical, cY - cosAngle*hHorizontal, cY - sinAngle*hVertical));
		//GenerateROIFromPoints(hemiNames[(1+nameShift)%4],newArray(cX - sinAngle*hHorizontal, cX + cosAngle*hVertical, cX + sinAngle*hHorizontal), newArray(cY - cosAngle*hHorizontal, cY - sinAngle*hVertical, cY + cosAngle*hHorizontal));
		//GenerateROIFromPoints(hemiNames[(2+nameShift)%4],newArray(cX - cosAngle*hVertical, cX + sinAngle*hHorizontal, cX + cosAngle*hVertical), newArray(cY + sinAngle*hVertical, cY + cosAngle*hHorizontal, cY - sinAngle*hVertical));
		//GenerateROIFromPoints(hemiNames[(3+nameShift)%4],newArray(cX - sinAngle*hHorizontal, cX - cosAngle*hVertical, cX + sinAngle*hHorizontal), newArray(cY - cosAngle*hHorizontal, cY + sinAngle*hVertical, cY + cosAngle*hHorizontal));
		
		GenerateROIFromPoints(hemiNames[0],newArray((cX - switch*cosAngle*hVertical)/pixelWidth, imageXBorders[2], imageXBorders[0], (cX + switch*cosAngle*hVertical)/pixelWidth), newArray((cY + switch*sinAngle*hVertical)/pixelHeight, imageYBorders[2], imageYBorders[0], (cY - switch*sinAngle*hVertical)/pixelHeight));
		GenerateROIFromPoints(hemiNames[1],newArray((cX - switch*sinAngle*hHorizontal)/pixelWidth, imageXBorders[0], imageXBorders[1],(cX + switch*sinAngle*hHorizontal)/pixelWidth), newArray((cY - switch*cosAngle*hHorizontal)/pixelHeight, imageYBorders[0], imageYBorders[1], (cY + switch*cosAngle*hHorizontal)/pixelHeight));
		GenerateROIFromPoints(hemiNames[2],newArray((cX + switch*cosAngle*hVertical)/pixelWidth, imageXBorders[1], imageXBorders[3], (cX - switch*cosAngle*hVertical)/pixelWidth), newArray((cY - switch*sinAngle*hVertical)/pixelHeight, imageYBorders[1], imageYBorders[3], (cY + switch*sinAngle*hVertical)/pixelHeight));
		GenerateROIFromPoints(hemiNames[3],newArray((cX - switch*sinAngle*hHorizontal)/pixelWidth, imageXBorders[2], imageXBorders[3], (cX + switch*sinAngle*hHorizontal)/pixelWidth), newArray((cY - switch*cosAngle*hHorizontal)/pixelHeight, imageYBorders[2], imageYBorders[3], (cY + switch*cosAngle*hHorizontal)/pixelHeight));
	//}
}
function GenerateROIFromPoints(name, xPoints, yPoints)
{
	makeSelection("polygon", xPoints, yPoints);	
	roiManager("Add");
	n = roiManager("count");
	roiManager("Select", n-1);
	roiManager("Rename", name);
}


function toRadians(angle)
{
	return angle*PI/180;
}


function AddGC_roi()
{
	roiPath = File.getDirectory(gFileFullPath)+gFileNameNoExt+gRoisSuffix;
	if(!openROIsFile(roiPath,true))
	{
		print("Fatal Error: could not find ROI file " + roiPath + ".roi");
		return false;
	}
	// rename ROI to GC
	selectLastROI();
	roiManager("Rename", "GC");
	return true;
}

/*function ProcessFile(directory) 

	axonCh1 = 2;
	axonCh2 = 3;
	if(!openFile(gFileFullPath))
		return false;	
	setBatchMode(gBatchModeFlag);	
	//run("Brightness/Contrast...");
	run("Enhance Contrast", "saturated=0.35");			
	originalWindow = getTitle();
	gFileNameNoExt = File.getNameWithoutExtension(gFileFullPath);
	gImagesResultsSubFolder = gResultsSubFolder + "/" + gFileNameNoExt;
	File.makeDirectory(gImagesResultsSubFolder);
	run("Select None");
	run("Duplicate...", "title="+gAxonCh1Name+" duplicate channels="+axonCh1);
	run("Enhance Contrast", "saturated=0.35");		
	selectWindow(originalWindow);
	run("Duplicate...", "title="+gAxonCh2Name+" duplicate channels="+axonCh2);
	run("Enhance Contrast", "saturated=0.35");	
	

	
	axonCh1DansityMapTitle = CreateSegmentationAndDensityMap(gAxonCh1Name, iMinThresholdCh1, iMinAxonCh1);
	axonCh2DansityMapTitle = CreateSegmentationAndDensityMap(gAxonCh2Name, iMinThresholdCh2, iMinAxonCh2);
	if(openROIsFile(File.getDirectory(gFileFullPath)+gFileNameNoExt+gRoisSuffix))
	{
		windows = newArray(axonCh1DansityMapTitle,axonCh2DansityMapTitle); 
		GenerateCompositeResultTable(windows, originalWindow);
	}
	else
		print(File.getDirectory(gFileFullPath)+gFileNameNoExt+" has no ROIs");
	return true;
}*/

//GenerateCompositeResultTable:
// 1. for each window in a given list of windows (channels) it:
// 1.1 rum measurements on all rois
// 1.2 for each roi in the list of rois
// 1.2.1 for each meaasurment taken
// 1.2.1.1 it adds it to a single row per roi in a single table for all channels
// 1.2.1.2 if the macro runs on all files in a directory it will also add these row to a comulative table 
/*function GenerateCompositeResultTable(windows, originalWindow)
{	
	selectImage(originalWindow);
	run("Duplicate...", "duplicate channels=1");
	FlattenRois(getTitle(),gFileNameNoExt, "Yellow",10,"Jpeg", true);
	
	Table.create("Results");	
	selectImage(windows[0]);
	roiManager("Deselect");
	roiManager("Measure");
	selectWindow("Results");

	columns_names = split(Table.headings,"\t");
	Table.create(gCompositeTable);
	for(w=0;w<lengthOf(windows);w++)
	{	
		roiManager("Associate", "true");
		roiManager("Centered", "false");
		roiManager("UseNames", "true");
		FlattenRois(windows[w],File.getNameWithoutExtension(windows[w]), "Yellow",10,"Jpeg",true);	
		Table.create("Results");	
		selectImage(windows[w]);
		roiManager("Measure");
		for(r=0;r<nResults;r++)
		{
			for(c=1;c<lengthOf(columns_names);c++)
			{
				column_name = columns_names[c]+"_"+w;
				value = Table.getString(columns_names[c],r, "Results");
				Table.set(column_name,r,value,gCompositeTable);
				if(!matches(iProcessMode, "singleFile"))
					Table.set(column_name,gAllCompositeResults+r,value,gAllCompositeTable);
			}
		}	
		roiManager("Deselect");
	}
	gAllCompositeResults += nResults;
	fullPath = gResultsSubFolder+"/"+gFileNameNoExt+".csv";
	Table.save(fullPath,gCompositeTable);
}*/
//FlattenRois:
//to a given image it flattens all rois onto it and stroes it as Jpeg
function FlattenRois(imageId, name, color, width, extention,withLabels)
{
	selectImage(imageId);
	
	//RoiManager.setPosition(3);
	roiManager("Deselect");
	roiManager("Set Color", color);
	roiManager("Set Line Width", width);
	//n = roiManager("count");
	//arr = Array.getSequence(n);
	//roiManager("select", arr);
	//Roi.setFontSize(5)
	if(withLabels)
		roiManager("Show All with labels");
	else 
		roiManager("Show All without labels");
	//	Overlay.setLabelFontSize(5, 'sacle')
	run("Flatten");
	saveAs(extention, gImagesResultsSubFolder+"/"+name+"_rois."+extention);
}

// CreateSegmentationAndDensityMap:
// 1. on a given channel, run Tubeness filter + Threshold to generate Mask
// 2. run mean intensisty on the result to get density map
// 3. store it to disk 
// 4. stroe to disk the original channel with the threshold mask
function CreateSegmentationAndDensityMap(window, minThreshold, minAxonSize)
{
	selectWindow(window);
	getPixelSize(unit,pixelWidth, pixelHeight);
	pixelDensityRadius = Math.round((iDensityRadius)/pixelWidth);
	//print("pixelDensityRadius: " + pixelDensityRadius);
	run("Tubeness", "sigma="+iTubenessSigma+" use");
	setThreshold(minThreshold, 1000000000000000000000000000000.0000);
	setOption("BlackBackground", false);
	run("Analyze Particles...", "size="+minAxonSize+"-Infinity show=Masks exclude composite");
	run("Convert to Mask");	
	run("Create Selection");
	run("Select None");
	
	run("Divide...", "value=2.55");
	//run("Brightness/Contrast...");
	//setMinAndMax(0, iMaxDensity);

	run("Mean...", "radius="+pixelDensityRadius);
	run("Fire");
	setMinAndMax(0, iMaxDensity);	
	run("Calibration Bar...", "location=[Upper Right] fill=White label=Black number=5 decimal=0 font=12 zoom="+iZoomLevel+" overlay");
	dansityMapTitle = gFileNameNoExt + "_" + window + "_DensityMap_R"+pixelDensityRadius;
	rename(dansityMapTitle);
	//saveAs("Tiff", gImagesResultsSubFolder+"/"+title+".tif");
	saveAs("Tiff", gImagesResultsSubFolder+"/"+window+".tif");
	dansityMapTitle = getTitle();
	
	selectWindow(window);
	run("Grays");
	run("Restore Selection");
	//saveAs("Tiff", gImagesResultsSubFolder+"/"+gFileNameNoExt + "_"+window+"_Segmentation_T"+iMinThreshold+".tif");
	saveAs("Tiff", gImagesResultsSubFolder+"/"+window+"_Segmentation_T"+minThreshold+".tif");
	return dansityMapTitle;
}

function FinalActions()
{
	if(gAllCompositeResults > 0) // stroe allCompositeTable table
		Table.save(gResultsSubFolder+"/"+gAllCompositeTable+".csv", gAllCompositeTable);
}
// end of single file analysis

//--------Helper functions-------------

function Initialization()
{
	requires("1.53c");
	run("Check Required Update Sites");
	run("Configure ilastik executable location", "executablefile=["+iIlastikExe+"] numthreads=-1 maxrammb=150000");
	//run("Cellpose setup...", "cellposeenvdirectory="+iCellposeEnv+" envtype=conda usegpu=true usemxnet=false usefastmode=false useresample=false version=2.0");		
	
	setBatchMode(false);
	run("Close All");
	close("\\Others");
	print("\\Clear");
	run("Options...", "iterations=1 count=1 black");
	run("Set Measurements...", "area mean standard min centroid perimeter median display redirect=None decimal=3");
	roiManager("Reset");

	CloseTable("Results");
	CloseTable(gCompositeTable);	
	CloseTable(gAllCompositeTable);

	run("Collect Garbage");

	if (gBatchModeFlag)
	{
		print("Working in Batch Mode, processing without opening images");
		setBatchMode(gBatchModeFlag);
	}	

}

function checkInput()
{
	getDimensions (ImageWidth, ImageHeight, ImageChannels, ImageSlices, ImageFrames);

	/*if(ImageChannels < 3)
	{
		print("Fatal error: input file must include 3 channels: Lipid Droplets, Litosomes, and Mitocondria stainings");
		return false;
	}*/
	getPixelSize(unit,pixelWidth, pixelHeight);
	/*if(!matches(unit, "microns") && !matches(unit, "um"))
	{
		print("Fatal error. File " + gFileFullPath + " units are "+ unit+ " and not microns");
		return false;
	}*/
	return true;
}
//------openROIsFile----------
//open ROI file with 
function openROIsFile(ROIsFileNameNoExt, clearROIs)
{
	roiManager("deselect");
	// first delete all ROIs from ROI manager
	if(clearROIs && roiManager("count") > 0)
		roiManager("delete");

	// ROIs are stored in "roi" suffix in case of a single roi and in "zip" suffix in case of multiple ROIs
	RoiFileName = ROIsFileNameNoExt+".roi";
	ZipRoiFileName = ROIsFileNameNoExt+".zip";
	if (File.exists(RoiFileName) && File.exists(ZipRoiFileName))
	{
		if(File.dateLastModified(RoiFileName) > File.dateLastModified(ZipRoiFileName))
			roiManager("Open", RoiFileName);
		else
			roiManager("Open", ZipRoiFileName);
		return true;
	}
	if (File.exists(RoiFileName))
	{
		roiManager("Open", RoiFileName);
		return true;
	}
	if (File.exists(ZipRoiFileName))
	{
		roiManager("Open", ZipRoiFileName);
		return true;
	}
	return false;
}

function openROIs(ROIsFullName, clearROIs)
{
	roiManager("deselect");
	// first delete all ROIs from ROI manager
	if(clearROIs && roiManager("count") > 0)
		roiManager("delete");

	if (File.exists(ROIsFullName))
	{
		roiManager("Open", ROIsFullName);
		return true;
	}
	return false;
}
function openFile(fileName)
{
	// ===== Open File ========================
	// later on, replace with a stack and do here Z-Project, change the message above
	if ( endsWith(gFileFullPath, "h5") )
		run("Import HDF5", "select=["+gFileFullPath+"] "+ gH5OpenParms);
	if ( endsWith(gFileFullPath, "ims") )
		run("Bio-Formats Importer", "open=["+gFileFullPath+"] "+ gImsOpenParms);
	if ( endsWith(gFileFullPath, "nd2") )
		run("Bio-Formats Importer", "open=["+gFileFullPath+"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
	else
		open(gFileFullPath);
	

	return checkInput();
	
}


//----------LoopFiles-------------
// according to iProcessMode analyzes a single file, or loops over a directory or sub-directories
function LoopFiles()
{
	SetProcessMode();
	gResultsSubFolder = gMainDirectory + File.separator + "Results" + File.separator; 
	File.makeDirectory(gResultsSubFolder);
	
	if (matches(iProcessMode, "wholeFolder") || matches(iProcessMode, "singleFile")) {
		print("directory: "+ gMainDirectory);
		
		if (matches(iProcessMode, "singleFile")) {
			return ProcessFile(gMainDirectory); 
		}
		else if (matches(iProcessMode, "wholeFolder")) {
			return ProcessFiles(gMainDirectory); 
		}
	}
	
	else if (matches(iProcessMode, "AllSubFolders")) {
		list = getFileList(gMainDirectory);
		for (i = 0; i < list.length; i++) {
			if(File.isDirectory(gMainDirectory + list[i])) {
				gSubFolderName = list[i];
				gSubFolderName = substring(gSubFolderName, 0,lengthOf(gSubFolderName)-1);
	
				//directory = gMainDirectory + list[i];
				directory = gMainDirectory + gSubFolderName + File.separator;
				gResultsSubFolder = directory + File.separator + "Results" + File.separator; 
				File.makeDirectory(gResultsSubFolder);
				//resFolder = directory + gResultsSubFolder + File.separator; 
				//print(gMainDirectory, directory, resFolder);
				//File.makeDirectory(resFolder);
				print("inDir=",directory," outDir=",gResultsSubFolder);
				if(!ProcessFiles(directory))
					return false;
				print("Processing ",gSubFolderName, " Done");
			}
		}
	}
	return true;
}
function SaveParms(resFolder)
{
	//waitForUser("macro"+File.getNameWithoutExtension(getInfo("macro.filepath")));
	// print parameters to Prm file for documentation
	PrmFile = pMacroName+"Parameters.txt";
	if(iProcessMode == "singleFile")
		PrmFile = resFolder + File.getNameWithoutExtension(gFileFullPath) + "_" + PrmFile;
	else 
		PrmFile = resFolder + PrmFile;
		
	File.saveString("macroVersion="+pMacroVersion, PrmFile);
	File.append("", PrmFile); 
	
	File.append("RunTime="+getTimeString(), PrmFile);
	
	// save user input
//	File.append("processMode="+iProcessMode, PrmFile); 
//	File.append("fileExtention="+ iFileExtension, PrmFile); 
	File.append("iIlastikExe="+iIlastikExe+" \n", PrmFile); 
	File.append("iIlastikModelPath="+iIlastikModelPath, PrmFile)
 	File.append("iUseIlastikPrevRun="+iUseIlastikPrevRun, PrmFile)
 	File.append("iMainAngleVariance="+iMainAngleVariance, PrmFile)
	File.append("iMainGeneralOrientation="+iMainGeneralOrientation, PrmFile)
	File.append("iMinSkeletonLength="+iMinSkeletonLength, PrmFile)
	File.append("nm / pixel scale="+gScale, PrmFile)
	
  
 	//global parameters

}
function getTimeString()
{
	MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat");
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	TimeString ="Date: "+DayNames[dayOfWeek]+" ";
	if (dayOfMonth<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+dayOfMonth+"-"+MonthNames[month]+"-"+year+", Time: ";
	if (hour<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+hour+":";
	if (minute<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+minute+":";
	if (second<10) {TimeString = TimeString+"0";}
	TimeString = TimeString+second;
	return TimeString;
}
//===============================================================================================================
// Loop on all files in the folder and Run analysis on each of them
function ProcessFiles(directory) 
{
	Table.create(gAllCompositeTable);		
	gAllCompositeResults = 0;

	setBatchMode(gBatchModeFlag);
	dir1=substring(directory, 0,lengthOf(directory)-1);
	idx=lastIndexOf(dir1,File.separator);
	subdir=substring(dir1, idx+1,lengthOf(dir1));

	// Get the files in the folder 
	fileListArray = getFileList(directory);
	
	// Loop over files
	for (fileIndex = 0; fileIndex < lengthOf(fileListArray); fileIndex++) {
		if (endsWith(fileListArray[fileIndex], iFileExtension) ) {
			gFileFullPath = directory+File.separator+fileListArray[fileIndex];
			print("\nProcessing:",fileListArray[fileIndex]);
			showProgress(fileIndex/lengthOf(fileListArray));
			if(!ProcessFile(directory))
				return false;
			CleanUp(false);		
		} // end of if 
	} // end of for loop
	FinalActions();
	CleanUp(true);
	return true;
} // end of ProcessFiles

function CleanUp(finalCleanUp)
{
	run("Close All");
	close("\\Others");
	run("Collect Garbage");
	if (finalCleanUp) 
	{
		CloseTable(gAllCompositeTable);	
		setBatchMode(false);
	}
}
function SetProcessMode()
{
		// Choose image file or folder
	if (matches(iProcessMode, "singleFile")) {
		gFileFullPath=File.openDialog("Please select an image file to analyze");
		gMainDirectory = File.getParent(gFileFullPath);
	}
	else if (matches(iProcessMode, "wholeFolder")) {
		gMainDirectory = getDirectory("Please select a folder of images to analyze"); }
	
	else if (matches(iProcessMode, "AllSubFolders")) {
		gMainDirectory = getDirectory("Please select a Parent Folder of subfolders to analyze"); }
}

//===============================================================================================================
function CloseTable(TableName)
{
	if (isOpen(TableName))
	{
		selectWindow(TableName);
		run("Close");
	}
}
