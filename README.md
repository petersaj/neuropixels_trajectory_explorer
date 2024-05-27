[![DOI](https://zenodo.org/badge/429406115.svg)](https://zenodo.org/badge/latestdoi/429406115)

# Neuropixels trajectory explorer
Neuropixels trajectory explorer with the Allen CCF mouse atlas 

There is also a Waxholm rat atlas version available, though this is not actively maintained.

The program does not require any specific software. It was written and can be run from MATLAB, but included is a standalone version that does not require MATLAB to run.

**Features:**
  * Plan trajectories to target brain regions with one or more Neuropixels probes
  * Interface with New Scale manipulators to have a live visual of trajectories and recorded areas during an experiment
  * Display brain regions alongside data during recording (in Open Ephys or SpikeGLX)

**For a demo, see [this video](https://www.youtube.com/watch?v=54VHDqzowwY&ab_channel=MatteoCarandini) (part of the [2023 UCL Neuropixels Course](https://www.ucl.ac.uk/neuropixels/training/2023-neuropixels-course))**


**For instructions, see the [Wiki](https://github.com/petersaj/neuropixels_trajectory_explorer/wiki)**

**Atlas accuracy:** The Allen CCF atlas is not the size of the average mouse brain, and the tilt of the atlas does not match a leveled bregma and lambda (e.g. the anterior-posterior tilt that the Paxinos atlas uses). Scaling and tilt values have been approximated in the Neuropixels Trajectory Explorer and [documented on the wiki](https://github.com/petersaj/neuropixels_trajectory_explorer/wiki/CCF-stereotax-coordinate-conversion). Furthermore, the scaling of each mouse can be accounted for by the Trajectory Explorer.

Note that there are still likely to be **innacuracies in these values**, and work is currently being done improve this by 1) comparing planned to actual trajectories, and 2) aligning the CCF atlas to skull landmarks with MRI data. Specifically, there is still a discrepancy between the tilt angle between the adjusted CCF and Paxinos atlases. 

It would be helpful to know if any user finds systematic errors between planned and actual trajectories and has data to suggest better values - if so, please raise a github issue.

**Updates and issues:**
  * **Regularly pull new code:** try to use up-to-date code whenever possible, there are sometimes critical fixes/updates
  * Major changes are logged on the [Wiki change log page](https://github.com/petersaj/neuropixels_trajectory_explorer/wiki/Major-change-log)
  * Issues/bugs/suggestions: please open a github issue by clicking on the 'Issues' tab above and pressing the green 'New issue' button
  * Planned updates are marked as "future upgrades" on the issues page (https://github.com/petersaj/neuropixels_trajectory_explorer/issues). If you would like to be notified when a planned update is completed, click into the issue page for that update and hit "subscribe" in the lower right-hand corner

![](https://github.com/petersaj/neuropixels_trajectory_explorer/blob/main/wiki/front_image.png)
