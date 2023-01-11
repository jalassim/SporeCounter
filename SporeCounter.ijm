/********** Informations ********************
 Script Author: Julien Alassimone 
 Date: 10/03/2022  
  
This script uses the Live Macro plugging developed by Jerome Mutterer (jerome.mutterer@ibmp.fr - https://www.cnrs.fr/fr/personne/jerome-mutterer) to access the Camera feed
 https://imagejdocu.tudor.lu/plugin/utilities/livemacro/start
 
Live Macro is a project based on 
 https://imagej.nih.gov/ij/plugins/webcam-capture/index.html
 https://figshare.com/articles/dataset/A_generic_webcam_image_acquisition_plugin_for_ImageJ/3397732/1

JAR files Requirements:
- bridj-0.7-20130703.103049-42.jar
- live_macro.jar
- rsyntaxtextarea-3.0.0-SNAPSHOT.jar
- slf4j-api-1.7.2.jar

V2.8 - J.Alassimone - Corrected dilution factor error on the 10E7 adjustment (was 10E6 in previous versions)
V2.11 - J.Alassimone - Corrected tables error, Fix critical bugs in the spores calculation, added summary tables, updates setting save, added addaptation to screen resolution)
V2.12 - J.Alassimone - added Gaussian Filtering for high resolution, adjstememt of the scale when typing so it scale to the resolutions

To do list : 
//standads error stats?
//Add metadata?
**************************************/

/* General info */
setBatchMode(true); //start work in Bash mode
Version="V2.12"; // Edit the version here when making modifs

/* Prerequisit 3 */
run("Collect Garbage"); // soft reset of ImageJ memory
OpenWin=getList("window.titles"); //get a list of all opened windows
PreviousImg=getList("image.titles"); //get a list of all opened images
OpenWin=Array.concat(OpenWin,PreviousImg); //add the list of all opened windows to the list of opened Windows
for (zz = 0; zz < OpenWin.length; zz++) { // Loop1- Loop to close all non image windows except the log
	if (OpenWin[zz]!="Log"){ //if-11- if the open window is the log
		selectWindow(OpenWin[zz]); //select the window
		run("Close"); //close the window
	}//close if-1
}//close loop1
dir=File.getDefaultDir;// get the current Working directory
ScrnHeight=screenHeight; //get the screen Height for window adjustement
ScrnWidth=screenWidth; //get screen Width for window adjustment
MoveIJWindow= //move imageJ window to top left corner
	"IJ.getInstance().setLocation(0,0)";
eval("script", MoveIJWindow);

/* defining functions */
function contains( array, value ) { //function that indicates if a value is present in an array
    for (i=0; i<array.length; i++) 
        if ( array[i] == value ) return true;
    return false;
}

/* Settings */
Gaussian=1; //default value for the Gaussian filter applied before the particule detection	
MinSize=0.01; // default value for the particule detection minimal size (in um)
MaxSize=1000; // default value for the particule detection maximum size (in um)
MinCirc=0; // default value for the particule detection minimal circularity (0=line; 1=perfect circle)
MaxCirc=0.9; // default value for the particule detection maximal circularity (0=line; 1=perfect circle)
DilutionFactor=100; // default value of the dilution factor (used for spore concentration calculation)
Line=""; // default value for line name (use "" for an empty field)
BlurNb=10; // default value for background removal blur to do a background removal
ThresholdMethod="Otsu"; // default value for the thresholding applied before particule detection
OverlaySet="Outlines"; // default option for the display of the detection ("Outlines" or "threshold").

/* set increments */
Terminate=false; //set a switch for the Macro ending 
SameDilution=true; //set a switch to know when user indicates the next dilution 
SameLine=true; //set a switch to know when user indicates the next line 
Dilution=1; //set a increment to keep track of the dilution number
NbQuantifPerline=0; //set a increment to keep track of the dilution number for each line
NbQuantifPerDilution=0; //set a increment to keep track of the dilution number for each dilution
imNb=0; //set a increment to keep track of the number of images (also used for file naming)
SaveOnlyIc=0; 
TableInc=100000000;//increment to reverse the result table
SumInc=0;

/* User interface */
Dialog.create("Macro info/settings"); 
Dialog.addMessage("*********************  Macro settings  **************************** ");
Dialog.addDirectory("Analysis saved in:",dir);
Dialog.addChoice("Color Transfo.", newArray("8-bit","16-bit","32-bit"),"32-bit");
Dialog.addNumber("Size of the smallest Kova Chamber Square (mm):", 0.330);
Dialog.addNumber("Chamber Depth (mm)",0.1);
Dialog.addNumber("Scale (pix/um)",0.6425);
Dialog.addChoice("Rescaling:", newArray("No","Yes"));
Dialog.addMessage("NB1: Scaling info will be listed in the Setting file");
Dialog.addMessage("NB2: !!!Never close the images or the popUp windows/menus!!!");
Dialog.addMessage("NB3: !!!Never press on CANCEL !!!");
Dialog.show(); //display the message

dir=Dialog.getString(); //get user defined folder to saves the analysis
Bits=Dialog.getChoice(); // get user choice for image transformation 8bits or 32bits
KovaKnownSizeMM=Dialog.getNumber(); // get size of the cova chambers in mm
KovaKnownSize=KovaKnownSizeMM*1000; // transfor the size of the cova chambers in um
Depth=Dialog.getNumber(); //get Kova chamber depth (mm)
Scale=Dialog.getNumber(); // Scale in um/pixel
UserDefinedScale=Scale; //keep track of the user defined scale fo the "settings" report
Rescaling=Dialog.getChoice(); //get rescaling option choice

