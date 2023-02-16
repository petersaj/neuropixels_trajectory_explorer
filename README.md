[![DOI](https://zenodo.org/badge/429406115.svg)](https://zenodo.org/badge/latestdoi/429406115)

# Neuropixels trajectory explorer
Neuropixels trajectory explorer with the Allen CCF mouse atlas or Waxholm rat atlas. See changelog below for history of updates.

**Keep the GUI up-to-date:** there are semi-regular upgrades (sometimes just a feature, sometimes something critical like getting a better estimate of distances and angles), so make sure to pull the current repository whenever planning a new trajectory.

Mouse CCF scaling, rotation, and bregma notes:
* The CCF scaling is based on a single mouse. To approximate average scaling, the "Toronto MRI" transform is used: 1.031\*AP, 0.952\*ML, 0.885\*DV (based on [this data](https://www.nature.com/articles/s41467-018-04921-2), MRI-CCF fits by Steven J West from the IBL, configured as CCF transform by Dan Birman for [Pinpoint](https://github.com/VirtualBrainLab/Pinpoint))
* The CCF AP rotation is arbitrary with reference to the skull, this angle here is 5 degrees nose-down (as estimated in [this paper](https://www.biorxiv.org/content/10.1101/2022.05.09.491042v3)).
* Bregma has been approximated in AP by visually matching the Paxinos atlas slice at AP=0, the ML position is the midline, and the DV position (i.e. distance from brain surface to skull surface) is a very rough approximation from matching an MRI image.

Any issues/bugs/suggestions, please open a github issue by clicking on the 'Issues' tab above and pressing the green 'New issue' button.

## Requirements, setup, starting
- Mouse: download the Allen CCF mouse atlas (all files at http://data.cortexlab.net/allenCCF/)
(note on where these files came from: they are a re-formatted version of [the original atlas](http://download.alleninstitute.org/informatics-archive/current-release/mouse_ccf/annotation/ccf_2017/), which has been [processed with this script](https://github.com/cortex-lab/allenCCF/blob/master/setup_utils.m))

- Rat: download the Waxholm rat atlas and unzip (https://www.nitrc.org/projects/whs-sd-atlas/)

- Download/clone this repository

### If you have MATLAB
- Download/clone the NPY-matlab repository: https://github.com/kwikteam/npy-matlab
(this is code to load the formatted CCF atlas)

- Add to MATLAB path: the folders with the atlas, the NPY-matlab repository, and this repository
(File > Set Path > Add with subfolders... > select the downloaded folder (have to do this for each folder separately), then hit 'Save' and 'Close')

- Run the command in MATLAB:

Mouse:
```matlab
neuropixels_trajectory_explorer
```
Rat: 
```matlab
neuropixels_trajectory_explorer_rat
```

### If you don't have MATLAB
- Run neuropixels_trajectory_explorer_installer.exe (also installs MATLAB runtime environment)
- The first time the explorer is run, you will be prompted to select the folder where you installed the CCF atlas. Navigate to the folder with the atlas and hit 'ok'.

## Instructions

A video demo of usage (from the [UCL Neuropixels 2021 course](https://www.ucl.ac.uk/neuropixels/training/2021-neuropixels-course) on a slightly older version) is here: https://www.youtube.com/watch?v=ZtiX0iunUTM

### Overview of interface
![image](https://github.com/petersaj/neuropixels_trajectory_explorer/blob/main/wiki/overview.PNG)

#### Controls
Moving the probe: arrow keys
Insert/retract the probe: alt + arrow keys
Move probe tip independent from top (changes probe angle): shift + arrow keys
Select probe (if more than one): click on probe, selected is blue

Menu descriptions:
- **Probe controls**
  - Display controls: pop up box with probe controls
  - Set entry: move probe to specific entry coordinates
  - Set endpoint: move probe to specific endpoint coordinates (NOTE: this uses the roughly approximated bregma DV position)
  - Add probe: add a new probe
  - Remove probe: remove selected probe (unless only 1 probe)
- **Probe controls**
  - Set bregma-lambda distance: set to rescale brain (relative to standard average 4.1 mm)
- **3D areas**
  - List areas: choose from list all areas in the CCF
  - Search areas: search CCF areas (e.g. search for "CA1" to find what the CCF calls "Field CA1")
  - Hierarchy areas: pick CCF area by regional hierarchy
  - Remove areas: select previously drawn 3D areas to remove 
- **Display**
  - Region names: display full or abbreviated region names under "probe areas" plot
  - Slice: brain slice between anatomy (greyscale), CCF regions (with CCF-assigned colors), or off
  - Brain outline: brain outline visibility
  - Probe: probe visibility
  - 3D areas: 3D areas visibility
  - Dark mode: white or black background
- **Manipulator**
  - New Scale MPM: sync with New Scale MPM manipulator
  - Scientifica Patchstar: sync with Scientifica Patchstar manipulator

#### Atlas
The atlas can be rotated by clicking and dragging (the slice updates when the mouse is released). The probe can be moved with the arrow keys (+SHIFT: rotation, +ALT: depth).

#### Probe areas
These are the regions that the probe (blue line) is passing through

### Practical use of Neuropixels coordinates for experiments
The coordinates of the probe are displayed above the atlas relative to **bregma (anterior/posterior and medial/lateral)** and the **brain surface (depth, axis along the probe)**

![image](https://github.com/petersaj/neuropixels_trajectory_explorer/blob/main/wiki/positions.png)

The angles of the manipulator are displayed as the **azimuth (polar) relative to the line from tail to nose, where 0 degrees means the probe is coming straight from behind the mouse**, and to the **elevation (pitch) relative to the horizontal, where 90 degrees means the probe is going straight downward**.

![image](https://github.com/petersaj/neuropixels_trajectory_explorer/blob/main/wiki/angles.png)

During the experiment:
- Position the manipulator angles in azimuth/polar and elevation/pitch
- Position the probe tip over bregma and zero the AP/ML coordinates
- Move the probe tip until it's lightly touching the brain at the desired AP/ML coordinates
- Zero the depth coordinate (along the probe-axis), then descend until the desired depth is reached

## Manipulator interfacing
### New Scale Manipulators
Interfacing with New Scale MPM requires the "Pathfinder" software running the HTTP server (see documentation from New Scale). This is functional both in simulation mode and with physical manipulators.

To connect with Pathfinder, click Manipulator > New Scale MPM. This requires the New Scale client access DLL (NstMpmClientAccess.dll), and the user will have to give the location of that file the first time this connection is made.

In the dialog box that appears, enter the IP address and port for the Pathfinder HTTP server. If the same computer, IP is localhost, and the default port is 8080 (find this on Pathfinder by: Coordinate Sys > ... > Http server > Port)

Once connected, the probe positions in the trajectory explorer will synchronize with Pathfinder, and the text will turn from red to black when completed.

A new "Probe at brain surface" button will appear at the bottom of the "Probe areas" plot, used to set a DV offset to the probe:
![image](https://github.com/petersaj/neuropixels_trajectory_explorer/blob/main/wiki/newscale_buttons.png)

How to use this button: when the probe is touching the brain, press this button to zero the DV coordinate at the brain surface. This calibrates the Pathfinder coordinate relative to skull thickness, since otherwise the uncalibrated coordinates may have the probe over or under the brain when it is actually on the surface.

**Note on scaling:** based on the bregma-lambda distance in Pathfinder, the atlas automatically scales to the size of the individual mouse assuming an template average distance of 4.1mm 

Typical workflow: 
- Open Pathfinder (ensuring HTTP server is runnning) and Neuropixels Trajectory Explorer
- Connect Neuropixels Trajectory Explorer to Pathfinder (Manipulator > New Scale MPM)
- In Pathfinder: calibrate bregma then lambda with probe A, calibrate bregma on all other probes
- For each probe
  - Move to desired AP/ML position, adjust if necessary based on displayed trajectory to target region
  - Lower in DV until just touching brain 
  - Press "Probe at brain surface" button to set DV offset
  - Move probe into brain along the Z (direction of probe) axis, then insert to desired depth

## Major change log
- 2023-02-15: Moved controls to menu, added full New Scale MPM interfacing
- 2022-09-23: Changed CCF rotation to 5 degrees AP (clarification from IBL paper)
- 2022-07-20: Updated position readout for clarification
- 2022-05-20: Added rat trajectory explorer ('neuropixels_trajectory_explorer_rat')
- 2022-05-18: Changed coordinate system to allow for more flexible coordinate changes in future (including user-set scalings/rotations)
- 2022-05-17: Rotated CCF 7 degrees in AP to line up to a leveled bregma-lambda (angle from https://www.biorxiv.org/content/10.1101/2022.05.09.491042v3.full.pdf)
- 2021-12-15: Added 'set endpoint' functionality, approximated bregma DV (from MRI - very rough)


