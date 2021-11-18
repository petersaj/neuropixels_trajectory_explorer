# Neuropixels trajectory explorer
Neuropixels trajectory explorer with the Allen CCF mouse atlas

## Requirements, setup, starting
- Allen CCF mouse atlas (download all files at http://data.cortexlab.net/allenCCF/)
(these are formatted versions of the atlas)

### If you have MATLAB
- NPY-matlab repository: https://github.com/kwikteam/npy-matlab
(this is code to load the formatted CCF atlas)

- Add the folders with the CCF atlas, the NPY-matlab repository, and this repository into the MATLAB path
(File > Set Path > Add with subfolders... > select the downloaded folder (have to do this for each folder separately), then hit 'Save' and 'Close')

- Run the command in MATLAB:
```matlab
neuropixels_trajectory_explorer
```

### If you don't have MATLAB
- Run neuropixels_trajectory_explorer_installer.exe (also installs MATLAB runtime environment)
- The first time the explorer is run, you will be prompted to select the folder where you installed the CCF atlas

## Instructions
