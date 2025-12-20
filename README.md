# FS25_CourseplayGps
Courseplay GPS Extension
-
This is a Mod for Farming Simulator 25 allowing to use GPS tracking (automatic steering) based on Courseplay courses. 
In order to use this mod there is the need to have Courseplay (https://github.com/Courseplay/Courseplay_FS25) installed. 

Afterwards you can use Field courses to enable GPS tracking when driving tractors or harvesters. 
The motivation was to have the chance to smoothly swap between the CP helper and manual driving, but still using GPS tracking. 
The Giants automatic steering does come with own courses might causing an offset or different tracks than CoursePlay uses. 
In general does the CP course generator offer much more options to control the details of courses incl. the option to load and save them. 
An example is cutting the grass (10m working width) and afterwards picking it up by simply loading the same course.


How to use this mod:
- 
- Assign an activation key in the settings
- Generate or load a CP course
- As from this moment the you can activate the automatic steering when driving onto a field
- The system picks the closest way points and start to steer automatically

Features:
-
- Automatically follows the CP course
- Parameters to control the following features:
    - GPS tracking disabled (end of the row, end of the course, on connecting path or never)
    - Disable cruise control (end of the row, end of the course, on connecting path or never)
    - Remove Giants automatic steering courses when a CP course is loaded
    - Define the mode to show the path of the course
    - Time to hide the path after activating the automatic steering
    
Known / open issues / limitations:
-
- The system is foreseen for working on fields only.
- When keeping the steering at the end of the row active in order to drive a U-turn, the vehicle might have difficulties to follow the path at higher speeds.

Screenshot
-
<img src="Assets/Courseplay GPS Tracking On.png" style="width:100%; height:auto;" alt="Screenshot">