/* Creating folders */
	/* Get time */
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec); //get universal time
year1=year-2000; //change the year for a 2 digit number
MonthNames = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"); //array to change month from digit to names
DayNames = newArray("Sun", "Mon","Tue","Wed","Thu","Fri","Sat"); //array to change days from digit to names
if (month<10) {month = "0"+month;} //if value is smaller than 10 add a 0 in front of it
if (dayOfMonth<10) {dayOfMonth = "0"+dayOfMonth;}//if value is smaller than 10 add a 0 in front of it
if (hour<10) {hour = "0"+hour;}//if value is smaller than 10 add a 0 in front of it
if (minute<10) {minute = "0"+minute;}//if value is smaller than 10 add a 0 in front of it
if (second<10) {second = "0"+second;}//if value is smaller than 10 add a 0 in front of it
TimeStamp = ""+year1+""+month+""+dayOfMonth+"_"+hour+"h"+minute+"_"; //create time stamp for the folder name
TimeStampSimple = ""+year1+""+month+""+dayOfMonth+""; //create time stamp for the folder name
	/* Create folders */
AnalysisDir=dir+TimeStamp+"Spore_Count_Array_Analysis"+ File.separator; //create a path for the analysis folder
RoiDir=AnalysisDir+"ROI"+ File.separator;  //create a path for a folder to save the selections as ROI zip files
PicDir=AnalysisDir+"pictures"+ File.separator; //create a path for a folder to save the pictures
OverlayDir=AnalysisDir+"Overlays"+ File.separator; //create a path for a folder to save the overlays
File.makeDirectory(AnalysisDir); //create folder
File.makeDirectory(RoiDir); //create folder
File.makeDirectory(PicDir); //create folder
File.makeDirectory(OverlayDir); //create folder

/* Creating Array for data collection */

NotAnalysed_Array=newArray(); // create array to save : images that were not analyses (used in "Non analysed" table)

Spore_Count_Array=newArray(); // create array to save : count number (used in "Counting_Results" table)
Analysed_Pic_Array=newArray(); // create array to save : image names (used in "Counting_Results" table)
Dilution_Factor_Array=newArray(); // create array to save : user defined dilution factor for each image (used in "Counting_Results" table)
RawConcentration_Array=newArray(); // create array to save : calculated spore concentration  (used in "Counting_Results" table)
Undiluted_Sample_Array=newArray(); // create array to save : Non diluted spore concentration (used in "Counting_Results" table)
Undiluted_Sample_Array_10e7_Array=newArray();  // create array to save : Non diluted spore concentration modified to 10e7 (used in "Counting_Results" table)
PicLineArray=newArray();  // create array to save : line names (used in "Counting_Results" table)
ThresholdMethod_Array=newArray();  // create array to save : User defined Thresholding method (used in "Counting_Results" table)
ThresholdMin_Array=newArray();  // create array to save : User defined min Thresholding value (used in "Counting_Results" table)
ThresholdMax_Array=newArray(); // create array to save : User defined max Thresholding value (used in "Counting_Results" table)
BlurNb_Array=newArray(); // create array to save : User defined value for background removal blur (used for background removal)(used in "Counting_Results" table)
Gaussian_Array=newArray(); // create array to save : Gaussian blur value applyed before particule detection (used in "Counting_Results" table)
MinSize_Array=newArray(); // create array to save : minimal size particule detection (used in "Counting_Results" table)
MaxSize_Array=newArray(); // create array to save : max size particule detection (used in "Counting_Results" table)
MinCirc_Array=newArray(); // create array to save : minimal circularity particule detection (used in "Counting_Results" table)
MaxCirc_Array=newArray();  // create array to save : max circularity particule detection (used in "Counting_Results" table)
DilutionFactor_Array=newArray(); // create array to save : dilution factor (used in "Counting_Results" table)
OverlaySet_Array=newArray(); // create array to save : display of the detection (used in "Counting_Results" table)
imNumber_array=newArray();  // create array to save : image number (used in "Counting_Results" table)

TableIncArray=newArray(); //array to reverse the "Counting_Results" table and display the last aquisition result on the first row

Dilution_Array=newArray(); // create array to save the dilution number (used in "Results Stats" table - reset for each line)

LineArray=newArray();  // create array to save : line names (used in "Summary" table)

Spore_Count_Main_Array=newArray(); // create array to save : counts number for each line (used to calculate mean and statistics )
RawConcentration_Main_Array=newArray(); // create array to save : calculated spore concentration for each line (used to calculate mean and statistics )
Undiluted_Sample_Array_10e7_Main_Array=newArray(); // create array to save : Non diluted spore concentration modified to 10e7 for each line (used to calculate mean and statistics )

Spore_Count_Dilution_Array=newArray(); // create array to save : counts number for each dilution (used to calculate mean and statistics )
RawConcentration_Dilution_Array=newArray(); // create array to save : calculated spore concentration for each dilution (used to calculate mean and statistics )
Undiluted_Sample_Array_10e7_Dilution_Array=newArray(); // create array to save : Non diluted spore concentration modified to 10e7 for each dilution (used to calculate mean and statistics )

/*start Live feed acquisiion */
setBatchMode(false); // exit Bach mode otherwise LiveMacro plugin crashes
doCommand("Live Macro");// Start the Live Macro plugin
OpenedImages=getList("image.titles"); //get a list of all opened images (to be able do know when live macro is successful lauched)

