# Neuropixels trajectory explorer
Neuropixels trajectory explorer with the Allen CCF mouse atlas

**NOTE ON UPDATES:** The coordinates in this program will be updated in the (hopefully) near future following comparisons between the CCF and MRI data: this will likely include size, scaling, and rotation. 

**NOTE ON SCALING AND ROTATION:** The Allen CCF mouse atlas is slightly stretched in the DV axis compared to the average brain, and is currently scaled at 94.5%. This is provisional, and will be updated in the future based on CCF/MRI alignment. It is also estimated that the angle between bregma and lambda is >5 degrees in the CCF, this is not implemented yet but will be once it is more accurately estimated.

Any issues/bugs/suggestions, please open a github issue by clicking on the 'Issues' tab above and pressing the green 'New issue' button.

## Requirements, setup, starting
- Download the Allen CCF mouse atlas (all files at http://data.cortexlab.net/allenCCF/)

(note on where these files came from: they are a re-formatted version of [the original atlas](http://download.alleninstitute.org/informatics-archive/current-release/mouse_ccf/annotation/ccf_2017/), which has been [processed with this script](https://github.com/cortex-lab/allenCCF/blob/master/setup_utils.m))

- Download/clone this repository

### If you have MATLAB
- Download/clone the NPY-matlab repository: https://github.com/kwikteam/npy-matlab
(this is code to load the formatted CCF atlas)

- Add the folders with the CCF atlas, the NPY-matlab repository, and this repository into the MATLAB path
(File > Set Path > Add with subfolders... > select the downloaded folder (have to do this for each folder separately), then hit 'Save' and 'Close')

- Run the command in MATLAB:
```matlab
neuropixels_trajectory_explorer
```

### If you don't have MATLAB
- Run neuropixels_trajectory_explorer_installer.exe (also installs MATLAB runtime environment)
- The first time the explorer is run, you will be prompted to select the folder where you installed the CCF atlas. Navigate to the folder with the atlas and hit 'ok'.

## Instructions

A video demo of usage (from the [UCL Neuropixels 2021 course](https://www.ucl.ac.uk/neuropixels/training/2021-neuropixels-course) on a slightly older version) is here: https://www.youtube.com/watch?v=ZtiX0iunUTM

### Overview of interface
![image](https://github.com/petersaj/neuropixels_trajectory_explorer/blob/main/wiki/overview.PNG)

#### Control panel
- Probe controls: 
  - arrow keys (translate), SHIFT+arrow keys (rotate probe by moving bottom), ALT+arrow keys (depth along probe axis)
  - Enter coordinates: move probe to specific coordinates
- 3D areas: pick an area (through a comprehensive list, search, or hierarchy) to draw in 3D on the atlas
  - List areas: choose from list all areas in the CCF
  - Search areas: search CCF areas (e.g. search for "CA1" to find what the CCF calls "Field CA1")
  - Hierarchy areas: drill down to areas on the hierarchy, select structures at any level of the hierarchy (e.g. select all "primary visual cortex" instead of by layer like "primary visual cortex layer 1")
  - Remove areas: select previously drawn 3D areas to remove 
- Toggle visibility: turn on/off visibility ('Slice' switches between displaying anatomy, CCF-parsed regions, or nothing)
  - Slice: toggle brain slice between anatomy (greyscale), CCF regions (with CCF-assigned colors), or off
  - Brain outline: toggle brain outline visibility on/off
  - Probe: toggle probe visibility on/off
  - 3D areas: toggle 3D areas visibility on/off
  - Dark mode: toggle white/black font and background (can make some colors like yellow cerebellum easier to see)
- Other: in development, not currently in regular use

#### Atlas
The atlas can be rotated by clicking and dragging (the slice updates when the mouse is released). The probe can be moved with the arrow keys (+SHIFT: rotation, +ALT: depth).

#### Probe areas
These are the regions that the probe (blue line) is passing through


### Experimental use of Neuropixels coordinates
The coordinates of the probe are displayed above the atlas relative to **bregma (anterior/posterior and medial/lateral)** and the **brain surface (depth, axis along the probe)**

The angles of the manipulator are displayed as the **azimuth (polar) relative to the line from tail to nose, where 0 degrees means the probe is coming straight from behind the mouse**, and to the **elevation (pitch) relative to the horizontal, where 90 degrees means the probe is going straight downward**.

![image](https://github.com/petersaj/neuropixels_trajectory_explorer/blob/main/wiki/angles.png)


During the experiment:
- The manipulator angles should be set relative to the midline (azimuth/polar angle) and horizontal (pitch angle)
- The probe should be positioned over bregma and the AP/ML coordinates should be zeroed, then the probe should lightly touch the brain in the desired insertion spot and the probe-axis coordinate should be zeroed
- The probe should be lowered along the probe-axis until it reaches the desired probe-axis coordinate
