# SporeCounter
This project is design to automatically count spores in ImageJ/Fiji.
To run this macro you would needfirst to add the requiered JAR files to the "plugin" folder of Fiji. 
Then load and run the macro in Fiji.
This sript was only test on Window OS and does not work on MAC OS. 
This script only works if a USB camera is functional prior starting the macro.

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

Author: Julien Alassimone   