while ( !contains( OpenedImages, "Live" ) ){ //While-1 :loop to display message while Live feed is opening. (This loop assess if the "live" image is opened)
	showStatus("!Macro will start when \"Live\" is ON .");wait(400);
	showStatus("!Macro will start when \"Live\" is ON ..");wait(400);
	showStatus("!Macro will start when \"Live\" is ON ...");wait(400);
	showStatus("!Macro will start when \"Live\" is ON ....");wait(400);
	showStatus("!Macro will start when \"Live\" is ON .....");wait(400);
	OpenedImages=getList("image.titles"); // get the list of all opened image for the while condition assessement
	} //Close While-1
	
LivePicID=getImageID(); // get ID number of live feed window
selectImage(LivePicID); // Select the live feed window
run("Set Scale...","distance=0 known=0 unit=unit");//remove any previous scale
LivePicZoom=getZoom(); //get the zoom factor of the live feed window for all other display adjustements
if (LivePicZoom<1) { //if zoom factor of the live feed window is smaller than 1 (if live feed window is reduced)
	run("View 100%");//Make the live feed window unzooomed
	LivePicZoom=getZoom(); 
}
if (LivePicZoom>1) LivePicZoom=1; //if zoom is bigger tha  100% set the zoom factor to 100% 
LivePicHeight=getHeight(); //get the live feed window height
LivePicWidth=getWidth(); //get the live feed window
Resolution=LivePicHeight*LivePicWidth; //
DefaultResolution=640*480;
ResolutionAdjustement=LivePicWidth/640;
Scale=Scale*ResolutionAdjustement;
LiveDisplayWidth=LivePicZoom*LivePicWidth;
LiveDisplayHeight=LivePicZoom*LivePicHeight;
while (LiveDisplayWidth>(ScrnWidth/(2))) {
	run("Out [-]");
	LivePicZoom=getZoom();
	if (LivePicZoom>1) LivePicZoom=1;
	LiveDisplayWidth=LivePicZoom*LivePicWidth;
	LiveDisplayHeight=LivePicZoom*LivePicHeight;
}
setLocation(0,screenHeight/8);
showStatus("!Macro running"); // display message in ImageJ window
setBatchMode(true); //start headless mode

/* Scaling */

if(Rescaling=="Yes"){
	ScaleDir=AnalysisDir+"Scaling"+ File.separator; //defining folder path to create the folder where scaling picture are saved
	File.makeDirectory(ScaleDir); //create the folder
	selectImage(LivePicID); //Test unbugg V2.10
	run("Line Width...", "line=10");//Test unbugg V2.10
	Xa=-1; //increment fo the following While loop.
	
 	waitForUser("Please find small Kova chamber squares\nAnd click on \"OK\".");//display message to ask user to find a kova area
 	run("Select None");
 	run("Duplicate...","title=Scaling image"); //duplicate image from live feed
 	setTool("line"); //select line tool
 	
 	setBatchMode("show"); //display the image to user
 	run("Set... ", "zoom="+(LivePicZoom*100)+" x=0 y="+(screenHeight/8)+"");
 	ScalePicID=getImageID(); //get window ID number for selection
	PicPath=ScaleDir+"scalingPic.png"; //defining image Path for the scaling picture save
	saveAs("png", PicPath);//save pic
	while (Xa==-1){ //Do the following until a line is drawn
			selectImage(ScalePicID);
//			setLocation(0,120);
			setLocation(0,screenHeight/8);
			waitForUser("Draw a line of the legth of the Kova chamber grid\nBe as precise as possible\nClick on \"OK\".");//display message to ask again to draw the line
			if (is("line")==true) getLine(Xa,Ya,Xb,Yb,KovaLength); //get line coordonates
			
		} //close While loop
	setBatchMode("hide"); //hide picture
	selectImage(LivePicID);
	run("Select None"); 
	CalibLenght=Math.sqrt((Math.sqr(Xb-Xa))+(Math.sqr(Yb-Ya))); //Calcul the lenght of the line drawn by the user
	run("Set Scale...", "distance="+CalibLenght+" known="+KovaKnownSize+" unit=um global"); //set global scale
//	Scale=KovaKnownSize/CalibLenght; //calculate scaling info for report table
	Scale=CalibLenght/KovaKnownSize; //calculate scaling info for report table pix/um
	selectImage(ScalePicID);
	Overlay.addSelection;
	Overlay.flatten
	PicPath=ScaleDir+"scalingPic_Overlay.png";
	ScaleOvelayID=getImageID();
	saveAs("png", PicPath);
	selectImage(ScaleOvelayID);
	close();
	selectImage(ScalePicID);
	close();
}

/* Save settings /scaling info */

