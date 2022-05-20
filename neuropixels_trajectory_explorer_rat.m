%% Neuropixels Trajector Explorer
% neuropixels_trajectory_explorer
% Andy Peters (peters.andrew.j@gmail.com)
%
% GUI for planning Neuropixels trajectories with the Allen CCF atlas
%
% Instructions for use: 
% https://github.com/petersaj/neuropixels_trajectory_explorer

%% GUI setup
function neuropixels_trajectory_explorer_rat

% Check MATLAB version
matlab_version = version('-date');
if str2num(matlab_version(end-3:end)) <= 2016
    error('Old MATLAB - allen_ccf_npx requires 2016 or later');
end

% Check for dependencies
% (npy-matlab to load in atlas)
if ~exist('readNPY','file')
   error('"npy-matlab" code not found, download here and add to matlab path: https://github.com/kwikteam/npy-matlab') 
end

% Initialize gui_data structure
gui_data = struct;

% ~~~~ Load atlas and associated data

% Load in atlas
% Find path with ratlas
atlas_path = fileparts(which('WHS_SD_rat_T2star_v1.01.nii.gz'));
if isempty(atlas_path)
    error('Rat atlas not in MATLAB path (click ''Set path'', add folder with CCF)');
end
% Load ratlas
tv = cast(rescale(permute(niftiread(fullfile(atlas_path,'WHS_SD_rat_T2star_v1.01.nii.gz')),[2,3,1]),0,255),'uint8');
av = permute(niftiread(fullfile(atlas_path,'WHS_SD_rat_atlas_v4.nii.gz')),[2,3,1]);

% (zero tv where av not defined)
tv(av == 0) = 0;

% Load labels (made from auto-generated script)
filename = 'C:\Users\Andrew\OneDrive for Business\Documents\Atlases\WHSrat\WHS_SD_rat_atlas_v4.label';
startRow = 15;
formatSpec = '%5f%6f%5f%5f%9f%3f%3f%s%[^\n\r]';
fileID = fopen(filename,'r');
dataArray = textscan(fileID, formatSpec, 'Delimiter', '', 'WhiteSpace', '', 'TextType', 'string', 'HeaderLines' ,startRow-1, 'ReturnOnError', false, 'EndOfLine', '\r\n');
dataArray{8} = strtrim(dataArray{8});
fclose(fileID);
st_raw = table(dataArray{1:end-1}, 'VariableNames', {'index','R','G','B','A','VIS','MSH','safe_name'});
st = table; 
st(st_raw.index(2:end),:) = st_raw(2:end,:);
clearvars filename startRow formatSpec fileID dataArray ans;

% Create colormap
ccf_cmap = [st.R,st.G,st.B]/255;


% ~~~~ Make transform matrix from CCF to bregma/mm coordinates
% This is in the coordinates pdf
bregma_ccf = [635,440,246]; % [AP,DV,ML]
ccf_translation_tform = eye(4)+[zeros(3,4);-bregma_ccf([3,1,2]),0];

% (scale voxel to mm)
voxel2mm = 0.039;
scale = voxel2mm./[-1,1,-1]; % [AP,ML,DV]
ccf_scale_tform = eye(4).*[scale,1]';

ccf_bregma_tform_matrix = ccf_translation_tform*ccf_scale_tform;
ccf_bregma_tform = affine3d(ccf_bregma_tform_matrix);

% ~~~~ Make GUI axes and objects

% Set up the gui
probe_atlas_gui = figure('Toolbar','none','Menubar','none','color','w', ...
    'Name','Neuropixels Trajectory Explorer (Rat)','Units','normalized','Position',[0.21,0.2,0.7,0.7]);

% Set up the atlas axes
axes_atlas = axes('Position',[-0.3,0.1,1.2,0.8],'ZDir','reverse');
axis(axes_atlas,'vis3d','equal','off','manual'); hold(axes_atlas,'on');

% Draw brain outline
slice_spacing = 5;
brain_volume = ...
    bwmorph3(bwmorph3(av(1:slice_spacing:end, ...
    1:slice_spacing:end,1:slice_spacing:end)>1,'majority'),'majority');

[ap_grid_ccf,dv_grid_ccf,ml_grid_ccf] = ...
    ndgrid(1:slice_spacing:size(av,1), ...
    1:slice_spacing:size(av,2), ...
    1:slice_spacing:size(av,3));

[ml_grid_bregma,ap_grid_bregma,dv_grid_bregma] = ...
    transformPointsForward(ccf_bregma_tform,ml_grid_ccf,ap_grid_ccf,dv_grid_ccf);

brain_outline_patchdata = reducepatch(isosurface(ml_grid_bregma,ap_grid_bregma, ...
    dv_grid_bregma,brain_volume,0.5),0.1);

brain_outline = patch( ...
        'Vertices',brain_outline_patchdata.vertices, ...
        'Faces',brain_outline_patchdata.faces, ...
        'FaceColor',[0.5,0.5,0.5],'EdgeColor','none','FaceAlpha',0.1);

view([30,150]);
caxis([1,size(ccf_cmap,1)]);

xlim(prctile(ml_grid_bregma(:),[0,100]));
ylim(prctile(ap_grid_bregma(:),[0,100]));
zlim(prctile(dv_grid_bregma(:),[0,100]));
grid on;

% Set up the probe reference/actual
probe_ref_top = [0,0,-0.1];
probe_ref_bottom = [0,0,prctile(dv_grid_bregma(:),100)];
probe_ref_vector = [probe_ref_top',probe_ref_bottom'];
probe_ref_line = line(probe_ref_vector(1,:),probe_ref_vector(2,:),probe_ref_vector(3,:), ...
    'linewidth',1.5,'color','r','linestyle','--');

probe_length = 3.840; % IMEC phase 3 (in mm)
probe_vector = [probe_ref_vector(:,1),diff(probe_ref_vector,[],2)./ ...
    norm(diff(probe_ref_vector,[],2))*probe_length + probe_ref_vector(:,1)];
probe_line = line(probe_vector(1,:),probe_vector(2,:),probe_vector(3,:), ...
    'linewidth',3,'color','b','linestyle','-');

% Set up the text to display coordinates
probe_coordinates_text = uicontrol('Style','text','String','', ...
    'Units','normalized','Position',[0,0.9,0.5,0.1], ...
    'BackgroundColor','w','HorizontalAlignment','left','FontSize',12);