nameSetting = "[Settings]";
f = nameSetting;
//run("New... ", "name="+nameSetting+" type=Table");
run("Text Window...", "name="+nameSetting+" width=72 height=8");
print(f, "Macro \"Spore Count\" version "+Version+".\n");
print(f, " - Date: "+DayNames[dayOfWeek]+" "+dayOfMonth+"-"+MonthNames[month]+"-"+year+"\n - Time: "+hour+":"+minute+":"+second);
print(f, "\n**************** Macro Settings *************************\n");
print(f, "Images converted in : "+Bits+".\n");
print(f, "Size of the smallest Kova Chamber Square: "+KovaKnownSize+"mm.\n");
print(f, "Chamber Depth: "+Depth+"(mm).\n");
print(f, "Rescaling: "+Rescaling+"\n");
//print(f, "Scale: "+Scale+"(um/pixel).\n");
if((Rescaling=="No")&&(ResolutionAdjustement!=1)) print(f, "Resolution ("+LivePicWidth+"x"+LivePicHeight+") is different from the standard 640x480pixels.\n User defined scales was adjusted as such "+UserDefinedScale+"x"+ResolutionAdjustement+".\n");
print(f, "Scale: "+Scale+"(pixel/um).\n");
print(f, "\n************ Field of view information ******************\n");
if(Rescaling=="Yes") print(f, "Smaller Kova square area =>"+CalibLenght+"x"+CalibLenght+"="+CalibLenght*CalibLenght+" pixel^2.\n");
print(f, "Smaller Kova square area => "+KovaKnownSizeMM+"x"+KovaKnownSizeMM+"="+KovaKnownSizeMM*KovaKnownSizeMM+" mm^2.\n");
print(f, "the field of view area => "+LivePicWidth+"x"+LivePicHeight+"="+LivePicWidth*LivePicHeight+" pixel^2.\n");
//print(f, "the field of view area => "+LivePicWidth*Scale+"x"+LivePicHeight*Scale+"="+(LivePicWidth*Scale)*(LivePicHeight*Scale)+" um^2="+((LivePicWidth*Scale)*(LivePicHeight*Scale))/1000000+" mm^2.\n");// scale in um/pix
print(f, "the field of view area => "+LivePicWidth/Scale+"x"+LivePicHeight/Scale+"="+(LivePicWidth/Scale)*(LivePicHeight/Scale)+" um^2="+((LivePicWidth/Scale)*(LivePicHeight/Scale))/1000000+" mm^2.\n");//scale in pix/um
//print(f, "Proportion => 1field of view="+((((LivePicWidth*Scale)*(LivePicHeight*Scale))/1000000)/(KovaKnownSizeMM*KovaKnownSizeMM))+" small kova squares.\n");// scale in um/pix
print(f, "Proportion => 1field of view="+((((LivePicWidth/Scale)*(LivePicHeight/Scale))/1000000)/(KovaKnownSizeMM*KovaKnownSizeMM))+" small kova squares.\n");//scale in pix/um
print(f, "\n************ Image Processing pipeline ******************\n");
print(f, "1) images are duplicated form the webcam Live feed\n");
print(f, "2) Image Type is change to the selected Mode (8 or 32 bits)\n");
print(f, "3) A gaussian blur background removal treatment is applied \n");
print(f, "	gaussian blur background removal treatment details:\n");
print(f, "	-image is duplicated\n");
print(f, "	-A Gaussian blur using the macro settings requirement is applied\n");
print(f, "	-the Gaussian treated image is removed to the image using the  image calculator function. \n");
print(f, "4) A Gaussian blur filtering is applied to the picture to smooth the spores textures (Vaule is user defined and saved in the results table)\n");
print(f, "5) the Selected Thresholding method is applied the the background removed image.\n");
print(f, "6) particule are detected and counted using the imageJ \"Analyze Particles\" using the user defined settings\n");
print(f, "7) Results are harvested and data handling/statist calculations are performed. \n");
print(f, "8) Selection overlays are then applied to the original Live feed duplicated image for display\n");
print(f, "\n**************** Macro JAR Requirements ****************\n");
print(f, "JAR files Requirements:\n");
print(f, "- bridj-0.7-20130703.103049-42.jar\n");
print(f, "- live_macro.jar\n");
print(f, "- rsyntaxtextarea-3.0.0-SNAPSHOT.jar\n");
print(f, "- slf4j-api-1.7.2.jar\n");
print(f, "\n**************** Macro Credits *************************\n");
print(f, "- This script was developed by Julien Alassimone (julien.alassimone@usys.ethz.ch - https://ch.linkedin.com/in/julienalassimone).\n"); 
print(f, "- This Macro uses the Live Macro plugging developed by Jerome Mutterer (jerome.mutterer@ibmp.fr - https://www.cnrs.fr/fr/personne/jerome-mutterer) to access the Camera feed.\n");
print(f, "	https://imagejdocu.tudor.lu/plugin/utilities/livemacro/start\n");
print(f, "- Live Macro is a project based on IJ_webcam_plugin. for more details about IJ_webcam_plugin see:\n");
print(f, "	https://imagej.nih.gov/ij/plugins/webcam-capture/index.html\n");
print(f, "  https://figshare.com/articles/dataset/A_generic_webcam_image_acquisition_plugin_for_ImageJ/3397732/1\n");
saveAs("text", AnalysisDir+ "Settings.txt");
run("Close");

// start of analysis
OpenedImages=getList("image.titles");


//test 28/03
Table.create("Summary.csv"); 
//Table.setLocationAndSize((LivePicWidth+230), 0, (ScrnWidth-(LivePicWidth+230)), 250);
Table.setLocationAndSize((LiveDisplayWidth+230), 0, (ScrnWidth-(LiveDisplayWidth+230)), (ScrnHeight/6));
Table.set("LineArray", SumInc, 0);
Table.set("Nb of pictures analysed", SumInc, 0);
Table.set("Av.Count.", SumInc, 0);
Table.set("Std.Count", SumInc, 0);
Table.set("SEM.Count", SumInc, 0);
Table.set("spores/ul", SumInc, 0);
Table.set("Undil.Conc.(10^7/ml)", SumInc, 0);
Table.update;



Table.create("Results Stats"); 
//Table.setLocationAndSize((LivePicWidth+230), 0, (ScrnWidth-(LivePicWidth+230)), 250);
Table.setLocationAndSize((LiveDisplayWidth+230), (ScrnHeight/6), (ScrnWidth-(LiveDisplayWidth+230)), (ScrnHeight/6));

while  (((contains(OpenedImages, "Live"))==true)&&(Terminate==false)) {//test final
	
	if (contains(OpenedImages, "Live")){
		Dialog.createNonBlocking("Analysis next image");
		Dialog.setLocation((LiveDisplayWidth+20), 0);
		//Dialog.setLocation(650,0);
//		Dialog.addMessage("==== Settings ====");	
		Dialog.addMessage("Threshold Method:");
		Dialog.setInsets(0,-90,0);
		Dialog.addChoice("", newArray("Otsu","Triangle","Minimum","Default","Huang","IsoData","IJ_IsoData","Li","Intermodes","MaxEntropy","MinError","Moments","Mean","RenyiEntropy","Shanbhag","Yen","Percentile"),ThresholdMethod); 
		//Dialog.addChoice("Method:", newArray(1,2,3),1); 
//		Dialog.setInsets(top, left, bottom);
//		Dialog.setInsets(0,10,-200);
		Dialog.addMessage("Detection Overlay:");
//		Dialog.setInsets(-300,0,0);
		Dialog.addRadioButtonGroup("", newArray("Outlines","threshold"), 2, 1,OverlaySet);
		Dialog.addMessage("Background");
		Dialog.addNumber("Remov.(px):",BlurNb);
		Dialog.addNumber("Gauss. Filt.(pix):",Gaussian);
		Dialog.addNumber("min size.(um):",MinSize);
		Dialog.addNumber("max size.(um):",MaxSize);
		Dialog.addNumber("min Circ.",MinCirc);
		Dialog.addNumber("max Circ.",MaxCirc);
		Dialog.addNumber("Dilution factor 1/",DilutionFactor);
		Dialog.addMessage("=== Next Image ===");
		Dialog.setInsets(5,-100,5);
		Dialog.addString("Line Name:",Line );
		Dialog.addMessage("Dilution: "+Dilution);
		Dialog.addMessage("==============");
		Dialog.addCheckbox("Next Dilution:", false);
		Dialog.addCheckbox("Save only in sep. Folder:", false);
		Dialog.addCheckbox("End Analysis:", false);
		Dialog.show(); //display the message
		//OpenedImages=getList("image.titles");

		ThresholdMethod=Dialog.getChoice();
		OverlaySet=Dialog.getRadioButton;
		BlurNb=Dialog.getNumber();
		Gaussian=Dialog.getNumber();
		MinSize=Dialog.getNumber();
		MaxSize=Dialog.getNumber();
		MinCirc=Dialog.getNumber();
		MaxCirc=Dialog.getNumber();
		DilutionFactor=Dialog.getNumber();
		NextLine=Dialog.getString();
		DilutionUp=Dialog.getCheckbox();
		SaveOnly=Dialog.getCheckbox();
		Terminate=Dialog.getCheckbox();
		
		if (Terminate==false) {
			
			if (NextLine!=Line) {
				SameLine=false;
				DilutionUp=false;
				Line=NextLine;
				imNb=0;//reset Image Number
				Dilution=1;//reset Dilution Number
//				DilNb_Array=newArray();//reset Array for stat table
				//store Dilution data in array fo stat table
				NbQuantifPerline=1;
				NbQuantifPerDilution=0;
				//reset array line
				Spore_Count_Main_Array=newArray();
				Spore_Count_Main_n1_Array=newArray();	
				RawConcentration_Main_Array=newArray();
				RawConcentration_Main_n1_Array=newArray();
				Undiluted_Sample_Array_10e7_Main_Array=newArray();
				Undiluted_Sample_Array_10e7_Main_n1_Array=newArray();
				RawConcentration_Main_Array=newArray();
				Undiluted_Sample_Array_10e7_Main_Array=newArray();
				
				Spore_Count_Dilution_Array=newArray();
    			Spore_Count_Dilution_Array=newArray();
    			RawConcentration_Dilution_Array=newArray();
    			Undiluted_Sample_Array_10e7_Dilution_Array=newArray();

				SumInc++;

					
			}else {
				SameLine=true;
				NbQuantifPerline++;
			}
		
			//create a folder for separate picture once
			if (SaveOnly==true){
				SaveOnlyIc++;
				if (SaveOnlyIc==1){//create a folder for separate picture once
					SaveOnlyDir=AnalysisDir+"Save_Only"+ File.separator;
					File.makeDirectory(SaveOnlyDir); //create the folder
				}
			}	
	
			if (Analysed_Pic_Array.length<1) DilutionUp=false; //unbugged first picture with "next dilution" activated
			
			if (DilutionUp==true) {
				SameDilution=false;
				Dilution++;
				imNb=1;
				NbQuantifPerDilution=1;
				Spore_Count_Dilution_Array=newArray();
				Spore_Count_Dilution_n1_Array=newArray();	
				RawConcentration_Dilution_Array=newArray();
				RawConcentration_Dilution_n1_Array=newArray();
				Undiluted_Sample_Array_10e7_Dilution_Array=newArray();
				Undiluted_Sample_Array_10e7_Dilution_n1_Array=newArray();
				Spore_Count_Dilution_Array=newArray();
//				DilNb_Array=newArray();
				RawConcentration_Dilution_Array=newArray();
				Undiluted_Sample_Array_10e7_Dilution_Array=newArray();
			}else {
				SameDilution=true;
				NbQuantifPerDilution++;
//				DilNb_Array=Array.concat(DilNb_Array,Dilution);
				imNb ++;
			}
						
			selectImage(LivePicID);
			setLocation(0,screenHeight/8);
			CurrentPic=TimeStampSimple+"_"+Line+"_Dil"+Dilution+"_im"+imNb;
 			run("Duplicate...","title="+CurrentPic);
 			CurrentPicID=getImageID();
 			if (SaveOnly==true) {
				SaveOnlyPath=SaveOnlyDir+CurrentPic+".png";
				saveAs("png", SaveOnlyPath);
				NbQuantifPerline--;
				NbQuantifPerDilution--;
			}else {
				 	
			PicPath=PicDir+CurrentPic+".png";			

			saveAs("png", PicPath);
	 		run("Duplicate...","title=Current8bits");	
			run(Bits);
			//run("8-bit");
			run("Duplicate...","title=BK");
			run("Gaussian Blur...", "sigma=10");
			imageCalculator("Divide create 32-bit", "Current8bits","BK");
			MinusBKID=getImageID();
//			run("Mean...", "radius=1");
			run("Gaussian Blur...","radius="+Gaussian+"");
			
			setAutoThreshold(ThresholdMethod);
			getThreshold(lower, upper); 
			run("Analyze Particles...", "size="+MinSize+"-"+MaxSize+" circularity="+MinCirc+"-"+MaxCirc+" show=Overlay clear include");
			count=(Overlay.size);
			selectImage(MinusBKID);
			Overlay.copy;
			selectImage(CurrentPicID);
			Overlay.paste;	
			
			if (OverlaySet=="threshold"){
				run("Overlay Options...", "stroke=cyan width=1 fill=#4c00ff00 apply show");
			};else  {
				run("Overlay Options...", "stroke=cyan width=1 fill=none apply show");
			}
				
			close("Current8bits");
			close("BK");
			close(MinusBKID);
			selectImage(CurrentPicID);
			setBatchMode("show");
			run("Set... ", "zoom="+(LivePicZoom*100)+" x=0 y=0");
			setLocation(0,(screenHeight/8)); //same location as the Live window. It should mask the live feed
			Dialog.createNonBlocking("Detection validation");
			Dialog.setLocation((LiveDisplayWidth+20),500); //Next Analysis window = 480x640 pix- Using 460 pix aligne the "ok" button
			Dialog.addMessage("Count Nb="+count+"\n\n", 12,"red");			
//			Dialog.addRadioButtonGroup("Add to analysis ?", newArray("yes","no"), 1, 2, "yes");
			Dialog.addChoice("add to the results?", newArray("Yes","No"),"Yes");
			Dialog.show(); //display the message
		
			add_to_analysis=Dialog.getChoice();	
//			add_to_analysis=Dialog.getRadioButton;
			setBatchMode("hide");
			if (add_to_analysis=="yes"){
				TableInc=TableInc-1; //V2.10
				TableIncArray=Array.concat(TableIncArray,TableInc);//V2.10
				//save info from interface in Arrays
				imNumber_array=Array.concat(imNumber_array,imNb);
				Dilution_Array=Array.concat(Dilution_Array, Dilution);
				PicLineArray=Array.concat(PicLineArray,Line);
				ThresholdMethod_Array=Array.concat(ThresholdMethod_Array,ThresholdMethod); 
				ThresholdMin_Array=Array.concat(ThresholdMin_Array,lower);
				ThresholdMax_Array=Array.concat(ThresholdMax_Array,upper);
				BlurNb_Array=Array.concat(BlurNb_Array,BlurNb);
				Gaussian_Array=Array.concat(Gaussian_Array,Gaussian);
				MinSize_Array=Array.concat(MinSize_Array,MinSize);
				MaxSize_Array=Array.concat(MaxSize_Array,MaxSize);
				MinCirc_Array=Array.concat(MinCirc_Array,MinCirc);
				MaxCirc_Array=Array.concat(MaxCirc_Array,MaxCirc);
				OverlaySet_Array=Array.concat(OverlaySet_Array,OverlaySet);
				Dilution_Factor_Array=Array.concat(Dilution_Factor_Array,DilutionFactor);
//				Scale_Array=Array.concat(Scale_Array,Scale);
				
				selectImage(CurrentPicID);
				Overlay.show;
				path_overlay=OverlayDir+CurrentPic+"_Overlay.png";
				saveAs("png",path_overlay);//save scale pic
				//Overlay.drawLabels(false);
				run("To ROI Manager");
				RoiPath=RoiDir+CurrentPic+"_Roi.zip";
				roiManager("save",RoiPath);
				roiManager("reset");			

				/* Add results to Array for display */
				Analysed_Pic_Array=Array.concat(Analysed_Pic_Array,CurrentPic);
				Spore_Count_Array=Array.concat(Spore_Count_Array,count);
				Width=getWidth();
				Heigth=getHeight();
				toScaled(Width,Heigth);
				Width_mm=Width/1000;	
				Heigth_mm=Heigth/1000;
				Volume=Width_mm*Heigth_mm*Depth;
				Concentration=count/Volume; //ul;
				RawConcentration_Array=Array.concat(RawConcentration_Array,Concentration);
				non_diluted=Concentration*DilutionFactor;
				
				Undiluted_Sample_Array=Array.concat(Undiluted_Sample_Array,non_diluted);
				non_diluted_ml=non_diluted*1000;
				Undiluted_Sample_Array_10e7_Array=Array.concat(Undiluted_Sample_Array_10e7_Array,(non_diluted_ml/10000000));

				/*statistics */
				Spore_Count_Main_Array=Array.concat(Spore_Count_Main_Array,count);
				Array.getStatistics(Spore_Count_Main_Array, Spore_Count_Main_Array_min, Spore_Count_Main_Array_max, Spore_Count_Main_Array_mean, Spore_Count_Main_Array_stdDev);
				Spore_Count_Main_SEM=Spore_Count_Main_Array_stdDev/Math.sqrt(Spore_Count_Main_Array.length);
//				Spore_Count_Main_n1_Array=Array.trim(Spore_Count_Main_Array, ((Spore_Count_Main_Array.length)-1));
//				Array.getStatistics(Spore_Count_Main_n1_Array, Spore_Count_Main_n1_Array_min, Spore_Count_Main_n1_Array_max, Spore_Count_Main_n1_Array_mean, Spore_Count_Main_n1_Array_stdDev);
//				Spore_Count_Main_n1_SEM=Spore_Count_Main_n1_Array_stdDev/Math.sqrt(Spore_Count_Main_n1_Array.length);		

				Spore_Count_Dilution_Array=Array.concat(Spore_Count_Dilution_Array,count);
				Array.getStatistics(Spore_Count_Dilution_Array, Spore_Count_Dilution_Array_min, Spore_Count_Dilution_Array_max, Spore_Count_Dilution_Array_mean, Spore_Count_Dilution_Array_stdDev);
				Spore_Count_Dilution_SEM=Spore_Count_Dilution_Array_stdDev/Math.sqrt(Spore_Count_Dilution_Array.length);		
//				Spore_Count_Dilution_n1_Array=Array.trim(Spore_Count_Dilution_Array, ((Spore_Count_Dilution_Array.length)-1));
//				Array.getStatistics(Spore_Count_Dilution_n1_Array, Spore_Count_Dilution_n1_Array_min, Spore_Count_Dilution_n1_Array_max, Spore_Count_Dilution_n1_Array_mean, Spore_Count_Dilution_n1_Array_stdDev);
//				Spore_Count_Dilution_n1_SEM=Spore_Count_Dilution_n1_Array_stdDev/Math.sqrt(Spore_Count_Dilution_n1_Array.length);		

				RawConcentration_Main_Array=Array.concat(RawConcentration_Main_Array,Concentration);
				Array.getStatistics(RawConcentration_Main_Array, RawConcentration_Main_Array_min, RawConcentration_Main_Array_max, RawConcentration_Main_Array_mean, RawConcentration_Main_Array_stdDev);
				Undiluted_Sample_Array_10e7_Main_Array=Array.concat(Undiluted_Sample_Array_10e7_Main_Array,(non_diluted_ml/10000000));
				Array.getStatistics(Undiluted_Sample_Array_10e7_Main_Array, Undiluted_Sample_Array_10e7_Main_Array_min, Undiluted_Sample_Array_10e7_Main_Array_max, Undiluted_Sample_Array_10e7_Main_Array_mean, Undiluted_Sample_Array_10e7_Main_Array_stdDev);
				RawConcentration_Dilution_Array=Array.concat(RawConcentration_Dilution_Array,Concentration);
				Array.getStatistics(RawConcentration_Dilution_Array, RawConcentration_Dilution_Array_min, RawConcentration_Dilution_Array_max, RawConcentration_Dilution_Array_mean, RawConcentration_Dilution_Array_stdDev);
				Undiluted_Sample_Array_10e7_Dilution_Array=Array.concat(Undiluted_Sample_Array_10e7_Dilution_Array,(non_diluted_ml/10000000));
				Array.getStatistics(Undiluted_Sample_Array_10e7_Dilution_Array, Undiluted_Sample_Array_10e7_Dilution_Array_min, Undiluted_Sample_Array_10e7_Dilution_Array_max, Undiluted_Sample_Array_10e7_Dilution_Array_mean, Undiluted_Sample_Array_10e7_Dilution_Array_stdDev);	

				selectWindow("Summary.csv");
				Table.set("LineArray", SumInc, Line);
				Table.set("Nb of pictures analysed", SumInc, NbQuantifPerline);
				Table.set("Av.Count.", SumInc, Spore_Count_Main_Array_mean);
				Table.set("Std.Count", SumInc, Spore_Count_Main_Array_stdDev);
				Table.set("SEM.Count", SumInc, Spore_Count_Main_SEM);
				Table.set("spores/ul", SumInc, RawConcentration_Main_Array_mean);
				Table.set("Undil.Conc.(10^7/ml)", SumInc, Undiluted_Sample_Array_10e7_Main_Array_mean);
				Table.update;
    			saveAs("results", AnalysisDir+"Summary.csv");
    			    			
				/* setup Results table */
   			 	Table.showArrays("Counting_Results",TableIncArray,PicLineArray,Dilution_Array,imNumber_array,Spore_Count_Array,Undiluted_Sample_Array_10e7_Array,RawConcentration_Array,Analysed_Pic_Array,Dilution_Factor_Array,Undiluted_Sample_Array,ThresholdMethod_Array,ThresholdMin_Array,ThresholdMax_Array,MinSize_Array,MaxSize_Array,MinCirc_Array,MaxCirc_Array,Gaussian_Array,BlurNb_Array,OverlaySet_Array); 
//   			Table.setLocationAndSize((LiveDisplayWidth+230), 270, (ScrnWidth-(LiveDisplayWidth+230)), LivePicHeight);
				Table.setLocationAndSize((LiveDisplayWidth+230), ((ScrnHeight/6)*2), (ScrnWidth-(LiveDisplayWidth+230)), LivePicHeight);
		   	 	Table.renameColumn("PicLineArray", "Line");
   			 	Table.renameColumn("Dilution_Array", "Dil.");
   			 	Table.renameColumn("imNumber_array", "im."); 
   	 			Table.renameColumn("Spore_Count_Array", "Spores");
   	 			Table.renameColumn("Undiluted_Sample_Array_10e7_Array", "Undil.Spores(10^7/ml)");
   			 	Table.renameColumn("RawConcentration_Array", "Spores Conc.(sp/ul)");
    			Table.renameColumn("Dilution_Factor_Array", "Dil.Factor");
 			   	Table.renameColumn("Undiluted_Sample_Array", "Undil.Spores Conc.(sp/ul)");
   		 		Table.renameColumn("ThresholdMethod_Array", "Thresh. Method");
    			Table.renameColumn("ThresholdMin_Array", "Thresh. Min");
    			Table.renameColumn("ThresholdMax_Array", "Thresh. Max");
				Table.renameColumn("MinSize_Array","Min size");
				Table.renameColumn("MaxSize_Array","Max size");
				Table.renameColumn("MinCirc_Array","Min Circ.");
				Table.renameColumn("MaxCirc_Array","Max Circ.");
				Table.renameColumn("Gaussian_Array", "Gaussian Filter (pix)");
				Table.renameColumn("BlurNb_Array","BackG remov. blur (pix)");
				Table.renameColumn("OverlaySet_Array","Overlay Mode"); 
//				Table.renameColumn("Scale_Array","Scale (pix/um)");
				Table.sort("TableIncArray");
				Table.deleteColumn("TableIncArray");
    			Table.update;
    			saveAs("results", AnalysisDir+"Counting_Results.csv");
    			Table.rename("Counting_Results.csv", "Counting_Results");

    			
    			//setup Compact table 
    			if (SameLine==false){
    				selectWindow("Results Stats");
    				run("Close");
    				Table.create("Results Stats");
//    				Table.setLocationAndSize((LiveDisplayWidth+230), 0, (ScrnWidth-(LiveDisplayWidth+230)), (ScrnHeight/4));
					Table.setLocationAndSize((LiveDisplayWidth+230), (ScrnHeight/6), (ScrnWidth-(LiveDisplayWidth+230)), (ScrnHeight/6));		
    			}else {
    				selectWindow("Results Stats"); 
    			}		

				selectWindow("Results Stats"); 
				//Table.set(columnName, rowIndex, value);		
    			Table.set("Line", 0, Line);
    			Table.set("Dil.", 0, "All");
    			Table.set("#", 0, NbQuantifPerline);
    			Table.set("Av.Count", 0, Spore_Count_Main_Array_mean);
    			Table.set("Std.Count", 0, Spore_Count_Main_Array_stdDev);
    			Table.set("SEM.Count", 0,Spore_Count_Main_SEM);
    			Table.set("Conc.(spore/ul)", 0, RawConcentration_Main_Array_mean);
    			Table.set("Undil.Conc.(10^7/ml)", 0, Undiluted_Sample_Array_10e7_Main_Array_mean);
   
    			Table.set("Line", Dilution, Line);
    			Table.set("Dil.", Dilution, Dilution);
    			Table.set("#",Dilution, NbQuantifPerDilution);
    			Table.set("Av.Count", Dilution, Spore_Count_Dilution_Array_mean);
    			Table.set("Std.Count", Dilution, Spore_Count_Dilution_Array_stdDev);
    			Table.set("SEM.Count", Dilution,Spore_Count_Dilution_SEM);
    			Table.set("Conc.(spore/ul)", Dilution, RawConcentration_Dilution_Array_mean);
    			Table.set("Undil.Conc.(10^7/ml)", Dilution, Undiluted_Sample_Array_10e7_Dilution_Array_mean);
    			
    			Table.update ;
    			//updateResults();
    			TableName="stat_Results_"+Line+".csv";
    			saveAs("results", AnalysisDir+TableName);
    			Table.rename(TableName,"Results Stats"); //here
    			
    			
  		  	}
			else {
				NotAnalysed_Array=Array.concat(NotAnalysed_Array,CurrentPic);
				Array.show(NotAnalysed_Array);
				saveAs("results", AnalysisDir+"Non_Analysed.csv");
				close("Non_Analysed.csv");
			}
			}
		} // close if terminate is false
		else { //if terminate is true
				selectImage(LivePicID);
				close();
				print("Macro SporeCount Version "+Version+" Terminated");
				print("files saved in "+AnalysisDir+".");
		} //close else (if terminate is true)
	}//	close is open images contains"live" 
	else {// if is open images does not contains"live"
		setBatchMode(false);
		showStatus("Live feed missing - Live Restart procedure");
		doCommand("Live Macro")// test final
//		open("/Users/aljulien/Desktop/Macro/Cell count project/cecile_pic first/220225_S1_dil1_im3_2022-02-25.png"); //test remove
		rename("Live");// test remove
		
		OpenedImages=getList("image.titles");
		while (!contains(OpenedImages,"Live")){
			showStatus("!Live Restart procedure ."); wait(400);
			showStatus("!Live Restart procedure .."); wait(400);
			showStatus("!Live Restart procedure ..."); wait(400);
			showStatus("!Live Restart procedure ...."); wait(400);
			showStatus("!Live Restart procedure ....."); wait(400);
			OpenedImages=getList("image.titles"); 
		}	 
		LivePicID=getImageID();
		showStatus("!Macro running again");
		setBatchMode(true);
	} // close if is open images does not contains"live"
	OpenedImages=getList("image.titles"); 
}