% Set up the probe area axes
axes_probe_areas = axes('Position',[0.7,0.1,0.03,0.8]);
set(axes_probe_areas,'FontSize',11);
yyaxis(axes_probe_areas,'left');
probe_areas_plot = imagesc(0);
set(axes_probe_areas,'XTick','','YLim',[0,probe_length],'YColor','k','YDir','reverse');
ylabel(axes_probe_areas,'Depth (mm)');
yyaxis(axes_probe_areas,'right');
set(axes_probe_areas,'XTick','','YLim',[0,probe_length],'YColor','k','YDir','reverse');
title(axes_probe_areas,'Probe areas');

caxis(axes_probe_areas,[1,size(ccf_cmap,1)]);
colormap(axes_probe_areas,ccf_cmap);

% Store data
gui_data.tv = tv; % Intensity atlas
gui_data.av = av; % Annotated atlas
gui_data.st = st; % Labels table
gui_data.cmap = ccf_cmap; % Atlas colormap
gui_data.ccf_bregma_tform = ccf_bregma_tform;
gui_data.probe_length = probe_length; % Length of probe
gui_data.structure_plot_idx = []; % Plotted structures
gui_data.probe_angle = [0;90]; % Probe angles in ML/DV

%Store handles
gui_data.handles.cortex_outline = brain_outline;
gui_data.handles.structure_patch = []; % Plotted structures
gui_data.handles.axes_atlas = axes_atlas; % Axes with 3D atlas
gui_data.handles.axes_probe_areas = axes_probe_areas; % Axes with probe areas
gui_data.handles.slice_plot = surface(axes_atlas,'EdgeColor','none'); % Slice on 3D atlas
gui_data.handles.slice_volume = 'tv'; % The volume shown in the slice
gui_data.handles.probe_ref_line = probe_ref_line; % Probe reference line on 3D atlas
gui_data.handles.probe_line = probe_line; % Probe reference line on 3D atlas
gui_data.handles.probe_areas_plot = probe_areas_plot; % Color-coded probe regions
gui_data.probe_coordinates_text = probe_coordinates_text; % Probe coordinates text

% Make 3D rotation the default state (toggle on/off with 'r')
h = rotate3d(axes_atlas);
h.Enable = 'on';
% Update the slice whenever a rotation is completed
h.ActionPostCallback = @update_slice;

% Set functions for key presses
hManager = uigetmodemanager(probe_atlas_gui);
[hManager.WindowListenerHandles.Enabled] = deal(false);
set(probe_atlas_gui,'KeyPressFcn',@key_press);
set(probe_atlas_gui,'KeyReleaseFcn',@key_release);

% Upload gui_data
guidata(probe_atlas_gui, gui_data);

% Display the first slice and update the probe position
update_slice(probe_atlas_gui);
update_probe_coordinates(probe_atlas_gui);


%% Buttons

button_fontsize = 12;

%%% View angle buttons
view_button_position = [0,0,0.05,0.05];
clear view_button_h
view_button_h(1) = uicontrol('Parent',probe_atlas_gui,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',view_button_position,'String','Coronal','Callback',{@view_coronal,probe_atlas_gui});
view_button_h(end+1) = uicontrol('Parent',probe_atlas_gui,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',view_button_position,'String','Sagittal','Callback',{@view_sagittal,probe_atlas_gui});
view_button_h(end+1) = uicontrol('Parent',probe_atlas_gui,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',view_button_position,'String','Horizontal','Callback',{@view_horizontal,probe_atlas_gui});
align(view_button_h,'fixed',0.1,'middle');


%%% Control panel
control_panel = figure('Toolbar','none','Menubar','none','color','w', ...
    'Name','Controls','Units','normalized','Position',[0.09,0.2,0.11,0.7]);
button_position = [0.05,0.05,0.9,0.05];
header_text_position = [0.05,0.05,0.9,0.03];
clear controls_h

% (probe controls)
controls_h(1) = uicontrol('Parent',control_panel,'Style','text','FontSize',button_fontsize, ...
    'Units','normalized','Position',header_text_position,'String','Probe controls:', ...
    'BackgroundColor','w','FontWeight','bold');
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','text','FontSize',button_fontsize, ...
    'Units','normalized','Position',header_text_position,'String','Whole probe: arrow keys', ...
    'BackgroundColor','w');
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','text','FontSize',button_fontsize, ...
    'Units','normalized','Position',header_text_position,'String','Depth: alt+arrow keys', ...
    'BackgroundColor','w');
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','text','FontSize',button_fontsize, ...
    'Units','normalized','Position',header_text_position,'String','Probe tip: shift+arrow keys', ...
    'BackgroundColor','w');
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','text','FontSize',button_fontsize, ...
    'Units','normalized','Position',header_text_position,'String','(changes probe angle)', ...
    'BackgroundColor','w');
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Set entry','Callback',{@set_probe_entry,probe_atlas_gui});
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Set endpoint','Callback',{@set_probe_endpoint,probe_atlas_gui});

% (area selector)
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','text','FontSize',button_fontsize, ...
    'Units','normalized','Position',header_text_position,'String','3D areas:', ...
    'BackgroundColor','w','FontWeight','bold');
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','List areas','Callback',{@add_area_list,probe_atlas_gui});
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Search areas','Callback',{@add_area_search,probe_atlas_gui});
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Remove areas','Callback',{@remove_area,probe_atlas_gui});

% (visibility toggle)
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','text','FontSize',button_fontsize, ...
    'Units','normalized','Position',header_text_position,'String','Toggle visibility:', ...
    'BackgroundColor','w','FontWeight','bold');
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Slice','Callback',{@visibility_slice,probe_atlas_gui});
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Brain outline','Callback',{@visibility_brain_outline,probe_atlas_gui});
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Grid','Callback',{@visibility_grid,probe_atlas_gui});
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Probe','Callback',{@visibility_probe,probe_atlas_gui});
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','3D areas','Callback',{@visibility_3d_areas,probe_atlas_gui});
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Dark mode','Callback',{@visibility_darkmode,probe_atlas_gui});

% (other)
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','text','FontSize',button_fontsize, ...
    'Units','normalized','Position',header_text_position,'String','Other:', ...
    'BackgroundColor','w','FontWeight','bold');
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Export coordinates','Callback',{@export_coordinates,probe_atlas_gui});
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Load/plot histology','Callback',{@probe_histology,probe_atlas_gui});

set(controls_h(1),'Position',header_text_position+[0,0.9,0,0]);
align(fliplr(controls_h),'center','distribute');

% Set close functions for windows
set(probe_atlas_gui,'CloseRequestFcn',{@gui_close,probe_atlas_gui,control_panel});
set(control_panel,'CloseRequestFcn',{@gui_close,probe_atlas_gui,control_panel});
end

function gui_close(h,eventdata,probe_atlas_gui,control_panel)
% When closing either GUI or control panel, close both windows
delete(control_panel);
delete(probe_atlas_gui);
end

%% Probe controls and slice updating

function key_press(probe_atlas_gui,eventdata)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Set step size in millimeters
step_size = 0.1;

% Update probe coordinates
ap_offset = 0;
ml_offset = 0;
probe_offset = 0;
angle_change = [0;0];

switch eventdata.Key
    case 'uparrow'
        if isempty(eventdata.Modifier)
            ap_offset = step_size;
        elseif any(strcmp(eventdata.Modifier,'shift'))
            angle_change = [0;step_size];
        elseif any(strcmp(eventdata.Modifier,'alt'))
            probe_offset = -step_size;
        end
    case 'downarrow'
        if isempty(eventdata.Modifier)
            ap_offset = -step_size;
        elseif any(strcmp(eventdata.Modifier,'shift'))
            angle_change = [0;-step_size];
        elseif any(strcmp(eventdata.Modifier,'alt'))
            probe_offset = step_size;
        end
    case 'leftarrow'
        if isempty(eventdata.Modifier)
            ml_offset = -step_size;
        elseif any(strcmp(eventdata.Modifier,'shift'))
            angle_change = [-step_size;0];
        end
    case 'rightarrow'
        if isempty(eventdata.Modifier)
            ml_offset = step_size;
        elseif any(strcmp(eventdata.Modifier,'shift'))
            angle_change = [step_size;0];
        end
end

% Draw updated probe
if any([ap_offset,ml_offset,probe_offset])
    % (AP/ML)
    set(gui_data.handles.probe_ref_line,'XData',get(gui_data.handles.probe_ref_line,'XData') + ml_offset);
    set(gui_data.handles.probe_line,'XData',get(gui_data.handles.probe_line,'XData') + ml_offset);
    set(gui_data.handles.probe_ref_line,'YData',get(gui_data.handles.probe_ref_line,'YData') + ap_offset);
    set(gui_data.handles.probe_line,'YData',get(gui_data.handles.probe_line,'YData') + ap_offset);
    % (probe axis)
    old_probe_vector = cell2mat(get(gui_data.handles.probe_line,{'XData','YData','ZData'})');
    move_probe_vector = diff(old_probe_vector,[],2)./ ...
        norm(diff(old_probe_vector,[],2))*probe_offset;
    new_probe_vector = bsxfun(@plus,old_probe_vector,move_probe_vector);
    set(gui_data.handles.probe_line,'XData',new_probe_vector(1,:), ...
        'YData',new_probe_vector(2,:),'ZData',new_probe_vector(3,:));
end
% (angle)
if any(angle_change)
    gui_data = update_probe_angle(probe_atlas_gui,angle_change);
end

% Upload gui_data
guidata(probe_atlas_gui, gui_data);

end

function key_release(probe_atlas_gui,eventdata)

% Get guidata
gui_data = guidata(probe_atlas_gui);

switch eventdata.Key
    case {'rightarrow','leftarrow','uparrow','downarrow'}
        % Update the probe info/slice on arrow release 
        update_probe_coordinates(probe_atlas_gui);
        update_slice(probe_atlas_gui);
end

% Upload gui_data
guidata(probe_atlas_gui, gui_data);

end


function update_slice(probe_atlas_gui,varargin)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Only update the slice if it's visible
if strcmp(gui_data.handles.slice_plot(1).Visible,'on')
    
    % Get current position of camera
    curr_campos = campos(gui_data.handles.axes_atlas);
    
    % Get probe vector
    probe_ref_top = [gui_data.handles.probe_ref_line.XData(1), ...
        gui_data.handles.probe_ref_line.YData(1),gui_data.handles.probe_ref_line.ZData(1)];
    probe_ref_bottom = [gui_data.handles.probe_ref_line.XData(2), ...
        gui_data.handles.probe_ref_line.YData(2),gui_data.handles.probe_ref_line.ZData(2)];
    probe_vector = probe_ref_top - probe_ref_bottom;
    
    % Get probe-camera vector
    probe_camera_vector = probe_ref_top - curr_campos;
    
    % Get the vector to plot the plane in (along with probe vector)
    plot_vector = cross(probe_camera_vector,probe_vector);
    
    % Get the normal vector of the plane
    normal_vector = cross(plot_vector,probe_vector);
    
    % Get the plane offset through the probe
    plane_offset = -(normal_vector*probe_ref_top');
    
    % Define a plane of points to index
    % (the plane grid is defined based on the which cardinal plan is most
    % orthogonal to the plotted plane. this is janky but it works)
    ml_lim = xlim(gui_data.handles.axes_atlas);
    ap_lim = ylim(gui_data.handles.axes_atlas);
    dv_lim = zlim(gui_data.handles.axes_atlas);

    slice_px_space = 0.05; % resolution of slice to grab
    [~,cam_plane] = max(abs(normal_vector./norm(normal_vector)));
    switch cam_plane
        case 1
            [plane_ap_bregma,plane_dv_bregma] = ndgrid(...
                ap_lim(1):slice_px_space:ap_lim(2),...
                dv_lim(1):slice_px_space:dv_lim(2));
            plane_ml_bregma = ...
                (normal_vector(2)*plane_ap_bregma+normal_vector(3)*plane_dv_bregma + plane_offset)/ ...
                -normal_vector(1);

        case 2
            [plane_ml_bregma,plane_dv_bregma] = ndgrid(...
                ml_lim(1):slice_px_space:ml_lim(2),...
                dv_lim(1):slice_px_space:dv_lim(2));
            plane_ap_bregma = ...
                (normal_vector(3)*plane_dv_bregma+normal_vector(1)*plane_ml_bregma + plane_offset)/ ...
                -normal_vector(2);    
            
        case 3
            [plane_ml_bregma,plane_ap_bregma] = ndgrid(...
                ml_lim(1):slice_px_space:ml_lim(2),...
                ap_lim(1):slice_px_space:ap_lim(2));
            plane_dv_bregma = ...
                (normal_vector(2)*plane_ap_bregma+normal_vector(1)*plane_ml_bregma + plane_offset)/ ...
                -normal_vector(3);       
    end

    % Transform bregma coordinates to CCF coordinates
    [plane_ml_ccf,plane_ap_ccf,plane_dv_ccf] = ...
        transformPointsInverse(gui_data.ccf_bregma_tform,plane_ml_bregma,plane_ap_bregma,plane_dv_bregma);

    % Grab pixels from (selected) volume
    atlas_downsample = 3; % (downsample atlas to make this faster)
    switch gui_data.handles.slice_volume
        case 'tv'
            curr_slice = single(interpn( ...
                imresize3(gui_data.tv,1/atlas_downsample,'nearest'), ...
                plane_ap_ccf/atlas_downsample, ...
                plane_dv_ccf/atlas_downsample, ...
                plane_ml_ccf/atlas_downsample,'nearest'));
            curr_slice(curr_slice < 20) = NaN; % threshold values

            colormap(gui_data.handles.axes_atlas,'gray');
            caxis(gui_data.handles.axes_atlas,[0,255]);
        case 'av'
            curr_slice = single(interpn( ...
                imresize3(gui_data.av,1/atlas_downsample,'nearest'), ...
                plane_ap_ccf/atlas_downsample, ...
                plane_dv_ccf/atlas_downsample, ...
                plane_ml_ccf/atlas_downsample,'nearest'));
            curr_slice(curr_slice <= 1) = NaN;
            
            colormap(gui_data.handles.axes_atlas,gui_data.cmap);
            caxis(gui_data.handles.axes_atlas,[1,size(gui_data.cmap,1)]);
    end
   
    % Update the slice display
    set(gui_data.handles.slice_plot, ...
        'XData',plane_ml_bregma,'YData',plane_ap_bregma,'ZData',plane_dv_bregma,'CData',curr_slice);
    
    % Upload gui_data
    guidata(probe_atlas_gui, gui_data);
    
end

end


function set_probe_entry(h,eventdata,probe_atlas_gui)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Prompt for angles
prompt_text = { ...
    'AP position (mm from bregma)', ...
    'ML position (mm from bregma)', ...
    'Azimuth angle (relative to lambda -> bregma)', ....
    'Elevation angle (relative to horizontal)'};

new_probe_position_input = inputdlg(prompt_text,'Set probe position',1);
if any(cellfun(@isempty,new_probe_position_input))
   error('Not all coordinates entered'); 
end
new_probe_position = cellfun(@str2num,new_probe_position_input);

% Convert degrees to radians
probe_angle_rad = (new_probe_position(3:4)/360)*2*pi;

% Update the probe and trajectory reference
ml_lim = xlim(gui_data.handles.axes_atlas);
ap_lim = ylim(gui_data.handles.axes_atlas);
dv_lim = zlim(gui_data.handles.axes_atlas);
max_ref_length = norm([range(ap_lim);range(dv_lim);range(ml_lim)]);
[y,x,z] = sph2cart(pi-probe_angle_rad(1),pi-probe_angle_rad(2),max_ref_length);

% Get top of probe reference with user brain intersection point
% (get DV location of brain surface at chosen ML/AP point)
dv_query_bregma = interp1([0,1], ...
    [new_probe_position([2,1])',-1; ...
    new_probe_position([2,1])',6],linspace(0,1,100));
[ml_query_ccf,ap_query_ccf,dv_query_ccf] = ...
    transformPointsInverse(gui_data.ccf_bregma_tform, ...
    dv_query_bregma(:,1),dv_query_bregma(:,2),dv_query_bregma(:,3));

atlas_downsample = 5;
dv_ccf_line = interpn( ...
    imresize3(gui_data.av,1/atlas_downsample,'nearest'), ...
    ap_query_ccf/atlas_downsample, ...
    dv_query_ccf/atlas_downsample, ...
    ml_query_ccf/atlas_downsample,'nearest');
dv_brain_intersect_idx = find(dv_ccf_line > 1,1);

probe_brain_dv = dv_query_bregma(dv_brain_intersect_idx,3);

% (back up to 0 DV in CCF space)
probe_ref_top_ap = interp1(probe_brain_dv+[0,z],new_probe_position(1)+[0,y],0,'linear','extrap');
probe_ref_top_ml = interp1(probe_brain_dv+[0,z],new_probe_position(2)+[0,x],0,'linear','extrap');

% Set new probe position
probe_ref_top = [probe_ref_top_ml,probe_ref_top_ap,0];
probe_ref_bottom = probe_ref_top + [x,y,z];
probe_ref_vector = [probe_ref_top;probe_ref_bottom]';

set(gui_data.handles.probe_ref_line,'XData',probe_ref_vector(1,:), ...
    'YData',probe_ref_vector(2,:), ...
    'ZData',probe_ref_vector(3,:));

probe_vector = [probe_ref_vector(:,1),diff(probe_ref_vector,[],2)./ ...
    norm(diff(probe_ref_vector,[],2))*gui_data.probe_length + probe_ref_vector(:,1)];
set(gui_data.handles.probe_line,'XData',probe_vector(1,:), ...
    'YData',probe_vector(2,:),'ZData',probe_vector(3,:));

% Upload gui_data
gui_data.probe_angle = (probe_angle_rad/(2*pi))*360;
guidata(probe_atlas_gui, gui_data);

% Update the slice and probe coordinates
update_slice(probe_atlas_gui);
update_probe_coordinates(probe_atlas_gui);

end

function set_probe_endpoint(h,eventdata,probe_atlas_gui)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Prompt for angles
prompt_text = { ...
    'AP position (mm from bregma)', ...
    'ML position (mm from bregma)', ...
    'DV position (mm from bregma)', ...
    'Azimuth angle (relative to lambda -> bregma)', ....
    'Elevation angle (relative to horizontal)'};

new_probe_position_input = inputdlg(prompt_text,'Set probe position',1);
if any(cellfun(@isempty,new_probe_position_input))
   error('Not all coordinates entered'); 
end
new_probe_position = cellfun(@str2num,new_probe_position_input);

% Convert degrees to radians
probe_angle_rad = (new_probe_position(4:5)/360)*2*pi;

% Update the probe and trajectory reference
max_ref_length = norm([max(gui_data.ap_coords);max(gui_data.dv_coords);max(gui_data.ml_coords)]);
[y,x,z] = sph2cart(pi-probe_angle_rad(1),pi-probe_angle_rad(2),max_ref_length);

% Move probe reference (draw line through point and DV 0 with max length)
probe_ref_top_ap = interp1(new_probe_position(3)+[0,z],new_probe_position(1)+[0,y],0,'linear','extrap');
probe_ref_top_ml = interp1(new_probe_position(3)+[0,z],new_probe_position(2)+[0,x],0,'linear','extrap');

probe_ref_top = [probe_ref_top_ml,probe_ref_top_ap,0];
probe_ref_bottom = probe_ref_top + [x,y,z];
probe_ref_vector = [probe_ref_top;probe_ref_bottom]';

set(gui_data.handles.probe_ref_line,'XData',probe_ref_vector(1,:), ...
    'YData',probe_ref_vector(2,:), ...
    'ZData',probe_ref_vector(3,:));

% Move probe (lock endpoint, back up length of probe)
probe_vector = [diff(probe_ref_vector,[],2)./norm(diff(probe_ref_vector,[],2))* ...
    -gui_data.probe_length + new_probe_position([2,1,3]), ...
    new_probe_position([2,1,3])];
set(gui_data.handles.probe_line,'XData',probe_vector(1,:), ...
    'YData',probe_vector(2,:),'ZData',probe_vector(3,:));

% Upload gui_data
gui_data.probe_angle = (probe_angle_rad/(2*pi))*360;
guidata(probe_atlas_gui, gui_data);

% Update the slice and probe coordinates
update_slice(probe_atlas_gui);
update_probe_coordinates(probe_atlas_gui);

end


function gui_data = update_probe_angle(probe_atlas_gui,angle_change)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Get the positions of the probe and trajectory reference
probe_ref_vector = cell2mat(get(gui_data.handles.probe_ref_line,{'XData','YData','ZData'})');
probe_vector = cell2mat(get(gui_data.handles.probe_line,{'XData','YData','ZData'})');

% Update the probe trajectory reference angle

% % (Old, unused: spherical/manipulator coordinates)
% % Set new angle
% new_angle = gui_data.probe_angle + angle_change;
% gui_data.probe_angle = new_angle;
% 
% [ap_max,dv_max,ml_max] = size(gui_data.tv);
% 
% max_ref_length = sqrt(sum(([ap_max,dv_max,ml_max].^2)));
% 
% probe_angle_rad = (gui_data.probe_angle./360)*2*pi;
% [x,y,z] = sph2cart(pi-probe_angle_rad(1),probe_angle_rad(2),max_ref_length);
% 
% new_probe_ref_top = [probe_ref_vector(1,1),probe_ref_vector(2,1),0];
% new_probe_ref_bottom = new_probe_ref_top + [x,y,z];
% new_probe_ref_vector = [new_probe_ref_top;new_probe_ref_bottom]';

% (New: cartesian coordinates of the trajectory bottom)
new_probe_ref_vector = [probe_ref_vector(:,1), ...
    probe_ref_vector(:,2) + [angle_change;0]];

% (calculate angle with flipped x/y and -y to make zero be forward midline)
[probe_azimuth,probe_elevation] = cart2sph( ...
    diff(fliplr(-new_probe_ref_vector(2,:))), ...
    diff(fliplr(new_probe_ref_vector(1,:))), ...
    diff(fliplr(-new_probe_ref_vector(3,:))));
gui_data.probe_angle = [probe_azimuth,probe_elevation]*(360/(2*pi));

set(gui_data.handles.probe_ref_line,'XData',new_probe_ref_vector(1,:), ...
    'YData',new_probe_ref_vector(2,:), ...
    'ZData',new_probe_ref_vector(3,:));

% Update probe (retain depth)
new_probe_vector = [new_probe_ref_vector(:,1),diff(new_probe_ref_vector,[],2)./ ...
    norm(diff(new_probe_ref_vector,[],2))*gui_data.probe_length + new_probe_ref_vector(:,1)];

probe_depth = sqrt(sum((probe_ref_vector(:,1) - probe_vector(:,1)).^2));
new_probe_vector_depth = (diff(new_probe_vector,[],2)./ ...
    norm(diff(new_probe_vector,[],2))*probe_depth) + new_probe_vector;

set(gui_data.handles.probe_line,'XData',new_probe_vector_depth(1,:), ...
    'YData',new_probe_vector_depth(2,:),'ZData',new_probe_vector_depth(3,:));

% Upload gui_data
guidata(probe_atlas_gui, gui_data);

end


function update_probe_coordinates(probe_atlas_gui,varargin)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Get the positions of the probe and trajectory reference
probe_ref_vector = cell2mat(get(gui_data.handles.probe_ref_line,{'XData','YData','ZData'})');
probe_vector = cell2mat(get(gui_data.handles.probe_line,{'XData','YData','ZData'})');

trajectory_n_coords = max(abs(diff(probe_ref_vector,[],2)))*1000; % 1um resolution
[trajectory_ml_coords_bregma,trajectory_ap_coords_bregma,trajectory_dv_coords_bregma] = deal( ...
    linspace(probe_ref_vector(1,1),probe_ref_vector(1,2),trajectory_n_coords), ...
    linspace(probe_ref_vector(2,1),probe_ref_vector(2,2),trajectory_n_coords), ...
    linspace(probe_ref_vector(3,1),probe_ref_vector(3,2),trajectory_n_coords));

probe_n_coords = sqrt(sum(diff(probe_vector,[],2).^2))*1000; % 1um resolution along active sites
probe_coords_depth = linspace(0,gui_data.probe_length,probe_n_coords);
[probe_ml_coords_bregma,probe_ap_coords_bregma,probe_dv_coords_bregma] = deal( ...
    linspace(probe_vector(1,1),probe_vector(1,2),probe_n_coords), ...
    linspace(probe_vector(2,1),probe_vector(2,2),probe_n_coords), ...
    linspace(probe_vector(3,1),probe_vector(3,2),probe_n_coords));

% Transform bregma coordinates to CCF coordinates
[trajectory_ml_coords_ccf,trajectory_ap_coords_ccf,trajectory_dv_coords_ccf] = ...
    transformPointsInverse(gui_data.ccf_bregma_tform, ...
    trajectory_ml_coords_bregma,trajectory_ap_coords_bregma,trajectory_dv_coords_bregma);

[probe_ml_coords_ccf,probe_ap_coords_ccf,probe_dv_coords_ccf] = ...
    transformPointsInverse(gui_data.ccf_bregma_tform, ...
    probe_ml_coords_bregma,probe_ap_coords_bregma,probe_dv_coords_bregma);

% Get brain labels across the probe and trajectory, and intersection with brain
atlas_downsample = 3; % (downsample atlas to make this faster)
trajectory_areas = interpn( ...
    imresize3(gui_data.av,1/atlas_downsample,'nearest'), ...
    trajectory_ap_coords_ccf/atlas_downsample, ...
    trajectory_dv_coords_ccf/atlas_downsample, ...
    trajectory_ml_coords_ccf/atlas_downsample,'nearest');

trajectory_brain_idx = find(trajectory_areas > 1,1);
trajectory_brain_intersect = ...
    [trajectory_ml_coords_bregma(trajectory_brain_idx), ...
    trajectory_ap_coords_bregma(trajectory_brain_idx), ...
    trajectory_dv_coords_bregma(trajectory_brain_idx)]';

% (if the probe doesn't intersect the brain, don't update)
if isempty(trajectory_brain_intersect)
    return
end

probe_areas = interpn( ...
    imresize3(gui_data.av,1/atlas_downsample,'nearest'), ...
    probe_ap_coords_ccf/atlas_downsample, ...
    probe_dv_coords_ccf/atlas_downsample, ...
    probe_ml_coords_ccf/atlas_downsample,'nearest')';
probe_areas(probe_areas == 0) = 1; % set 0's (out of CCF) to 1's (non-brain)

probe_area_boundaries = intersect(unique([find(~isnan(probe_areas),1,'first'); ...
    find(diff(probe_areas) ~= 0);find(~isnan(probe_areas),1,'last')]),find(~isnan(probe_areas)));
probe_area_centers_idx = round(probe_area_boundaries(1:end-1) + diff(probe_area_boundaries)/2);
probe_area_centers = probe_coords_depth(probe_area_centers_idx);
probe_area_labels = gui_data.st.safe_name(probe_areas(probe_area_centers_idx));

% Get coordinate from bregma and probe-axis depth from surface
% (round to nearest 10 microns)
probe_bregma_coordinate = trajectory_brain_intersect(1:2);
probe_depth = norm(trajectory_brain_intersect - probe_vector(:,2));

% Update the text
probe_angle_text = sprintf('Probe angle: %.0f%c azimuth, %.0f%c elevation', ...
    gui_data.probe_angle(1),char(176),gui_data.probe_angle(2),char(176));
probe_insertion_text = sprintf('Probe insertion (mm from bregma): %.2f AP, %.2f ML, %.2f Probe-axis', ...
    probe_bregma_coordinate(2),probe_bregma_coordinate(1),probe_depth);
probe_endpoint_text = sprintf('(Probe endpoint (mm from bregma):  %.2f AP, %.2f ML, %.2f DV)', ...
    probe_vector(2,2),probe_vector(1,2),probe_vector(3,2));

probe_text = {probe_angle_text,probe_insertion_text,probe_endpoint_text};

set(gui_data.probe_coordinates_text,'String',probe_text);

% Update the probe areas
yyaxis(gui_data.handles.axes_probe_areas,'right');
set(gui_data.handles.probe_areas_plot,'YData',probe_coords_depth,'CData',probe_areas); 
set(gui_data.handles.axes_probe_areas,'YTick',probe_area_centers,'YTickLabels',probe_area_labels);

yyaxis(gui_data.handles.axes_probe_areas,'left');
caxis(gui_data.handles.axes_probe_areas,[1,size(gui_data.cmap,1)]);

% Upload gui_data
guidata(probe_atlas_gui, gui_data);

end

%% Button functions

function view_coronal(h,eventdata,probe_atlas_gui)
% Set coronal view
gui_data = guidata(probe_atlas_gui);
view(gui_data.handles.axes_atlas,[0,0]);
update_slice(probe_atlas_gui);
end

function view_sagittal(h,eventdata,probe_atlas_gui)
% Set sagittal view
gui_data = guidata(probe_atlas_gui);
view(gui_data.handles.axes_atlas,[-90,0]);
update_slice(probe_atlas_gui);
end

function view_horizontal(h,eventdata,probe_atlas_gui)
% Set horizontal view
gui_data = guidata(probe_atlas_gui);
view(gui_data.handles.axes_atlas,[0,90]);
update_slice(probe_atlas_gui);
end

function add_area_list(h,eventdata,probe_atlas_gui)
% List all CCF areas, draw selected

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Prompt for which structures to show (only structures which are
% labelled in the slice-spacing downsampled annotated volume)
slice_spacing = 10;
parsed_structures = setdiff(unique(reshape(gui_data.av(1:slice_spacing:end, ...
    1:slice_spacing:end,1:slice_spacing:end),[],1)),0);

plot_structure_parsed = listdlg('PromptString','Select a structure to plot:', ...
    'ListString',gui_data.st.safe_name(parsed_structures),'ListSize',[520,500], ...
    'SelectionMode','single');
plot_structure = parsed_structures(plot_structure_parsed);

% (change: show all structures even if not parsed to allow hierarchy)
plot_structure = listdlg('PromptString','Select a structure to plot:', ...
    'ListString',gui_data.st.safe_name,'ListSize',[520,500], ...
    'SelectionMode','single');

% Draw areas
draw_areas(probe_atlas_gui,slice_spacing,plot_structure);

end

function add_area_search(h,eventdata,probe_atlas_gui)
% Search all CCF areas, draw selected

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Prompt for which structures to show (only structures which are
% labelled in the slice-spacing downsampled annotated volume)
slice_spacing = 10;
parsed_structures = unique(reshape(gui_data.av(1:slice_spacing:end, ...
    1:slice_spacing:end,1:slice_spacing:end),[],1));

structure_search = lower(inputdlg('Search structures'));
structure_match = find(contains(lower(gui_data.st.safe_name),structure_search));
% list_structures = intersect(parsed_structures,structure_match);
% (change: show all structures even if not parsed to allow hierarchy)
list_structures = structure_match;

plot_structure_parsed = listdlg('PromptString','Select a structure to plot:', ...
    'ListString',gui_data.st.safe_name(list_structures),'ListSize',[520,500], ...
    'SelectionMode','single');
plot_structure = list_structures(plot_structure_parsed);

% Draw areas
draw_areas(probe_atlas_gui,slice_spacing,plot_structure);

end

function add_area_hierarchy(h,eventdata,probe_atlas_gui)
% Explore CCF hierarchy, draw selected

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Bring up hierarchical selector
plot_structure = hierarchical_select(gui_data.st);

% Draw areas
slice_spacing = 10;
draw_areas(probe_atlas_gui,slice_spacing,plot_structure);

end

function draw_areas(probe_atlas_gui,slice_spacing,plot_structure)

% Get guidata
gui_data = guidata(probe_atlas_gui);

if ~isempty(plot_structure)
    
    % Get all areas within and below the selected hierarchy level
    plot_ccf_idx = plot_structure;
    
    % Plot the structure
    atlas_downsample = 5; % (downsample atlas to make this faster)
    
    [ap_grid_ccf,dv_grid_ccf,ml_grid_ccf] = ...
        ndgrid(1:atlas_downsample:size(gui_data.av,1), ...
        1:atlas_downsample:size(gui_data.av,2), ...
        1:atlas_downsample:size(gui_data.av,3));

    [ml_grid_bregma,ap_grid_bregma,dv_grid_bregma] = ...
        transformPointsForward(gui_data.ccf_bregma_tform, ...
        ml_grid_ccf,ap_grid_ccf,dv_grid_ccf);

    structure_3d = isosurface(ml_grid_bregma,ap_grid_bregma,dv_grid_bregma, ...
        ismember(gui_data.av(1:atlas_downsample:end, ...
        1:atlas_downsample:end,1:atlas_downsample:end),plot_ccf_idx),0);
    
    structure_alpha = 0.2;
    plot_structure_color = ...
        [gui_data.st.R(plot_ccf_idx),gui_data.st.G(plot_ccf_idx),gui_data.st.B(plot_ccf_idx)]/255;

    gui_data.structure_plot_idx(end+1) = plot_structure;
    gui_data.handles.structure_patch(end+1) = patch(gui_data.handles.axes_atlas, ...
        'Vertices',structure_3d.vertices, ...
        'Faces',structure_3d.faces, ...
        'FaceColor',plot_structure_color,'EdgeColor','none','FaceAlpha',structure_alpha);
    
end

% Upload gui_data
guidata(probe_atlas_gui,gui_data);

end

function remove_area(h,eventdata,probe_atlas_gui)
% Remove previously drawn areas

% Get guidata
gui_data = guidata(probe_atlas_gui);

if ~isempty(gui_data.structure_plot_idx)
    remove_structures = listdlg('PromptString','Select a structure to remove:', ...
        'ListString',gui_data.st.safe_name(gui_data.structure_plot_idx));
    delete(gui_data.handles.structure_patch(remove_structures))
    gui_data.structure_plot_idx(remove_structures) = [];
    gui_data.handles.structure_patch(remove_structures) = [];
end

% Upload gui_data
guidata(probe_atlas_gui,gui_data);
end

function visibility_slice(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Toggle slice volume/visibility
slice_volumes = {'tv','av','none'};
new_slice_volume = slice_volumes{circshift( ...
    strcmp(gui_data.handles.slice_volume,slice_volumes),[0,1])};

if strcmp(new_slice_volume,'none')
    set(gui_data.handles.slice_plot,'Visible','off');
else
    set(gui_data.handles.slice_plot,'Visible','on');
end

gui_data.handles.slice_volume = new_slice_volume;
guidata(probe_atlas_gui, gui_data);

update_slice(probe_atlas_gui);

% Upload gui_data
guidata(probe_atlas_gui,gui_data);
end

function visibility_brain_outline(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Toggle brain outline visibility
current_visibility = gui_data.handles.cortex_outline.Visible;
switch current_visibility; case 'on'; new_visibility = 'off'; case 'off'; new_visibility = 'on'; end;
set(gui_data.handles.cortex_outline,'Visible',new_visibility);

% Upload gui_data
guidata(probe_atlas_gui,gui_data);
end

function visibility_grid(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Toggle grid
current_visibility = gui_data.handles.axes_atlas.Visible;
switch current_visibility; case 'on'; new_visibility = 'off'; case 'off'; new_visibility = 'on'; end;
set(gui_data.handles.axes_atlas,'Visible',new_visibility);

% Upload gui_data
guidata(probe_atlas_gui,gui_data);
end

function visibility_probe(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Toggle probe visibility
current_visibility = gui_data.handles.probe_ref_line.Visible;
switch current_visibility; case 'on'; new_visibility = 'off'; case 'off'; new_visibility = 'on'; end;
set(gui_data.handles.probe_ref_line,'Visible',new_visibility);
set(gui_data.handles.probe_line,'Visible',new_visibility);

% Upload gui_data
guidata(probe_atlas_gui,gui_data);
end

function visibility_3d_areas(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Toggle plotted structure visibility
if ~isempty(gui_data.structure_plot_idx)
    current_visibility = get(gui_data.handles.structure_patch(1),'Visible');
    switch current_visibility; case 'on'; new_visibility = 'off'; case 'off'; new_visibility = 'on'; end;
    set(gui_data.handles.structure_patch,'Visible',new_visibility);
end

% Upload gui_data
guidata(probe_atlas_gui,gui_data);
end

function visibility_darkmode(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Toggle dark mode
curr_bg = max(get(probe_atlas_gui,'color'));

switch curr_bg
    case 1
        new_bg_color = 'k';
        new_font_color = 'w';
    case 0
        new_bg_color = 'w';
        new_font_color = 'k';
end

% Set font colors
set(probe_atlas_gui,'color',new_bg_color)
yyaxis(gui_data.handles.axes_probe_areas,'left');
set(gui_data.handles.axes_probe_areas,'ycolor',new_font_color)
yyaxis(gui_data.handles.axes_probe_areas,'right');
set(gui_data.handles.axes_probe_areas,'ycolor',new_font_color)
set(gui_data.handles.axes_probe_areas.Title,'color',new_font_color)

% Upload gui_data
guidata(probe_atlas_gui,gui_data);
end

function export_coordinates(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Export the probe coordinates in Allen CCF to the workspace
probe_vector = cell2mat(get(gui_data.handles.probe_line,{'XData','YData','ZData'})');
probe_vector_ccf = round(probe_vector([1,3,2],:))';
assignin('base','probe_vector_ccf',probe_vector_ccf)
disp('Copied probe vector coordinates to workspace');
end

function probe_histology(h,eventdata,probe_atlas_gui)
% Load histology points
% UNDER CONSTRUCTION
% (used to use SHARP-Track, now using mine)

% Get guidata
gui_data = guidata(probe_atlas_gui);

[probe_file,probe_path] = uigetfile('*.mat','Choose probe coordinate file');
load([probe_path,probe_file]);

if exist('pointList','var')
    histology_points = pointList.pointList{1};
elseif exist('probe_ccf','var')
    histology_points = probe_ccf(1).points; % only use first probe
end

r0 = mean(histology_points,1);
xyz = bsxfun(@minus,histology_points,r0);
[~,~,V] = svd(xyz,0);
histology_probe_direction = V(:,1);

probe_eval_points = [-1000,1000];
probe_line_endpoints = bsxfun(@plus,bsxfun(@times,probe_eval_points',histology_probe_direction'),r0);

% Philip's GUI: not saved in native CCF order?
% plot3(histology_points(:,3),histology_points(:,1),histology_points(:,2),'.b','MarkerSize',20);
% line(P(:,3),P(:,1),P(:,2),'color','k','linewidth',2)

% % Mine: saved in native CCF order [AP,DV,ML]
plot3(gui_data.handles.axes_atlas, ...
    histology_points(:,1),histology_points(:,3),histology_points(:,2),'.b','MarkerSize',20);
line(gui_data.handles.axes_atlas, ...
    probe_line_endpoints(:,1),probe_line_endpoints(:,3),probe_line_endpoints(:,2),'color','k','linewidth',2)

% Place the probe on the histology best-fit axis
[ap_max,dv_max,ml_max] = size(gui_data.tv);

probe_ref_top = probe_line_endpoints(1,[1,3,2]);
probe_ref_bottom = probe_line_endpoints(2,[1,3,2]);
probe_ref_vector = [probe_ref_top;probe_ref_bottom]';

set(gui_data.handles.probe_ref_line,'XData',probe_ref_vector(1,:), ...
    'YData',probe_ref_vector(2,:), ...
    'ZData',probe_ref_vector(3,:));

probe_vector = [probe_ref_vector(:,1),diff(probe_ref_vector,[],2)./ ...
    norm(diff(probe_ref_vector,[],2))*gui_data.probe_length + probe_ref_vector(:,1)];
set(gui_data.handles.probe_line,'XData',probe_vector(1,:), ...
    'YData',probe_vector(2,:),'ZData',probe_vector(3,:));

% Upload gui_data
[theta,phi] = cart2sph(diff(probe_ref_vector(1,:)),diff(probe_ref_vector(2,:)),diff(probe_ref_vector(3,:)));
gui_data.probe_angle = ([theta,phi]/(2*pi))*360;
guidata(probe_atlas_gui, gui_data);

% Update the slice and probe coordinates
update_slice(probe_atlas_gui);
update_probe_coordinates(probe_atlas_gui);

end

%% Load and format structure tree
% (copied wholesale from cortex-lab/allenCCF/Browsing Functions/loadStructureTree to remove
% dependence)

function structureTreeTable = load_structure_tree(fn)

if nargin<1
    p = mfilename('fullpath');
    fn = fullfile(fileparts(fileparts(p)), 'structure_tree_safe_2017.csv');
end

[~, fnBase] = fileparts(fn);
if ~isempty(strfind(fnBase, '2017'))
    mode = '2017'; 
else
    mode = 'old'; 
end

fid = fopen(fn, 'r');

if strcmp(mode, 'old')
    titles = textscan(fid, '%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s', 1, 'delimiter', ',');
    titles = cellfun(@(x)x{1}, titles, 'uni', false);
    titles{1} = 'index'; % this is blank in the file
    
    data = textscan(fid, '%d%s%d%s%d%s%d%d%d%d%d%s%s%d%d%s%d%s%s%d%d', 'delimiter', ',');
    
elseif strcmp(mode, '2017')
    titles = textscan(fid, repmat('%s', 1, 21), 1, 'delimiter', ',');
    titles = cellfun(@(x)x{1}, titles, 'uni', false);
    
    data = textscan(fid, ['%d%d%s%s'... % 'id'    'atlas_id'    'name'    'acronym'
                          '%s%d%d%d'... % 'st_level'    'ontology_id'    'hemisphere_id'    'weight'
                          '%d%d%d%d'... % 'parent_structure_id'    'depth'    'graph_id'     'graph_order'
                          '%s%s%d%s'... % 'structure_id_path'    'color_hex_triplet' neuro_name_structure_id neuro_name_structure_id_path
                          '%s%d%d%d'... % 'failed'    'sphinx_id' structure_name_facet failed_facet
                          '%s'], 'delimiter', ','); % safe_name
    
    titles = ['index' titles];
    data = [[0:numel(data{1})-1]' data];    

end


structureTreeTable = table(data{:}, 'VariableNames', titles);

fclose(fid);

end

%% Hierarchy select dialog box
% (copied wholesale from cortex-lab/allenCCF/Browsing Functions/hierarchicalSelect to remove dependence)

function selIdx = hierarchical_select(st)

selID = 567; % Cerebrum, default to start

[boxList, idList] = makeBoxList(st, selID); 

ud.idList = idList; ud.st = st;

% make figure
f = figure; set(f, 'KeyPressFcn', @hierarchical_select_ok);

% selector box
ud.hBox = uicontrol(f, 'Style', 'listbox', 'String', boxList, ...
    'Callback', @hierarchical_select_update, 'Value', find(idList==selID),...
    'Units', 'normalized', 'Position', [0.1 0.2 0.8 0.7],...
    'KeyPressFcn', @hierarchical_select_ok); 

titleStr = boxList{idList==selID}; titleStr = titleStr(find(titleStr~=' ', 1):end);
ud.hSelTitle = uicontrol(f, 'Style', 'text', ...
    'String', sprintf('Selected: %s', titleStr), ...
    'Units', 'normalized', 'Position', [0.1 0.9 0.8 0.1]); 

ud.hCancel = uicontrol(f, 'Style', 'pushbutton', ...
    'String', 'Cancel', 'Callback', @hierarchical_select_cancel, ...
    'Units', 'normalized', 'Position', [0.1 0.1 0.2 0.1]); 

ud.hOK = uicontrol(f, 'Style', 'pushbutton', ...
    'String', 'OK', 'Callback', @hierarchical_select_ok, ...
    'Units', 'normalized', 'Position', [0.3 0.1 0.2 0.1]); 

set(f, 'UserData', ud);
drawnow;

uiwait(f);

if ishghandle(f)
    ud = get(f, 'UserData');
    idList = ud.idList;

    if ud.hBox.Value>1
        selID = idList(get(ud.hBox, 'Value'));

        selIdx = find(st.id==selID);
    else
        selIdx = [];
    end
    delete(f)
    drawnow; 
else
    selIdx = [];
end

end

function [boxList, idList] = makeBoxList(st, selID)

idList = selID;
while idList(end)~=997 % root
    idList(end+1) = st.parent_structure_id(st.id==idList(end));
end
idList = idList(end:-1:1); % this is the tree of parents down to the selected one

% make the parent string representation
for q = 1:numel(idList)
    boxList{q} = sprintf('%s%s (%s)', repmat('  ', 1, q-1), ...
        st.acronym{st.id==idList(q)}, ...
        st.safe_name{st.id==idList(q)});
end
np = numel(idList);

% now add children
idList = [idList st.id(st.parent_structure_id==selID)'];

% make the parent string representation
for q = np+1:numel(idList)
    boxList{q} = sprintf('%s%s (%s)', repmat('  ', 1, np), ...
        st.acronym{st.id==idList(q)}, ...
        st.safe_name{st.id==idList(q)});
end

end

function hierarchical_select_update(src, ~)

f = get(src, 'Parent'); 
ud = get(f, 'UserData');
st = ud.st; idList = ud.idList;

selID = idList(get(src, 'Value'));

[boxList, idList] = makeBoxList(st, selID); 

ud.idList = idList;
set(f, 'UserData', ud);
set(src, 'String', boxList, 'Value', find(idList==selID));

titleStr = boxList{idList==selID}; titleStr = titleStr(find(titleStr~=' ', 1):end);
set(ud.hSelTitle, 'String', sprintf('Selected: %s', titleStr));

end

% OK callback
function hierarchical_select_ok(~, ~)
    uiresume(gcbf);
end

% Cancel callback
function hierarchical_select_cancel(~, ~)
ud = get(gcbf, 'UserData');
ud.hBox.Value = 1;
uiresume(gcbf);
end









