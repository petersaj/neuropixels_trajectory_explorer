%% Neuropixels Trajector Explorer
% neuropixels_trajectory_explorer
% Andy Peters (peters.andrew.j@gmail.com)
%
% GUI for planning Neuropixels trajectories with the Allen CCF atlas
%
% Instructions for use:
% https://github.com/petersaj/neuropixels_trajectory_explorer

% TO DO 2.0 update: 
% - recording connection

function neuropixels_trajectory_explorer

%% Checks and initialize
% Check MATLAB version
matlab_version = version('-date');
if str2num(matlab_version(end-3:end)) <= 2016
    error('Neuropixels Trajectory Explorer requires MATLAB 2016 or later');
end

% Check for dependencies
% (npy-matlab to load in atlas)
if ~exist('readNPY','file')
    error('"npy-matlab" code not found, download here and add to matlab path: https://github.com/kwikteam/npy-matlab')
end
if ~license('test','Statistics_Toolbox')
    error('MATLAB statistics toolbox required (https://uk.mathworks.com/products/statistics.html)')
end
if ~license('test','Image_Toolbox')
    error('MATLAB image processing toolbox required (https://uk.mathworks.com/products/image.html)')
end

% Initialize gui_data structure
gui_data = struct;

%% Load atlas and associated data

% Load in atlas
% Find path with CCF
if ~isdeployed
    % (if being run in matlab: find CCF in the matlab path)
    allen_atlas_path = fileparts(which('template_volume_10um.npy'));
    if isempty(allen_atlas_path)
        error('CCF atlas not in MATLAB path (click ''Set path'', add folder with CCF)');
    end
elseif isdeployed
    % (if being run standalone: use previous user-supplied path, or query if files not available)
    load('nte_paths.mat')
    allen_atlas_path = nte_paths.allen_atlas_path;

    if isempty(allen_atlas_path)
        % (use uigetdir_workaround: matlab-issued workaround for R2018a bug)
        allen_atlas_path = uigetdir_workaround([],'Select folder with Allen CCF');
        tv_fn = [allen_atlas_path filesep 'template_volume_10um.npy'];
        av_fn = [allen_atlas_path filesep 'annotation_volume_10um_by_index.npy'];
        st_fn = [allen_atlas_path filesep 'structure_tree_safe_2017.csv'];

        tv_exist = exist(tv_fn,'file');
        av_exist = exist(av_fn,'file');
        st_exist = exist(st_fn,'file');

        ccf_files = {tv_fn,av_fn,st_fn};
        ccf_exist = [tv_exist,av_exist,st_exist];
        if any(~ccf_exist)
            % If CCF not present in specified directory, error out
            errordlg([{'Allen CCF files not found: '}, ...
                ccf_files(~ccf_exist)],'Allen CCF not found');
            return
        else
            % If all CCF files present, save path for future
            nte_paths.allen_atlas_path = allen_atlas_path;
            nte_paths_fn = which('nte_paths.mat');
            save(nte_paths_fn,'nte_paths');
        end
    end
end

% Load CCF components
tv = readNPY([allen_atlas_path filesep 'template_volume_10um.npy']); % grey-scale "background signal intensity"
av = readNPY([allen_atlas_path filesep 'annotation_volume_10um_by_index.npy']); % the number at each pixel labels the area, see note below
st = load_structure_tree([allen_atlas_path filesep 'structure_tree_safe_2017.csv']); % a table of what all the labels mean

% Create CCF colormap
% (copied from cortex-lab/allenCCF/setup_utils
ccf_color_hex = st.color_hex_triplet;
ccf_color_hex(cellfun(@numel,ccf_color_hex)==5) = {'019399'}; % special case where leading zero was evidently dropped
ccf_cmap_c1 = cellfun(@(x)hex2dec(x(1:2)), ccf_color_hex, 'uni', false);
ccf_cmap_c2 = cellfun(@(x)hex2dec(x(3:4)), ccf_color_hex, 'uni', false);
ccf_cmap_c3 = cellfun(@(x)hex2dec(x(5:6)), ccf_color_hex, 'uni', false);
ccf_cmap = horzcat(vertcat(ccf_cmap_c1{:}),vertcat(ccf_cmap_c2{:}),vertcat(ccf_cmap_c3{:}))./255;

%% Make transform matrix from CCF to bregma/mm coordinates

% Set average stereotaxic bregma-lambda distance, set initial scale to 1
bregma_lambda_distance_avg = 4.1; % Currently approximation

% (translation values from our bregma estimate: AP/ML from Paxinos, DV from
% rough MRI estimate)
bregma_ccf = [570.5,520,44]; % [ML,AP,DV]
ccf_translation_tform = eye(4)+[zeros(3,4);-bregma_ccf,0];

% (scaling "Toronto MRI transform", reflect AP/ML, convert 10um to 1mm)
scale = [0.952,-1.031,0.885]./100; % [ML,AP,DV]
ccf_scale_tform = eye(4).*[scale,1]';

% (rotation values from IBL estimate)
ap_rotation = 5; % tilt the CCF 5 degrees nose-up
ccf_rotation_tform = ...
    [1 0 0 0; ...
    0 cosd(ap_rotation) -sind(ap_rotation) 0; ...
    0 sind(ap_rotation) cosd(ap_rotation) 0; ...
    0 0 0 1];

ccf_bregma_tform_matrix = ccf_translation_tform*ccf_scale_tform*ccf_rotation_tform;
ccf_bregma_tform = affine3d(ccf_bregma_tform_matrix);

%% Make GUI axes and objects

% Set up the gui
screen_size_px = get(0,'screensize');
gui_aspect_ratio = 1.7; % width/length
gui_width_fraction = 0.6; % fraction of screen width to occupy
gui_width_px = screen_size_px(3).*gui_width_fraction;
gui_position = [...
    (screen_size_px(3)-gui_width_px)/2, ... % left x
    (screen_size_px(4)-gui_width_px/gui_aspect_ratio)/2, ... % bottom y
    gui_width_px,gui_width_px/gui_aspect_ratio]; % width, height

probe_atlas_gui = figure('Toolbar','none','Menubar','none','color','w', ...
    'Name','Neuropixels Trajectory Explorer', ...
    'Units','pixels','Position',gui_position, ...
    'CloseRequestFcn',{@gui_close});

% Set up the atlas axes
axes_atlas = axes('Position',[-0.08,0.05,1,0.9],'ZDir','reverse');
axis(axes_atlas,'vis3d','equal','off','manual'); hold(axes_atlas,'on');

view([30,150]);
caxis([0 300]);
xlim([-5,5]);ylim([-8,6]);zlim([-1,6.5]);
grid_spacing = 0.5;
set(gca,'XTick',floor(min(xlim)):grid_spacing:ceil(max(xlim)));
set(gca,'YTick',floor(min(ylim)):grid_spacing:ceil(max(ylim)));
set(gca,'ZTick',floor(min(zlim)):grid_spacing:ceil(max(zlim)));
grid on;

% Set up the text to display coordinates
gui_position_px = getpixelposition(probe_atlas_gui);
probe_coordinates_text = annotation('textbox','String','No probe selected', ...
    'Units','normalized','Position',[0,0,1,1],'VerticalAlignment','top', ...
    'FontSize',12,'FontName','Consolas','PickableParts','none');

% Set up the probe area axes
axes_probe_areas = axes('Position',[0.80,0.01,0.15,0.95],'TickDir','in');
axes_probe_areas.ActivePositionProperty = 'position';
probe_areas_plot = image(axes_probe_areas,[0,1],0,0);
axes_probe_areas_probelimits = ...
    rectangle(axes_probe_areas, ...
    'position',[min(xlim(axes_probe_areas)),0,0,0], ...
    'edgecolor','b','linewidth',5);

set(axes_probe_areas,'FontSize',12);
set(axes_probe_areas,'XTick','','YColor','k','YDir','reverse');
ylabel(axes_probe_areas,'Depth (mm)');
axes_probe_areas.YAxisLocation = 'right';
title(axes_probe_areas,'Probe areas');


%% Create menu/buttons

probe_controls_menu = uimenu(probe_atlas_gui,'Text','Probe controls');
uimenu(probe_controls_menu,'Text','Display controls','MenuSelectedFcn',{@popup_controls,probe_atlas_gui});
uimenu(probe_controls_menu,'Text','Add probe','MenuSelectedFcn',{@probe_add,probe_atlas_gui});
uimenu(probe_controls_menu,'Text','Remove selected probe','MenuSelectedFcn',{@probe_remove,probe_atlas_gui});
uimenu(probe_controls_menu,'Text','Set entry','MenuSelectedFcn',{@set_probe_entry,probe_atlas_gui});
uimenu(probe_controls_menu,'Text','Set endpoint','MenuSelectedFcn',{@set_probe_endpoint,probe_atlas_gui});

scaling_menu = uimenu(probe_atlas_gui,'Text','Brain scaling');
uimenu(scaling_menu,'Text','Set bregma-lambda distance','MenuSelectedFcn',{@set_bregma_lambda_distance,probe_atlas_gui});

mesh_areas_menu = uimenu(probe_atlas_gui,'Text','3D areas');
uimenu(mesh_areas_menu,'Text','List areas','MenuSelectedFcn',{@add_area_list,probe_atlas_gui});
uimenu(mesh_areas_menu,'Text','Search areas','MenuSelectedFcn',{@add_area_search,probe_atlas_gui});
uimenu(mesh_areas_menu,'Text','Hierarchy areas','MenuSelectedFcn',{@add_area_hierarchy,probe_atlas_gui});
uimenu(mesh_areas_menu,'Text','Remove areas','MenuSelectedFcn',{@remove_area,probe_atlas_gui});

display_menu = uimenu(probe_atlas_gui,'Text','Display');
name_menu = uimenu(display_menu,'Text','Trajectory areas');
uimenu(name_menu,'Text','Probe position','MenuSelectedFcn',{@set_areas_probe,probe_atlas_gui},'Checked','on')
uimenu(name_menu,'Text','Full trajectory','MenuSelectedFcn',{@set_areas_trajectory,probe_atlas_gui},'Checked','off')
name_menu = uimenu(display_menu,'Text','Region names');
uimenu(name_menu,'Text','Acronym','MenuSelectedFcn',{@set_name_acronym,probe_atlas_gui},'Checked','on')
uimenu(name_menu,'Text','Full','MenuSelectedFcn',{@set_name_full,probe_atlas_gui})
slice_menu = uimenu(display_menu,'Text','Slice');
uimenu(slice_menu,'Text','Anatomical','MenuSelectedFcn',{@visibility_tv_slice,probe_atlas_gui},'Checked','off')
uimenu(slice_menu,'Text','Annotated','MenuSelectedFcn',{@visibility_av_slice,probe_atlas_gui})
object_menu = uimenu(display_menu,'Text','Objects');
uimenu(object_menu,'Text','Brain outline','MenuSelectedFcn',{@visibility_brain_outline,probe_atlas_gui},'Checked','on');
uimenu(object_menu,'Text','Grid','MenuSelectedFcn',{@visibility_grid,probe_atlas_gui});
uimenu(object_menu,'Text','Probe','MenuSelectedFcn',{@visibility_probe,probe_atlas_gui},'Checked','on');
uimenu(object_menu,'Text','3D areas','MenuSelectedFcn',{@visibility_3d_areas,probe_atlas_gui},'Checked','on');
uimenu(object_menu,'Text','Dark mode','MenuSelectedFcn',{@visibility_darkmode,probe_atlas_gui});

connect_menu = uimenu(probe_atlas_gui,'Text','Connect');
manipulator_menu = uimenu(connect_menu,'Text','Manipulator');
uimenu(manipulator_menu,'Text','New Scale MPM','MenuSelectedFcn',{@connect_newscale,probe_atlas_gui});
uimenu(manipulator_menu,'Text','Scientifica Patchstar','MenuSelectedFcn',{@connect_scientifica,probe_atlas_gui});
record_menu = uimenu(connect_menu,'Text','Recording');
uimenu(record_menu,'Text','OpenEphys','MenuSelectedFcn',{@connect_openephys,probe_atlas_gui});
uimenu(record_menu,'Text','SpikeGLX','MenuSelectedFcn',{@connect_spikeglx,probe_atlas_gui});
uimenu(record_menu,'Text','Set recording slot','MenuSelectedFcn',{@set_probe_recording_slot,probe_atlas_gui});

saveload_menu = uimenu(probe_atlas_gui,'Text','Save/Load');
uimenu(saveload_menu,'Text','Save positions','MenuSelectedFcn',{@save_probe_positions,probe_atlas_gui});
uimenu(saveload_menu,'Text','Load positions','MenuSelectedFcn',{@load_probe_positions,probe_atlas_gui});


%%% Buttons
button_fontsize = 12;

% View angle buttons
button_position = [0,0,0.1,0.05];
view_button_h(1) = uicontrol('Parent',probe_atlas_gui,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Coronal','Callback',{@view_coronal,probe_atlas_gui});
view_button_h(end+1) = uicontrol('Parent',probe_atlas_gui,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Sagittal','Callback',{@view_sagittal,probe_atlas_gui});
view_button_h(end+1) = uicontrol('Parent',probe_atlas_gui,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Horizontal','Callback',{@view_horizontal,probe_atlas_gui});
align(view_button_h,'fixed',0.1,'middle');


%% Store initial GUI data
gui_data.tv = tv; % Intensity atlas
gui_data.av = av; % Annotated atlas
gui_data.st = st; % Labels table
gui_data.bregma_lambda_distance_avg = bregma_lambda_distance_avg; % Average bregma-lambda distance
gui_data.bregma_lambda_distance_curr = bregma_lambda_distance_avg; % Set current as average
gui_data.cmap = ccf_cmap; % Atlas colormap
gui_data.ccf_bregma_tform_ref = ccf_bregma_tform; % Reference CCF-bregma transform
gui_data.ccf_bregma_tform = ccf_bregma_tform; % CCF-bregma transform to use
gui_data.structure_plot_idx = []; % Plotted structures

% Store handles
gui_data.handles.structure_patch = []; % Plotted structures
gui_data.handles.axes_atlas = axes_atlas; % Axes with 3D atlas
gui_data.handles.axes_probe_areas = axes_probe_areas; % Axes with probe areas
gui_data.handles.axes_probe_areas_probelimits = axes_probe_areas_probelimits; % Probe location on area plot
gui_data.handles.probe_areas_plot = probe_areas_plot; % Color-coded probe regions
gui_data.handles.slice_plot = surface(axes_atlas,'EdgeColor','none','Visible','off'); % Slice on 3D atlas
gui_data.handles.slice_volume = 'tv'; % The volume shown in the slice
gui_data.probe_coordinates_text = probe_coordinates_text; % Probe coordinates text

% Make 3D rotation the default state
h = rotate3d(axes_atlas);
h.Enable = 'on';
h.ButtonDownFilter = @rotate_clickable; % enable click-to-select during rotation
% Update the slice whenever a rotation is completed
h.ActionPostCallback = @update_slice;

% Set functions for key presses
hManager = uigetmodemanager(probe_atlas_gui);
[hManager.WindowListenerHandles.Enabled] = deal(false);
set(probe_atlas_gui,'KeyPressFcn',@key_press);
set(probe_atlas_gui,'KeyReleaseFcn',@key_release);

% Upload gui_data
guidata(probe_atlas_gui, gui_data);

% Draw brain outline
draw_brain(probe_atlas_gui);

end

function gui_close(probe_atlas_gui,eventdata)
% When closing gui, make sure all timers are ended

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Find all timers derived by the gui
if ~isdeployed
    % (only necessary if running from matlab)
    curr_timers = timerfindall;
    if ~isempty(curr_timers)
        gui_timers_idx = cellfun(@(x) x{2} == probe_atlas_gui,{curr_timers(:).TimerFcn});
        stop(curr_timers(gui_timers_idx));
        delete(curr_timers(gui_timers_idx));
    end
end

% Close the gui
delete(probe_atlas_gui);

end

%% Probe controls and slice/brain updating

function key_press(probe_atlas_gui,eventdata)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% If no probes are selected, do nothing
if ~isfield(gui_data,'selected_probe') || isempty(gui_data.selected_probe)
    return
end

% Step sizes
step_size_position = 0.1; % position, mm
step_size_rotation = 10; % angle, deg

% Update probe coordinates
ap_offset = 0;
ml_offset = 0;
angle_ap_offset = 0;
angle_ml_offset = 0;

update_probe_flag = false;

switch eventdata.Key
    case 'uparrow'
        if isempty(eventdata.Modifier)
            ap_offset = step_size_position;
        elseif any(strcmp(eventdata.Modifier,'shift'))
            angle_ap_offset = step_size_position;
        elseif any(strcmp(eventdata.Modifier,'alt'))
            gui_data.probe(gui_data.selected_probe).dv = ...
                gui_data.probe(gui_data.selected_probe).dv - step_size_position;
            update_probe_flag = true;
            guidata(probe_atlas_gui,gui_data);
        end
    case 'downarrow'
        if isempty(eventdata.Modifier)
            ap_offset = -step_size_position;
        elseif any(strcmp(eventdata.Modifier,'shift'))
            angle_ap_offset = -step_size_position;
        elseif any(strcmp(eventdata.Modifier,'alt'))
            gui_data.probe(gui_data.selected_probe).dv = ...
                gui_data.probe(gui_data.selected_probe).dv + step_size_position;
            update_probe_flag = true;
            guidata(probe_atlas_gui,gui_data);
        end
    case 'leftarrow'
        if isempty(eventdata.Modifier)
            ml_offset = -step_size_position;
        elseif any(strcmp(eventdata.Modifier,'shift'))
            angle_ml_offset = -step_size_position;
        elseif any(strcmp(eventdata.Modifier,'control'))
            gui_data.probe(gui_data.selected_probe).angle = ...
                mod(gui_data.probe(gui_data.selected_probe).angle + ...
                [0;0;step_size_rotation],360);
            update_probe_flag = true;
        end
    case 'rightarrow'
        if isempty(eventdata.Modifier)
            ml_offset = step_size_position;
        elseif any(strcmp(eventdata.Modifier,'shift'))
            angle_ml_offset = step_size_position;
        elseif any(strcmp(eventdata.Modifier,'control'))
            gui_data.probe(gui_data.selected_probe).angle = ...
                mod(gui_data.probe(gui_data.selected_probe).angle + ...
                [0;0;-step_size_rotation],360);
            update_probe_flag = true;
        end
end

% Draw updated trajectory
old_trajectory_vector = get(gui_data.probe(gui_data.selected_probe).trajectory,{'XData','YData'});

set(gui_data.probe(gui_data.selected_probe).trajectory,'XData', ...
    old_trajectory_vector{1} + repmat(ml_offset,1,2) + [0,angle_ml_offset]);
set(gui_data.probe(gui_data.selected_probe).trajectory,'YData', ...
    old_trajectory_vector{2} + repmat(ap_offset,1,2) + [0,angle_ap_offset]);

% Update position (only if insertion point doesn't change)
if update_probe_flag
    update_probe_position(probe_atlas_gui);
end

% Upload gui_data
guidata(probe_atlas_gui, gui_data);

end

function key_release(probe_atlas_gui,eventdata)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% If no probes are selected, do nothing
if ~isfield(gui_data,'selected_probe') || isempty(gui_data.selected_probe)
    return
end

% On any key release: update the probe coordinates/position and slice
update_probe_position(probe_atlas_gui);
update_probe_areas_coordinates(probe_atlas_gui);
update_slice(probe_atlas_gui);

end


function update_slice(probe_atlas_gui,varargin)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Only update the slice if it's visible
if strcmp(gui_data.handles.slice_plot(1).Visible,'on')

    % Get trajectory and probe location
    trajectory_position = cell2mat(get( ...
        gui_data.probe(gui_data.selected_probe).trajectory, ...
        {'XData','YData','ZData'})')';

    probe_position = permute(cell2mat(permute(get( ...
        gui_data.probe(gui_data.selected_probe).line, ...
        {'XData','YData','ZData'}),[1,3,2])),[2,3,1]);

    if size(probe_position,3) > 1
        % If multiple shanks: use vector across shank points
        plot_vector = diff(permute(probe_position(1,:,[1,end]),[3,2,1]));
    else
        % Otherwise: use plane perpendicular to camera viewpoint

        % Get current position of camera
        curr_campos = campos(gui_data.handles.axes_atlas);

        % Get trajectory-camera vector
        trajectory_camera_vector = trajectory_position(1,:) - curr_campos;

        % Get the vector to plot the plane in (along with probe vector)
        plot_vector = cross(trajectory_camera_vector,probe_position(1,:));
    end

    % Get the normal vector of the plane
    normal_vector = cross(plot_vector,diff(trajectory_position));

    % Get the plane offset through the probe
    plane_offset = -(normal_vector*trajectory_position(1,:)');

    % Define a plane of points to index
    % (the plane grid is defined based on the which cardinal plan is most
    % orthogonal to the plotted plane. this is janky but it works)
    ml_lim = xlim(gui_data.handles.axes_atlas);
    ap_lim = ylim(gui_data.handles.axes_atlas);
    dv_lim = zlim(gui_data.handles.axes_atlas);

    slice_px_space = 0.03; % resolution of slice to grab
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
    plane_coords = ...
        round([plane_ap_ccf(:),plane_dv_ccf(:),plane_ml_ccf(:)]);
    plane_coords_inbounds = all(plane_coords > 0 & ...
        plane_coords <= size(gui_data.tv),2);

    plane_idx = sub2ind(size(gui_data.tv), ...
        plane_coords(plane_coords_inbounds,1), ...
        plane_coords(plane_coords_inbounds,2), ...
        plane_coords(plane_coords_inbounds,3));

    switch gui_data.handles.slice_volume
        case 'tv'
            curr_slice = nan(size(plane_ap_ccf));
            curr_slice(plane_coords_inbounds) = gui_data.tv(plane_idx);
            curr_slice(curr_slice < 20) = NaN; % threshold values

            colormap(gui_data.handles.axes_atlas,'gray');
            caxis(gui_data.handles.axes_atlas,[0,255]);

        case 'av'
            curr_slice = nan(size(plane_ap_ccf));
            curr_slice(plane_coords_inbounds) = gui_data.av(plane_idx);
            curr_slice(curr_slice <= 1) = NaN; % threshold values

            curr_slice(boundarymask(max(curr_slice,0),4)) = 0;

            colormap(gui_data.handles.axes_atlas,gui_data.cmap);
            caxis(gui_data.handles.axes_atlas,[1,size(gui_data.cmap,1)]);
    end

    % Update the slice display
    set(gui_data.handles.slice_plot, ...
        'XData',plane_ml_bregma,'YData',plane_ap_bregma,'ZData',plane_dv_bregma,'CData',curr_slice);

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
    'Elevation angle (relative to horizontal)', ...
    'Rotation angle'};

new_probe_position_input = inputdlg(prompt_text,'Set probe position',1);
if any(cellfun(@isempty,new_probe_position_input))
    error('Not all coordinates entered');
end
new_probe_position = cellfun(@str2num,new_probe_position_input);

% Convert degrees to radians
probe_angle = new_probe_position(3:5);

% Update the probe and trajectory reference
ml_lim = xlim(gui_data.handles.axes_atlas);
ap_lim = ylim(gui_data.handles.axes_atlas);
dv_lim = zlim(gui_data.handles.axes_atlas);
max_ref_length = norm([range(ap_lim);range(dv_lim);range(ml_lim)]);
[x,y,z] = sph2cart( ...
    deg2rad(90-probe_angle(1)),  ...
    deg2rad(180+probe_angle(2)), ...
    -max_ref_length);

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
trajectory_vector = [probe_ref_top;probe_ref_bottom]';

set(gui_data.probe(gui_data.selected_probe).trajectory, ...
    'XData',trajectory_vector(1,:), ...
    'YData',trajectory_vector(2,:), ...
    'ZData',trajectory_vector(3,:));

% Upload gui_data
gui_data.probe(gui_data.selected_probe).angle = probe_angle;
guidata(probe_atlas_gui, gui_data);

% Update probe and slice
update_probe_position(probe_atlas_gui);
update_probe_areas_coordinates(probe_atlas_gui);
update_slice(probe_atlas_gui);

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
    'Elevation angle (relative to horizontal)', ...
    'Rotation angle'};

new_probe_position_input = inputdlg(prompt_text,'Set probe position',1);
if any(cellfun(@isempty,new_probe_position_input))
    error('Not all coordinates entered');
end
new_probe_position = cellfun(@str2num,new_probe_position_input);

probe_angle = new_probe_position(4:6);

% Convert degrees to radians
probe_angle_rad = deg2rad(probe_angle(1:2));

% Update the probe and trajectory reference
ml_lim = xlim(gui_data.handles.axes_atlas);
ap_lim = ylim(gui_data.handles.axes_atlas);
dv_lim = zlim(gui_data.handles.axes_atlas);
max_ref_length = norm([range(ap_lim);range(dv_lim);range(ml_lim)]);
[y,x,z] = sph2cart(pi+probe_angle_rad(1),pi-probe_angle_rad(2),max_ref_length);

% Move probe reference (draw line through point and DV 0 with max length)
probe_ref_top_ap = interp1(new_probe_position(3)+[0,z],new_probe_position(1)+[0,y],0,'linear','extrap');
probe_ref_top_ml = interp1(new_probe_position(3)+[0,z],new_probe_position(2)+[0,x],0,'linear','extrap');

probe_ref_top = [probe_ref_top_ml,probe_ref_top_ap,0];
probe_ref_bottom = probe_ref_top + [x,y,z];
trajectory_vector = [probe_ref_top;probe_ref_bottom]';

set(gui_data.probe(gui_data.selected_probe).trajectory, ...
    'XData',trajectory_vector(1,:), ...
    'YData',trajectory_vector(2,:), ...
    'ZData',trajectory_vector(3,:));

% Upload gui_data
gui_data.probe(gui_data.selected_probe).angle = probe_angle;
guidata(probe_atlas_gui, gui_data);

% Update probe and slice
update_probe_position(probe_atlas_gui);
update_probe_areas_coordinates(probe_atlas_gui);
update_slice(probe_atlas_gui);

end


function gui_data = update_probe_position(probe_atlas_gui)
% Update the probe position position relative to trajectory vector angles,
% stored rotation angle, and stored DV position

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Get the trajectory angle
trajectory_vector = cell2mat( ...
    get(gui_data.probe(gui_data.selected_probe).trajectory, ...
    {'XData','YData','ZData'})');

[trajectory_azimuth_sph,trajectory_elevation_sph] = cart2sph( ...
    diff(trajectory_vector(1,:)), ...
    diff(trajectory_vector(2,:)), ...
    diff(trajectory_vector(3,:)));

% Get probe shank coordinates relative to rotation
probe_rotation_rad = deg2rad(gui_data.probe(gui_data.selected_probe).angle(3));
probe_angle_rad = [probe_rotation_rad, ...
    pi/2-trajectory_elevation_sph, ...
    trajectory_azimuth_sph+pi/2];

% Create rotation transform matricies
R_shank = [cos(probe_angle_rad(1)) -sin(probe_angle_rad(1)) 0; sin(probe_angle_rad(1)) cos(probe_angle_rad(1)) 0; 0 0 1];
R_elevation = [1 0 0; 0 cos(probe_angle_rad(2)) -sin(probe_angle_rad(2)); 0 sin(probe_angle_rad(2)) cos(probe_angle_rad(2))];
R_azimuth = [cos(probe_angle_rad(3)) -sin(probe_angle_rad(3)) 0; sin(probe_angle_rad(3)) cos(probe_angle_rad(3)) 0; 0 0 1];
R_probe = R_azimuth*R_elevation*R_shank;

% Rotate and translate default shanks to follow trajectory
shank_translate = trajectory_vector(:,1); % (move to trajectory top)
shank_ref_vec = gui_data.probe(gui_data.selected_probe).reference_vector;
shank_ref_vec_flat = reshape(permute(shank_ref_vec,[3,1,2]),3,[]);
shank_vector_flat = R_probe*shank_ref_vec_flat + shank_translate;
shank_vector = permute(reshape(shank_vector_flat,3,2,[]),[2 3 1]);

% Get current probe (reference shank) DV position
ref_shank = gui_data.probe(gui_data.selected_probe).ref_shank;
dv_target = gui_data.probe(gui_data.selected_probe).dv;

dv_ref = shank_vector(:,ref_shank,3);
new_probe_position = reshape(interp1(dv_ref, ...
    reshape(shank_vector,2,[]), ...
    dv_target-[diff(dv_ref),0],'linear','extrap'),size(shank_vector));

% Update shank line positions
for curr_shank = 1:size(shank_vector,2)
    gui_data.probe(gui_data.selected_probe).line(curr_shank).XData = new_probe_position(:,curr_shank,1);
    gui_data.probe(gui_data.selected_probe).line(curr_shank).YData = new_probe_position(:,curr_shank,2);
    gui_data.probe(gui_data.selected_probe).line(curr_shank).ZData = new_probe_position(:,curr_shank,3);
end

% Update probe angles
gui_data.probe(gui_data.selected_probe).angle(1:2) = ...
    mod(rad2deg([-trajectory_azimuth_sph,trajectory_elevation_sph]) + ...
    [90,0],360);

% Upload gui_data
guidata(probe_atlas_gui, gui_data);

end

function update_probe_areas_coordinates(probe_atlas_gui,varargin)
% Update the areas and coordinates for the current probe position

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Get current probe location
probe_vector = permute(cell2mat(permute(get( ...
    gui_data.probe(gui_data.selected_probe).line, ...
    {'XData','YData','ZData'}),[1,3,2])),[2,3,1]);

n_shanks = size(probe_vector,3);

% Interpolate to extremes of probe range
ml_lim = xlim(gui_data.handles.axes_atlas);
ap_lim = ylim(gui_data.handles.axes_atlas);
dv_lim = zlim(gui_data.handles.axes_atlas);
max_ref_length = norm([range(ap_lim);range(dv_lim);range(ml_lim)]);

sample_points = (-max_ref_length:0.001:max_ref_length)';
probe_sample_points_bregma = reshape( ...
    interp1([0,gui_data.probe(gui_data.selected_probe).length], ...
    reshape(probe_vector,2,[]), ...
    sample_points,'linear','extrap'), ...
    [length(sample_points),size(probe_vector,[2,3])]);

probe_sample_points_ccf_flat = ...
    round(transformPointsInverse(gui_data.ccf_bregma_tform, ...
    reshape(permute(probe_sample_points_bregma,[1,3,2]),[],3)));

inbounds_idx = all(probe_sample_points_ccf_flat > 0 & ...
    probe_sample_points_ccf_flat <= size(gui_data.av,[3,1,2]),2);

probe_sample_ccf_idx = ...
    sub2ind(size(gui_data.av), ...
    probe_sample_points_ccf_flat(inbounds_idx,2), ...
    probe_sample_points_ccf_flat(inbounds_idx,3), ...
    probe_sample_points_ccf_flat(inbounds_idx,1));

probe_areas = ones(length(sample_points),n_shanks);
probe_areas(inbounds_idx) = gui_data.av(probe_sample_ccf_idx);

% Only plot areas that have index >1 (in-brain)
plot_probe_areas_idx = find(any(probe_areas > 1,2));
probe_areas_plot = probe_areas(plot_probe_areas_idx,:);

% Get insertion coordinate
ref_shank = gui_data.probe(gui_data.selected_probe).ref_shank;
insertion_point = probe_sample_points_bregma( ...
    plot_probe_areas_idx(find(probe_areas_plot(:,ref_shank) > 1,1,'first')),:,ref_shank);

if isempty(insertion_point)
    % (don't update if there isn't an insertion point)
    set(gui_data.probe_coordinates_text,'String','Probe trajectory is outside brain');
    return
end

% Get current depth of probe relative to insertion coordinate
probe_depth = pdist2(insertion_point,probe_vector(2,:,ref_shank));

% Get area depths relative to insertion coordinate
probe_areas_plot_depth = pdist2(insertion_point, ...
    probe_sample_points_bregma(plot_probe_areas_idx,:,ref_shank))';

% Get colors for all areas (draw white lines between areas)
probe_areas_hexcolors = gui_data.st.color_hex_triplet(probe_areas_plot);
probe_areas_rgbcolors = cell2mat(cellfun(@(x) ...
    permute(hex2dec({x(1:2),x(3:4),x(5:6)})'./255,[1,3,2]), ...
    probe_areas_hexcolors,'uni',false));
for curr_shank = 1:n_shanks
    probe_areas_rgbcolors(imdilate(boundarymask( ...
        probe_areas_plot(:,curr_shank)),ones(20,1)),curr_shank,:) = 1;
end

% Get boundaries, centers, and labels for all areas
if ~isfield(gui_data,'display_region_name')
    gui_data.display_region_name = 'acronym';
end

probe_area_boundaries = cell(n_shanks,1);
probe_area_centers = cell(n_shanks,1);
probe_area_labels = cell(n_shanks,1);
for curr_shank = 1:n_shanks

    shank_areas_plot = probe_areas_plot(:,curr_shank);
    shank_areas_boundaries_idx = intersect(unique( ...
        [find(shank_areas_plot ~= 1,1,'first'); ...
        find(diff(shank_areas_plot) ~= 0); ...
        find(shank_areas_plot ~= 1,1,'last')]), ...
        find(shank_areas_plot ~= 1));
    shank_areas_centers_idx = round(shank_areas_boundaries_idx(1:end-1) + ...
        diff(shank_areas_boundaries_idx)/2);

    probe_area_boundaries{curr_shank} = ...
        probe_areas_plot_depth(shank_areas_boundaries_idx);
    probe_area_centers{curr_shank} = ...
        probe_areas_plot_depth(shank_areas_centers_idx);
    probe_area_labels{curr_shank} = ...
        gui_data.st.(gui_data.display_region_name)(probe_areas_plot(shank_areas_centers_idx,curr_shank));

end

% Update area plot and labels
set(gui_data.handles.axes_probe_areas, ...
    'YTick',floor(probe_areas_plot_depth(1)):0.5: ...
    ceil(probe_areas_plot_depth(end)));
set(gui_data.handles.probe_areas_plot, ...
    'XData',1:n_shanks, ...
    'YData',probe_areas_plot_depth, ...
    'CData',probe_areas_rgbcolors);

probe_area_shank = cellfun(@(x,shank) ones(length(x),1).*shank, ...
    probe_area_centers,num2cell(1:n_shanks)','uni',false);

delete(findobj(gui_data.handles.axes_probe_areas,'Type','text'));
text_h = text(gui_data.handles.axes_probe_areas, ...
    vertcat(probe_area_shank{:}), ...
    vertcat(probe_area_centers{:}),vertcat(probe_area_labels{:}), ...
    'FontSize',12,'HorizontalAlignment','center','clipping','on');
switch gui_data.display_region_name
    case 'acronym'
        set(text_h,'clipping','on')
    case 'safe_name'
        set(text_h,'clipping','off')
end

% Update probe insertion point
[gui_data.probe(gui_data.selected_probe).insertion_point.XData, ...
    gui_data.probe(gui_data.selected_probe).insertion_point.YData, ...
    gui_data.probe(gui_data.selected_probe).insertion_point.ZData] = ...
    deal(insertion_point(1),insertion_point(2),insertion_point(3));

% Update area plot (user-selected zoom as probe or full trajectory)
probe_depth_limits = probe_depth - ...
    [gui_data.probe(gui_data.selected_probe).length,0];

gui_data.handles.axes_probe_areas_probelimits.Position = ...
    [0.5,probe_depth_limits(1),n_shanks,diff(probe_depth_limits)];

if ~isfield(gui_data,'display_areas')
    gui_data.display_areas = 'probe';
end
axis(gui_data.handles.axes_probe_areas,'tight');
switch gui_data.display_areas
    case 'probe'
        % Set limits to probe, turn off probe box
        ylim(gui_data.handles.axes_probe_areas,probe_depth_limits)
        gui_data.handles.axes_probe_areas_probelimits.Visible = 'off';
        title(gui_data.handles.axes_probe_areas,'Probe areas');
    case 'trajectory'
        % Set limits to whole trajectory, turn off probe box
        ylim(gui_data.handles.axes_probe_areas,prctile(probe_areas_plot_depth,[0,100]));
        gui_data.handles.axes_probe_areas_probelimits.Visible = 'on';
        title(gui_data.handles.axes_probe_areas,'Trajectory areas');
end

% Update the text
% (manipulator angles)
probe_angle_text = sprintf('Probe angle:      %.0f%c azimuth, %.0f%cV/%.0f%cH elevation, %.0f%c rotation', ...
    gui_data.probe(gui_data.selected_probe).angle(1),char(176), ...
    gui_data.probe(gui_data.selected_probe).angle(2),char(176), ...
    90-gui_data.probe(gui_data.selected_probe).angle(2),char(176), ...
    gui_data.probe(gui_data.selected_probe).angle(3),char(176));
% (probe insertion point and depth)
probe_insertion_text = sprintf('Probe insertion: % .2f AP, % .2f ML, % .2f depth', ...
    insertion_point(2),insertion_point(1),probe_depth);
% (probe tip)
probe_tip_text = sprintf('Probe tip:       % .2f AP, % .2f ML, % .2f DV', ...
    probe_vector(2,[2,1,3],ref_shank));
% (bregma-lambda distance for scaling)
bregma_lambda_text = sprintf('Bregma-Lambda distance: % .2f mm', ...
    gui_data.bregma_lambda_distance_curr);
% (connection status)
manipulator_text = [];
recording_text = [];
if isfield(gui_data,'connection')
    if isfield(gui_data.connection,'manipulator')
        manipulator_text = sprintf('Connected manipulator: %s', ...
            gui_data.connection.manipulator.model);
    end
    if isfield(gui_data.connection,'recording')
        recording_text = sprintf('Connected recording: %s', ...
            gui_data.connection.recording.software);
    end
end

% (combine and update)
probe_text = {probe_angle_text,probe_insertion_text, ...
    probe_tip_text,bregma_lambda_text, ...
    manipulator_text,recording_text};
set(gui_data.probe_coordinates_text,'String',probe_text(cellfun(@(x) ~isempty(x),probe_text)));

% If recording software is connected, send areas for display
if isfield(gui_data,'connection') && ...
        isfield(gui_data.connection,'recording')

    send_recording_areas(gui_data, ...
        probe_depths, ...
        trajectory_area_boundaries, ...
        trajectory_area_labels, ...
        trajectory_area_hexcolors(trajectory_area_centers_idx));
end

% Upload gui_data
guidata(probe_atlas_gui, gui_data);

end


function update_brain_scale(probe_atlas_gui,bregma_lambda_distance)
% Update the scaling of the brain based on the bregma-lambda distance

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Add "rescaling" message
set(gui_data.probe_coordinates_text,'String','RESCALING BRAIN...');
set(gui_data.probe_coordinates_text,'Color','r');
drawnow;

% Get the sizing scale of this mouse to the reference atlas
mouse_scale = bregma_lambda_distance/ ...
    gui_data.bregma_lambda_distance_avg;

% Apply scale to reference transform and set to new transform
mouse_scale_tform = eye(4).*[repmat(mouse_scale,3,1);1];
gui_data.ccf_bregma_tform.T = gui_data.ccf_bregma_tform_ref.T*mouse_scale_tform;

% Update current bregma-lambda distance
gui_data.bregma_lambda_distance_curr = bregma_lambda_distance;

% Upload gui_data
guidata(probe_atlas_gui, gui_data);

% Redraw to new scale:
% - Brain outline
draw_brain(probe_atlas_gui);
% - 3D areas
for redraw_area = gui_data.structure_plot_idx
    draw_areas(probe_atlas_gui,redraw_area)
end
% - Slice
update_slice(probe_atlas_gui);

% Update probe coordinates
update_probe_areas_coordinates(probe_atlas_gui);

% Restore text color
set(gui_data.probe_coordinates_text,'Color','k')

end


%% Control functions

function view_coronal(h,eventdata,probe_atlas_gui)
% Set coronal view
gui_data = guidata(probe_atlas_gui);
view(gui_data.handles.axes_atlas,[0,0]);
update_slice(probe_atlas_gui);
% (hacky - switch focus back to axes)
set(h,'enable','off');drawnow;set(h,'enable','on');
end

function view_sagittal(h,eventdata,probe_atlas_gui)
% Set sagittal view
gui_data = guidata(probe_atlas_gui);
view(gui_data.handles.axes_atlas,[-90,0]);
update_slice(probe_atlas_gui);
% (hacky - switch focus back to axes)
set(h,'enable','off');drawnow;set(h,'enable','on');
end

function view_horizontal(h,eventdata,probe_atlas_gui)
% Set horizontal view
gui_data = guidata(probe_atlas_gui);
view(gui_data.handles.axes_atlas,[0,90]);
update_slice(probe_atlas_gui);
% (hacky - switch focus back to axes)
set(h,'enable','off');drawnow;set(h,'enable','on');
end

function popup_controls(~,~,~)

CreateMode.Interpreter = 'tex';
CreateMode.WindowStyle = 'non-modal';

msgbox({'\fontsize{16}\bfProbe controls: ', ...
    '\fontsize{14}\rmWhole probe: Arrow keys', ...
    'Probe insertion depth: Alt + Arrow keys', ...
    'Probe rotation angle: Ctrl + Arrow keys', ...
    'Probe tip (changes angle): Shift + Arrow keys', ...
    'Select probe (if >1): Click probe, selected is \color{blue}blue'}, ...
    'Keyboard controls','help',CreateMode);

end

function probe_add(~,~,probe_atlas_gui,probe_type)
% Add probe

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Get index of new probe
if ~isfield(gui_data,'probe')
    % (first probe)
    new_probe_idx = 1;
else
    % (additional probes)
    new_probe_idx = length(gui_data.probe) + 1;
end

% Select probe type (if not input)
if nargin < 4 || isempty(probe_type)
    probe_types = {'Neuropixels 1.0','Neuropixels 2.0'};
    [probe_type_idx,probe_type_selected] = listdlg( ...
        'PromptString',sprintf('Probe %d: choose type',new_probe_idx), ...
        'ListString',probe_types, ...
        'SelectionMode','single');
    if ~probe_type_selected
        % If no probe selected, do nothing
        return
    else
        probe_type = probe_types{probe_type_idx};
    end
end

% Draw probe trajectory
trajectory_top = [0,0,-0.1];
trajectory_bottom = [0,0,6];
trajectory_vector = [trajectory_top',trajectory_bottom'];
trajectory_line = line(gui_data.handles.axes_atlas, ...
    trajectory_vector(1,:),trajectory_vector(2,:),trajectory_vector(3,:), ...
    'linewidth',1.5,'color','r','linestyle','--');

% Define default trajectory vector
probe_default_vector = [0,0,0;0,0,1]';

% Create probe shank geometry for selected type
switch probe_type
    case 'Neuropixels 1.0'
        probe_length = 3.840;
        shank_vector = permute(probe_default_vector.*probe_length,[3,2,1]);
    case 'Neuropixels 2.0'
        probe_length = 3.840;
        shank_spacing = [((0:3)*0.25);zeros(1,4);zeros(1,4)];
        shank_vector = permute(probe_default_vector.*probe_length + ...
            permute(shank_spacing,[1,3,2]),[2,3,1]);
end

% Draw probe
probe_line = line(gui_data.handles.axes_atlas, ...
    shank_vector(:,:,1), ...
    shank_vector(:,:,2), ...
    shank_vector(:,:,3), ...
    'color','m','linewidth',2);

% Draw probe insertion point
probe_insertion_point = plot3(gui_data.handles.axes_atlas,...
    trajectory_top(1),trajectory_top(2), ...
    trajectory_top(3),'.r','MarkerSize',30);

% Set up click-to-select (probe line or area axes)
set(probe_line,'ButtonDownFcn',{@select_probe,probe_atlas_gui});
set(probe_line,'Tag','rotate_clickable'); % (even during rotate3d)

% Store probe data and axes
gui_data.probe(new_probe_idx).trajectory = trajectory_line; % Trajectory line on 3D atlas
gui_data.probe(new_probe_idx).reference_vector = shank_vector; % Default probe position
gui_data.probe(new_probe_idx).line = probe_line; % Probe reference line on 3D atlas
gui_data.probe(new_probe_idx).insertion_point = probe_insertion_point; % Probe reference line on 3D atlas
gui_data.probe(new_probe_idx).length = probe_length; % Length of probe
gui_data.probe(new_probe_idx).dv = probe_length;
gui_data.probe(new_probe_idx).angle = [0;90;0]; % azimuth, elevation, rotation
gui_data.probe(new_probe_idx).type = probe_type;
gui_data.probe(new_probe_idx).ref_shank = 1;

% Set default recording slot (order of creation)
gui_data.probe(new_probe_idx).recording_slot = new_probe_idx;

% Update guidata
guidata(probe_atlas_gui,gui_data);

% Select probe
select_probe(gui_data.probe(new_probe_idx).line,[],probe_atlas_gui)

% Update probe areas and coordinates
update_probe_areas_coordinates(probe_atlas_gui);

% Update slice for newly selected probe
update_slice(probe_atlas_gui);

% Make GUI the current figure (not the toolbar)
figure(probe_atlas_gui);

end

function probe_remove(~,~,probe_atlas_gui)
% Remove probe

% Get guidata
gui_data = guidata(probe_atlas_gui);

% If there are no probes, don't do anything
if ~isfield(gui_data,'probe') || isempty(gui_data.probe)
    return
end

% Delete selected probe graphics
% (note: needed isgraphics & isa, because isgraphics doesn't distinguish
% between a handle and a double with the same value)
probe_fieldnames = fieldnames(gui_data.probe(gui_data.selected_probe));
probe_isgraphics = cellfun(@(x) ...
    any(isgraphics(gui_data.probe(gui_data.selected_probe).(x)(:))) & ...
    ~any(isa(gui_data.probe(gui_data.selected_probe).(x)(:),'double')) ,probe_fieldnames);
cellfun(@(x) delete(gui_data.probe(gui_data.selected_probe).(x)), ...
    probe_fieldnames(probe_isgraphics));

% Remove selected probe data
gui_data.probe(gui_data.selected_probe) = [];

% Update guidata
guidata(probe_atlas_gui,gui_data);

if ~isempty(gui_data.probe)
    % If there are remaining probes, auto-select first probe
    select_probe(gui_data.probe(1).line,[],probe_atlas_gui);
    update_probe_areas_coordinates(probe_atlas_gui);
    update_slice(probe_atlas_gui);
else
    % If there are no probes, clear selected and update text
    set(gui_data.probe_coordinates_text,'String','No probe selected');
    gui_data.selected_probe = [];

    % Update guidata
    guidata(probe_atlas_gui,gui_data);
end


end

function set_probe_recording_slot(~,~,probe_atlas_gui)
% Set probe properties

% Get guidata
gui_data = guidata(probe_atlas_gui);
n_probes = length(gui_data.probe);

% Create editable properties box
probe_slot_fig = uifigure('Name','Set probe properties');
probe_slot_grid = uigridlayout(probe_slot_fig,[2,2]);
probe_slot_grid.RowHeight = {'7x','1x'};

probe_recording_slots = num2cell(vertcat(gui_data.probe.recording_slot));
probe_types = {gui_data.probe.type}';
probe_properties = [probe_types,probe_recording_slots];

probe_properties_table = uitable(probe_slot_grid, ...
    'ColumnName',{'Probe type','Recording slot'}, ...
    'ColumnFormat',{'char','numeric'}, ...
    'ColumnEditable',[false,true], ...
    'RowName',arrayfun(@(x) sprintf('Probe %d',x),1:n_probes,'uni',false), ...
    'Data',probe_properties);
probe_properties_table.Layout.Column = [1,2];
uibutton(probe_slot_grid,'push', ...
    'Text','Save','ButtonPushedFcn',{@set_probe_recording_slot_save,probe_atlas_gui});
uibutton(probe_slot_grid,'push', ...
    'Text','Cancel','ButtonPushedFcn',@set_probe_recording_slot_cancel);

% Probe properties box functions
    function set_probe_recording_slot_save(obj,eventdata,probe_atlas_gui)
        % Get guidata
        gui_data = guidata(probe_atlas_gui);

        % Set recording slots
        [gui_data.probe.recording_slot] = deal(obj.Parent.Children(1).Data{:,2});

        % Update guidata
        guidata(probe_atlas_gui,gui_data);

        % Close properties box
        close(obj.Parent.Parent);
    end
    function set_probe_recording_slot_cancel(obj,eventdata)
        % Close properties box
        close(obj.Parent.Parent);
    end
end


function set_bregma_lambda_distance(h,eventdata,probe_atlas_gui)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Input bregma-lambda distance (default is standard average)
bregma_lambda_distance_new = ...
    cellfun(@str2num,inputdlg('Bregma-Lambda distance (mm):','', ...
    1,{num2str(gui_data.bregma_lambda_distance_avg)}));

update_brain_scale(probe_atlas_gui,bregma_lambda_distance_new);

end

function add_area_list(h,eventdata,probe_atlas_gui)
% List all CCF areas, draw selected

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Prompt for which structures to show (only structures which are
% labelled in the slice-spacing downsampled annotated volume)
slice_spacing = 10;

% Sort by alphabetical order and display list
[~,area_sort_idx] = sort(gui_data.st.safe_name);
plot_structure = area_sort_idx(listdlg('PromptString','Select a structure to plot:', ...
    'ListString',gui_data.st.safe_name(area_sort_idx),'ListSize',[520,500], ...
    'SelectionMode','single'));

% Draw areas
draw_areas(probe_atlas_gui,plot_structure);

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
draw_areas(probe_atlas_gui,plot_structure);

end

function add_area_hierarchy(h,eventdata,probe_atlas_gui)
% Explore CCF hierarchy, draw selected

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Bring up hierarchical selector
plot_structure = hierarchical_select(gui_data.st);

% Draw areas
draw_areas(probe_atlas_gui,plot_structure);

end

function draw_areas(probe_atlas_gui,plot_structure)

% Get guidata
gui_data = guidata(probe_atlas_gui);

if ~isempty(plot_structure)

    curr_structure_plot_idx = min([ ...
        find(gui_data.structure_plot_idx == plot_structure), ...
        length(gui_data.structure_plot_idx)+1]);

    % If the plot structure already exists, remove and redraw it
    if any(gui_data.structure_plot_idx == plot_structure)
        delete(gui_data.handles.structure_patch(curr_structure_plot_idx))
        gui_data.structure_plot_idx(curr_structure_plot_idx) = [];
        gui_data.handles.structure_patch(curr_structure_plot_idx) = [];
    end

    % Get all areas within and below the selected hierarchy level
    plot_structure_id = gui_data.st.structure_id_path{plot_structure};
    plot_ccf_idx = find(cellfun(@(x) contains(x,plot_structure_id), ...
        gui_data.st.structure_id_path));

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
    plot_structure_color = hex2dec(reshape(gui_data.st.color_hex_triplet{plot_structure},2,[])')./255;

    gui_data.structure_plot_idx(curr_structure_plot_idx) = plot_structure;
    gui_data.handles.structure_patch(curr_structure_plot_idx) = patch(gui_data.handles.axes_atlas, ...
        'Vertices',structure_3d.vertices, ...
        'Faces',structure_3d.faces, ...
        'FaceColor',plot_structure_color,'EdgeColor','none', ...
        'FaceAlpha',structure_alpha,'PickableParts','none');

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

function set_areas_probe(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Set name convention and check menu
h.Checked = 'on';
gui_data.display_areas = 'probe';

% Uncheck other options (mutually exclusive menu)
alt_menu_options = get(h.Parent,'Children');
set(alt_menu_options(alt_menu_options ~= h),'Checked','off');

% Update gui_data and area names
guidata(probe_atlas_gui, gui_data);
update_probe_areas_coordinates(probe_atlas_gui);
end

function set_areas_trajectory(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Set name convention and check menu
h.Checked = 'on';
gui_data.display_areas = 'trajectory';

% Uncheck other options (mutually exclusive menu)
alt_menu_options = get(h.Parent,'Children');
set(alt_menu_options(alt_menu_options ~= h),'Checked','off');

% Update gui_data and area names
guidata(probe_atlas_gui, gui_data);
update_probe_areas_coordinates(probe_atlas_gui);
end

function set_name_acronym(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Set name convention and check menu
h.Checked = 'on';
gui_data.display_region_name = 'acronym';

% Uncheck other options (mutually exclusive menu)
alt_menu_options = get(h.Parent,'Children');
set(alt_menu_options(alt_menu_options ~= h),'Checked','off');

% Update gui_data and area names
guidata(probe_atlas_gui, gui_data);
update_probe_areas_coordinates(probe_atlas_gui);
end

function set_name_full(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Set name convention and check menu
h.Checked = 'on';
gui_data.display_region_name = 'safe_name';

% Uncheck other options (mutually exclusive menu)
alt_menu_options = get(h.Parent,'Children');
set(alt_menu_options(alt_menu_options ~= h),'Checked','off');

% Update gui_data and area names
guidata(probe_atlas_gui, gui_data);
update_probe_areas_coordinates(probe_atlas_gui);
end


function visibility_av_slice(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

switch h.Checked; case 'on'; new_visibility = 'off'; case 'off'; new_visibility = 'on'; end;
set(gui_data.handles.slice_plot,'Visible',new_visibility);

% Set slice data to AV
gui_data.handles.slice_volume = 'av';

% Set menu item check
h.Checked = new_visibility;

% Uncheck other options (mutually exclusive menu)
alt_menu_options = get(h.Parent,'Children');
set(alt_menu_options(alt_menu_options ~= h),'Checked','off');

% Update gui_data and slice
guidata(probe_atlas_gui, gui_data);
update_slice(probe_atlas_gui);

end

function visibility_tv_slice(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

switch h.Checked; case 'on'; new_visibility = 'off'; case 'off'; new_visibility = 'on'; end;
set(gui_data.handles.slice_plot,'Visible',new_visibility);

% Set slice data to TV
gui_data.handles.slice_volume = 'tv';

% Set menu item check
h.Checked = new_visibility;

% Uncheck other options (mutually exclusive menu)
alt_menu_options = get(h.Parent,'Children');
set(alt_menu_options(alt_menu_options ~= h),'Checked','off');

% Update gui_data and slice
guidata(probe_atlas_gui, gui_data);
update_slice(probe_atlas_gui);

end

function visibility_brain_outline(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Toggle brain outline visibility
switch h.Checked; case 'on'; new_visibility = 'off'; case 'off'; new_visibility = 'on'; end;
set(gui_data.handles.brain_outline,'Visible',new_visibility);

% Set menu item check
h.Checked = new_visibility;

% Upload gui_data
guidata(probe_atlas_gui,gui_data);
end

function visibility_grid(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Toggle grid
switch h.Checked; case 'on'; new_visibility = 'off'; case 'off'; new_visibility = 'on'; end;
set(gui_data.handles.axes_atlas,'Visible',new_visibility);

% Set menu item check
h.Checked = new_visibility;

% Upload gui_data
guidata(probe_atlas_gui,gui_data);
end

function visibility_probe(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Toggle probe visibility
switch h.Checked; case 'on'; new_visibility = 'off'; case 'off'; new_visibility = 'on'; end;
set([gui_data.probe.trajectory],'Visible',new_visibility);
set([gui_data.probe.line],'Visible',new_visibility);
set([gui_data.probe.insertion_point],'Visible',new_visibility);

% Set menu item check
h.Checked = new_visibility;

% Upload gui_data
guidata(probe_atlas_gui,gui_data);
end

function visibility_3d_areas(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Toggle plotted structure visibility
if ~isempty(gui_data.structure_plot_idx)
    switch h.Checked; case 'on'; new_visibility = 'off'; case 'off'; new_visibility = 'on'; end;
    set(gui_data.handles.structure_patch,'Visible',new_visibility);

    % Set menu item check
    h.Checked = new_visibility;
end

% Upload gui_data
guidata(probe_atlas_gui,gui_data);
end

function visibility_darkmode(h,eventdata,probe_atlas_gui)
% Get guidata
gui_data = guidata(probe_atlas_gui);

% Toggle dark mode
switch h.Checked; case 'on'; new_visibility = 'off'; case 'off'; new_visibility = 'on'; end;

switch new_visibility
    case 'on'
        new_bg_color = 'k';
        new_font_color = 'w';
    case 'off'
        new_bg_color = 'w';
        new_font_color = 'k';
end

% Set font colors
set(probe_atlas_gui,'color',new_bg_color)
set(gui_data.handles.axes_probe_areas,'ycolor',new_font_color)
set(gui_data.handles.axes_probe_areas.Title,'color',new_font_color)
set(gui_data.probe_coordinates_text,'color',new_font_color)

% Set menu item check
h.Checked = new_visibility;

% Upload gui_data
guidata(probe_atlas_gui,gui_data);
end


function save_probe_positions(h,eventdata,probe_atlas_gui)

% Get guidata
gui_data = guidata(probe_atlas_gui);

n_probes = length(gui_data.probe);

% Get CCF coordinates for the probe (dim x start/end x shank)
probe_positions_ccf = cell(n_probes,1);
for curr_probe = 1:n_probes
     probe_position = permute(cell2mat(permute(get( ...
        gui_data.probe(curr_probe).line, ...
        {'XData','YData','ZData'}),[1,3,2])),[3,2,1]);

     probe_position_ccf = ...
         reshape(transformPointsInverse(gui_data.ccf_bregma_tform, ...
         reshape(probe_position,3,[])')',size(probe_position));

     probe_positions_ccf{curr_probe} = probe_position_ccf;
end

% Get areas along each probe
% (mostly copied from update_area - ideally don't copy code)
probe_areas = cell(n_probes,1);
for curr_probe = 1:n_probes

    % Get current probe location
    probe_vector = permute(cell2mat(permute(get( ...
        gui_data.probe(curr_probe).line, ...
        {'XData','YData','ZData'}),[1,3,2])),[2,3,1]);

    n_shanks = size(probe_vector,3);

    % Interpolate to extremes of probe range
    ml_lim = xlim(gui_data.handles.axes_atlas);
    ap_lim = ylim(gui_data.handles.axes_atlas);
    dv_lim = zlim(gui_data.handles.axes_atlas);
    max_ref_length = norm([range(ap_lim);range(dv_lim);range(ml_lim)]);

    sample_points = (-max_ref_length:0.001:max_ref_length)';
    probe_sample_points_bregma = reshape( ...
        interp1([0,gui_data.probe(curr_probe).length], ...
        reshape(probe_vector,2,[]), ...
        sample_points,'linear','extrap'), ...
        [length(sample_points),size(probe_vector,[2,3])]);

    probe_sample_points_ccf_flat = ...
        round(transformPointsInverse(gui_data.ccf_bregma_tform, ...
        reshape(permute(probe_sample_points_bregma,[1,3,2]),[],3)));

    inbounds_idx = all(probe_sample_points_ccf_flat > 0 & ...
        probe_sample_points_ccf_flat <= size(gui_data.av,[3,1,2]),2);

    probe_sample_ccf_idx = ...
        sub2ind(size(gui_data.av), ...
        probe_sample_points_ccf_flat(inbounds_idx,2), ...
        probe_sample_points_ccf_flat(inbounds_idx,3), ...
        probe_sample_points_ccf_flat(inbounds_idx,1));

    probe_av_idx = ones(length(sample_points),n_shanks);
    probe_av_idx(inbounds_idx) = gui_data.av(probe_sample_ccf_idx);

    % Only plot areas that have index >1 (in-brain)
    plot_probe_areas_idx = find(any(probe_av_idx > 1,2));
    probe_areas_plot = probe_av_idx(plot_probe_areas_idx,:);

    % Get insertion coordinate
    ref_shank = gui_data.probe(curr_probe).ref_shank;
    insertion_point = probe_sample_points_bregma( ...
        plot_probe_areas_idx(find(probe_areas_plot(:,ref_shank) > 1,1,'first')),:,ref_shank);

    if isempty(insertion_point)
        % (don't update if there isn't an insertion point)
        set(gui_data.probe_coordinates_text,'String','Probe trajectory is outside brain');
        return
    end

    % Get current depth of probe relative to insertion coordinate
    probe_depth = pdist2(insertion_point,probe_vector(2,:,ref_shank));

    % Get area depths relative to insertion coordinate
    probe_areas_plot_depth = pdist2(insertion_point, ...
        probe_sample_points_bregma(plot_probe_areas_idx,:,ref_shank))';

    % Get colors for all areas (draw white lines between areas)
    probe_areas_hexcolors = gui_data.st.color_hex_triplet(probe_areas_plot);
    probe_areas_rgbcolors = cell2mat(cellfun(@(x) ...
        permute(hex2dec({x(1:2),x(3:4),x(5:6)})'./255,[1,3,2]), ...
        probe_areas_hexcolors,'uni',false));
    for curr_shank = 1:n_shanks
        probe_areas_rgbcolors(imdilate(boundarymask( ...
            probe_areas_plot(:,curr_shank)),ones(20,1)),curr_shank,:) = 1;
    end

    % Get depth boundaries and structure tree entries for all regions
    if ~isfield(gui_data,'display_region_name')
        gui_data.display_region_name = 'acronym';
    end

    probe_area_boundaries = cell(n_shanks,1);
    probe_area_st = cell(n_shanks,1);
    for curr_shank = 1:n_shanks

        shank_areas_plot = probe_areas_plot(:,curr_shank);
        shank_areas_boundaries_idx = intersect(unique( ...
            [find(shank_areas_plot ~= 1,1,'first'); ...
            find(diff(shank_areas_plot) ~= 0); ...
            find(shank_areas_plot ~= 1,1,'last')]), ...
            find(shank_areas_plot ~= 1));
        shank_areas_centers_idx = round(shank_areas_boundaries_idx(1:end-1) + ...
            diff(shank_areas_boundaries_idx)/2);

        probe_area_bins = ...
            probe_areas_plot_depth(shank_areas_boundaries_idx);

        probe_area_boundaries{curr_shank} = ...
            [probe_area_bins(1:end-1),probe_area_bins(2:end)];
        probe_area_st{curr_shank} = ...
            gui_data.st(probe_areas_plot(shank_areas_centers_idx,curr_shank),:);

    end

    % Concatenate across shanks and store
    curr_probe_areas = vertcat(probe_area_st{:});
    curr_probe_areas.probe_depth = vertcat(probe_area_boundaries{:});
    curr_probe_areas.probe_shank = cell2mat(cellfun(@(shank,areas) ...
        repmat(shank,size(areas,1),1),num2cell(1:n_shanks)',probe_area_st,'uni',false));

    probe_areas{curr_probe} = curr_probe_areas;

end

% Get probe properties
probe_angles_cat = horzcat(gui_data.probe.angle);
probe_properties = struct( ...
    'probe_type',{gui_data.probe.type}, ...
    'rotation_angle',num2cell(probe_angles_cat(3,:)));

% Choose file location and save
[save_file,save_path] = uiputfile('probe_positions.mat','Save probe positions as...');
save_filename = fullfile(save_path,save_file);
save(save_filename,'probe_positions_ccf','probe_areas','probe_properties');

end

function load_probe_positions(h,eventdata,probe_atlas_gui)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Choose file and load
[probe_file,probe_path] = uigetfile('probe_positions.mat','Choose probe positions to load...');
probe_filename = fullfile(probe_path,probe_file);
load(probe_filename);

% Remove any pre-existing probes
if isfield(gui_data,'probe') && ~isempty(gui_data.probe)
    extant_n_probes = length(gui_data.probe);
    for i = 1:extant_n_probes
        probe_remove([],[],probe_atlas_gui);
        gui_data = guidata(probe_atlas_gui);
    end
end

% Create and position each saved probe
for curr_probe = 1:length(probe_positions_ccf)

    % Create probe
    % (use stored probe type, or guess from shank number if not)
    if exist('probe_properties','var')
        probe_type = probe_properties(curr_probe).probe_type;
    else
        switch size(probe_positions_ccf{curr_probe},3)
            case 1
                probe_type = 'Neuropixels 1.0';
            case 4
                probe_type = 'Neuropixels 2.0';
        end
    end
    probe_add([],[],probe_atlas_gui,probe_type);
    gui_data = guidata(probe_atlas_gui);

    % Convert saved probe coordinates CCF to stereotaxic
    curr_probe_positions_bregma =  ...
        reshape(transformPointsForward(gui_data.ccf_bregma_tform, ...
        reshape(probe_positions_ccf{curr_probe},3,[])')', ...
        size(probe_positions_ccf{curr_probe}));

    % Move probe trajectory to align with probe
    ref_shank = gui_data.probe(curr_probe).ref_shank;

    dv_lim = zlim(gui_data.handles.axes_atlas);
    trajectory_endpoints = ...
        interp1(curr_probe_positions_bregma(3,:,ref_shank), ...
        curr_probe_positions_bregma(:,:,ref_shank)',dv_lim,'linear','extrap');

    [gui_data.probe(curr_probe).trajectory.XData, ...
        gui_data.probe(curr_probe).trajectory.YData, ...
        gui_data.probe(curr_probe).trajectory.ZData] = deal( ...
        trajectory_endpoints(:,1), ...
        trajectory_endpoints(:,2), ...
        trajectory_endpoints(:,3));

    % Set probe DV coordinate
    gui_data.probe(curr_probe).dv = curr_probe_positions_bregma(3,2,1);

    % Set probe rotation angle (if stored)
    if exist('probe_properties','var')
        gui_data.probe(curr_probe).angle(3) = ...
            probe_properties(curr_probe).rotation_angle;
    end

    % Update guidata
    guidata(probe_atlas_gui,gui_data);

    % Update probe position and coordinates
    update_probe_position(probe_atlas_gui);
    update_probe_areas_coordinates(probe_atlas_gui);

end

% Update slice
update_slice(probe_atlas_gui);

end


%% Manipulator interfacing

function connect_newscale(h,eventdata,probe_atlas_gui)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Flip checked status
switch h.Checked; case 'on'; new_check = 'off'; case 'off'; new_check = 'on'; end;
h.Checked = new_check;

switch new_check
    case 'on'
        % Create button: zero probe at brain surface
        button_fontsize = 12;
        button_position = [0.70,0,0.20,0.05];
        gui_data.handles.zero_dv_button = ...
            uicontrol('Parent',probe_atlas_gui,'Style','pushbutton','FontSize',button_fontsize, ...
            'Units','normalized','Position',button_position,'String','Set probe at brain surface', ...
            'Callback',{@set_manipulator_dv_offset,probe_atlas_gui});
        guidata(probe_atlas_gui, gui_data);

        % Add "connecting" message
        set(gui_data.probe_coordinates_text,'String','CONNECTING TO NEW SCALE MPM...');
        set(gui_data.probe_coordinates_text,'Color','r')

        % Initialize MPM client
        if ~isdeployed
            % (being run in matlab: dll is kept in helpers folder)
            newscale_client_filename = fullfile( ...
                fileparts(which('neuropixels_trajectory_explorer')), ...
                'nte_helpers','newscale','NstMpmClientAccess.dll');
        elseif isdeployed
            % (standalone: included in exe, load)
            newscale_client_filename = which('NstMpmClientAccess.dll');
        end

        NET.addAssembly(newscale_client_filename);
        import NstMpmClientAccess.*
        newscale_client = NstMpmClientAccess.NstMpmClient;

        % Get IP and port configuration
        % (load settings: default is same computer, port 8080)
        matlab_settings = settings;
        if ~hasGroup(matlab_settings,'neuropixels_trajectory_explorer')
            addGroup(matlab_settings,'neuropixels_trajectory_explorer');
        end
        if ~hasSetting(matlab_settings.neuropixels_trajectory_explorer,'newscale_ip')
            addSetting(matlab_settings.neuropixels_trajectory_explorer,'newscale_ip');
            addSetting(matlab_settings.neuropixels_trajectory_explorer,'newscale_port');

            matlab_settings.neuropixels_trajectory_explorer.newscale_ip.PersonalValue = 'localhost';
            matlab_settings.neuropixels_trajectory_explorer.newscale_port.PersonalValue = '8080';
        end

        newscale_client_settings = inputdlg({'IP address (localhost if this computer):', ...
            'Port (Pathfinder: Coordinate Sys > ... > Http server) :'},'Pathfinder',1, ...
            {matlab_settings.neuropixels_trajectory_explorer.newscale_ip.ActiveValue, ...
            matlab_settings.neuropixels_trajectory_explorer.newscale_port.ActiveValue});
        newscale_client.IP_Address = newscale_client_settings{1};
        newscale_client.Port = str2num(newscale_client_settings{2});

        % Save current settings for future sessions
        matlab_settings.neuropixels_trajectory_explorer.newscale_ip.PersonalValue = char(newscale_client.IP_Address);
        matlab_settings.neuropixels_trajectory_explorer.newscale_port.PersonalValue = num2str(newscale_client.Port);

        % Initial MPM query
        newscale_client.QueryMpmApplication;

        % (if there was a query problem, error out)
        if any(newscale_client.LastError ~= '')
            error('Error querying MPM: %s',newscale_client.LastError);
        end

        % Remove any pre-existing probes
        if isfield(gui_data,'probe') && ~isempty(gui_data.probe)
            user_n_probes = length(gui_data.probe);
            for i = 1:user_n_probes
                probe_remove([],[],probe_atlas_gui);
                gui_data = guidata(probe_atlas_gui);
            end
        end

        % Add number of MPM-connected probes
        newscale_n_probes = newscale_client.AppData.Probes;
        for i = 1:newscale_n_probes
            newscale_probe_info = newscale_client.AppData.GetProbe(i-1);
            switch newscale_probe_info.ShankCount
                case 1
                    probe_type = 'Neuropixels 1.0';
                case 4
                    probe_type = 'Neuropixels 2.0';
            end
            probe_add([],[],probe_atlas_gui,probe_type);
            gui_data = guidata(probe_atlas_gui);
        end

        % Set manipulator DV offset for brain surface
        gui_data.manipulator_dv_offset = zeros(newscale_n_probes,1);

        % Save newscale_client in guidata
        gui_data.connection.manipulator.model = 'New Scale MPM';
        gui_data.connection.manipulator.client = newscale_client;
        guidata(probe_atlas_gui, gui_data);

        % Set up timer function for updating probe position
        manipulator_query_rate = 5; % Queries per second (hard-coding, 10Hz is ~max)
        gui_data.connection.manipulator.timer_fcn = timer('TimerFcn', ...
            {@get_newscale_position,probe_atlas_gui}, ...
            'Period', 1/manipulator_query_rate, 'ExecutionMode','fixedSpacing', ...
            'TasksToExecute', inf);

        % Restore text color
        set(gui_data.probe_coordinates_text,'Color','k')

        % Store timer function and start
        % (necessary for the standalone, which deletes function on 'start')
        guidata(probe_atlas_gui,gui_data);
        start(gui_data.connection.manipulator.timer_fcn)

    case 'off'
        % Stop timer function and delete connection
        try
            stop(gui_data.connection.manipulator.timer_fcn)
        catch
        end
        gui_data.connection = rmfield(gui_data.connection,'manipulator');

        % Remove manipulator buttons
        delete(gui_data.handles.zero_dv_button);

        % Update gui data
        guidata(probe_atlas_gui,gui_data);

        % Update probe coordinates
        update_probe_areas_coordinates(probe_atlas_gui);
end

end

function get_newscale_position(obj,event,probe_atlas_gui)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Query MPM app for probe information
gui_data.connection.manipulator.client.QueryMpmApplication;

% Loop through all MPM probes, update data
for curr_newscale_probe = 1:gui_data.connection.manipulator.client.AppData.Probes

    % Get given MPM probe data (0-indexed)
    newscale_probe_info = gui_data.connection.manipulator.client.AppData.GetProbe(curr_newscale_probe-1);

    % Get tip position of probe (MPM convention: -Z is down)
    mpm_tip = [newscale_probe_info.Tip_X_ML; newscale_probe_info.Tip_Y_AP; -newscale_probe_info.Tip_Z_DV];

    % Check if any changes to probe (if not, skip)
    curr_probe_position = cell2mat(get(gui_data.probe(curr_newscale_probe).line, ...
        {'XData','YData','ZData'})');
    if all(mpm_tip == curr_probe_position(:,2))
        continue
    end

    % Calculate top position of the probe (back up from bottom by angles)

    % (MPM convention: Polar is relative to Posterior Angle, Pitch: 0 is vertical)
    mpm2nte_angles = ...
        [newscale_probe_info.Polar-double(gui_data.connection.manipulator.client.AppData.PosteriorAngle), ...
        90-newscale_probe_info.Pitch, ...
        newscale_probe_info.ShankOrientation];

    % Get DV offset relative to zeroing at brain surface (if applicable)
    if isfield(gui_data,'manipulator_dv_offset') && ...
            length(gui_data.manipulator_dv_offset) >= curr_newscale_probe
        manipulator_dv_offset = gui_data.manipulator_dv_offset(curr_newscale_probe);
    else
        manipulator_dv_offset = 0;
    end
    mpm_tip_dv_adjusted = mpm_tip + [0;0;manipulator_dv_offset];

    % Update DV and angles
    gui_data.probe(curr_newscale_probe).dv = mpm_tip_dv_adjusted(3);
    gui_data.probe(curr_newscale_probe).angle = mpm2nte_angles;

    % Update the probe and trajectory reference
    ml_lim = xlim(gui_data.handles.axes_atlas);
    ap_lim = ylim(gui_data.handles.axes_atlas);
    dv_lim = zlim(gui_data.handles.axes_atlas);
    max_ref_length = norm([range(ap_lim);range(dv_lim);range(ml_lim)]);
    [x,y,z] = sph2cart( ...
        deg2rad(90-mpm2nte_angles(1)),  ...
        deg2rad(180+mpm2nte_angles(2)), ...
        -max_ref_length);

    % Move trajectory (draw line through point and DV 0 with max length)
    trajectory_top_ap = interp1(mpm_tip_dv_adjusted(3)+[0,z],mpm_tip(2)+[0,y],0,'linear','extrap');
    trajectory_top_ml = interp1(mpm_tip(3)+[0,z],mpm_tip_dv_adjusted(1)+[0,x],0,'linear','extrap');

    trajectory_top = [trajectory_top_ml,trajectory_top_ap,0];
    trajectory_bottom = trajectory_top + [x,y,z];

    trajectory_vector = [trajectory_top;trajectory_bottom]';

    set(gui_data.probe(curr_newscale_probe).trajectory, ...
        'XData',trajectory_vector(1,:), ...
        'YData',trajectory_vector(2,:), ...
        'ZData',trajectory_vector(3,:));

    % Update gui data
    guidata(probe_atlas_gui, gui_data);

    % Get bregma-lambda distance (from Probe A), re-scale atlas if changed
    newscale_probe_info = gui_data.connection.manipulator.client.AppData.GetProbe(0);
    newscale_bregma_lambda_distance = ...
        norm([newscale_probe_info.Bregma_X,newscale_probe_info.Bregma_Y,newscale_probe_info.Bregma_Z]- ...
        [newscale_probe_info.Lambda_X,newscale_probe_info.Lambda_Y,newscale_probe_info.Lambda_Z]);
    if newscale_bregma_lambda_distance ~= gui_data.bregma_lambda_distance_curr
        update_brain_scale(probe_atlas_gui,newscale_bregma_lambda_distance);
    end

    % Select current probe and update position
    select_probe(gui_data.probe(curr_newscale_probe).line,[],probe_atlas_gui)
    update_probe_position(probe_atlas_gui);

end

% Select MPM-selected probe (0-indexed, unselected = -1 so force >1)
newscale_selected_probe = max(gui_data.connection.manipulator.client.AppData.SelectedProbe+1,1);
select_probe(gui_data.probe(newscale_selected_probe).line,[],probe_atlas_gui)

% Update slice and position for selected probe
update_probe_areas_coordinates(probe_atlas_gui);
update_slice(probe_atlas_gui);

end

function set_manipulator_dv_offset(h,eventdata,probe_atlas_gui)
% Set probe tip DV at brain surface, apply DV offset

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Get probe position
probe_position = ...
    [gui_data.probe(gui_data.selected_probe).line.XData; ...
    gui_data.probe(gui_data.selected_probe).line.YData; ...
    gui_data.probe(gui_data.selected_probe).line.ZData];
probe_tip = probe_position(:,2);

% Get brain surface at ML/AP position
% (use brain outline mesh: find closest surface coordinate)
brain_outline_median_dv = median(gui_data.handles.brain_outline.Vertices(:,3));
use_vertices = find(gui_data.handles.brain_outline.Vertices(:,3) <= brain_outline_median_dv);

[~,mesh_coord_idx] = min(pdist2(probe_tip(1:2)', ...
    gui_data.handles.brain_outline.Vertices(use_vertices,1:2)));
manipulator_dv_offset = ...
    gui_data.handles.brain_outline.Vertices(use_vertices(mesh_coord_idx),3) - probe_tip(3);

% Store DV offset for currently selected probe
% (combine with current offset, if there is one)
manipulator_dv_offset_total = ...
    manipulator_dv_offset + gui_data.manipulator_dv_offset(gui_data.selected_probe);

gui_data.manipulator_dv_offset(gui_data.selected_probe) = manipulator_dv_offset_total;

% Update gui data
guidata(probe_atlas_gui, gui_data);

end

function connect_scientifica(h,eventdata,probe_atlas_gui)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Flip checked status
switch h.Checked; case 'on'; new_check = 'off'; case 'off'; new_check = 'on'; end;
h.Checked = new_check;

switch new_check
    case 'on'
        % Create button: zero manipulator
        button_fontsize = 12;
        button_position = [0.75,0,0.15,0.05];
        gui_data.handles.zero_manipulator_button = ...
            uicontrol('Parent',probe_atlas_gui,'Style','pushbutton','FontSize',button_fontsize, ...
            'Units','normalized','Position',button_position,'String','Zero manipulator', ...
            'Callback',{@zero_scientifica,probe_atlas_gui});

        % Update gui data
        guidata(probe_atlas_gui, gui_data);

        % Add "connecting" message
        set(gui_data.probe_coordinates_text,'String','CONNECTING TO SCIENTIFICA PATCHSTAR...');
        set(gui_data.probe_coordinates_text,'Color','r')

        % Find serial ports and prompt choice
        serial_ports = serialportlist('available');
        scientifica_serial_port = serial_ports(listdlg( ...
            'ListString',serial_ports,'SelectionMode','single'));

        % Connect to the manipulator, configure, store
        scientifica_connection = serialport(scientifica_serial_port,9600); % Motion Card 1: baud rate = 9600
        configureTerminator(scientifica_connection,'CR'); % Terminator = carriage return
        writeline(scientifica_connection,'ANGLE A'); % Set auto angle
        readline(scientifica_connection); % Read feedback
        writeline(scientifica_connection,'ZERO'); % Zero manipulator
        readline(scientifica_connection); % Read feedback

        gui_data.connection.manipulator.model = 'Scientifica Patchstar';
        gui_data.connection.manipulator.client = scientifica_connection;

        % Set up timer function for updating probe position
        manipulator_query_rate = 5; % MPM queries per second (hard-coding, 10Hz is ~max)
        gui_data.connection.manipulator.timer_fcn = timer('TimerFcn', ...
            {@get_scientifica_position,probe_atlas_gui}, ...
            'Period', 1/manipulator_query_rate, 'ExecutionMode','fixedSpacing', ...
            'TasksToExecute', inf);

        % Restore text color
        set(gui_data.probe_coordinates_text,'Color','k')

        % Store timer function and start
        % (necessary for the standalone, which deletes function on 'start')
        guidata(probe_atlas_gui,gui_data);
        start(gui_data.connection.manipulator.timer_fcn)

    case 'off'
        % Stop and delete timer function
        try
            stop(gui_data.connection.manipulator.timer_fcn)
        catch
        end
        delete(gui_data.connection.manipulator.timer_fcn)

        % Delete serial connection
        delete(gui_data.connection.manipulator.client)
        % Remove manipulator buttons
        delete(gui_data.handles.zero_manipulator_button);
end

end

function get_scientifica_position(obj,event,probe_atlas_gui)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Clear the manipulator buffer
flush(gui_data.connection.manipulator.client)

% Get position
% (allow a few attempts, if conflics with other commands)
writeline(gui_data.connection.manipulator.client,'P');
scientifica_position = str2num(readline(gui_data.connection.manipulator.client));

writeline(gui_data.connection.manipulator.client,'ANGLE');
scientifica_elevation_angle = str2num(readline(gui_data.connection.manipulator.client));
% (convert coordinate order and direction)
probe_tip = (scientifica_position([2,1,3]).*[1,-1,-1])'/10000; % reports as 1/10 microns
probe_angle = [90,scientifica_elevation_angle]; % TO DO: currently assume 90 azimuth

% (using length of recording sites, not full length of the probe from VCS)
[x,y,z] = sph2cart( ...
    deg2rad(90-probe_angle(1)),  ...
    deg2rad(180+probe_angle(2)), ...
    gui_data.probe.length);
probe_top = probe_tip + [x; y; z];

% Set probe vector
probe_vector = [probe_top, probe_tip] ;

% Update angles
gui_data.probe.angle{1} = probe_angle;

% Change probe location
set(gui_data.probe(1).line, ...
    'XData',probe_vector(1,:), ...
    'YData',probe_vector(2,:), ...
    'ZData',probe_vector(3,:));

% Update the probe and trajectory reference
ml_lim = xlim(gui_data.handles.axes_atlas);
ap_lim = ylim(gui_data.handles.axes_atlas);
dv_lim = zlim(gui_data.handles.axes_atlas);
max_ref_length = norm([range(ap_lim);range(dv_lim);range(ml_lim)]);
[x,y,z] = sph2cart( ...
    deg2rad(90-probe_angle(1)),  ...
    deg2rad(180+probe_angle(2)), ...
    -max_ref_length);

% Move probe reference (draw line through point and DV 0 with max length)
probe_ref_top_ap = interp1(probe_vector(3,2)+[0,z],probe_vector(2,2)+[0,y],0,'linear','extrap');
probe_ref_top_ml = interp1(probe_vector(3,2)+[0,z],probe_vector(1,2)+[0,x],0,'linear','extrap');

probe_ref_top = [probe_ref_top_ml,probe_ref_top_ap,0];
probe_ref_bottom = probe_ref_top + [x,y,z];

trajectory_vector = [probe_ref_top;probe_ref_bottom]';

set(gui_data.probe.trajectory(1), ...
    'XData',trajectory_vector(1,:), ...
    'YData',trajectory_vector(2,:), ...
    'ZData',trajectory_vector(3,:));

% Update gui data
guidata(probe_atlas_gui, gui_data);

% Update the slice and probe coordinates
update_probe_areas_coordinates(probe_atlas_gui);

% Update slice
update_slice(probe_atlas_gui);

end

function zero_scientifica(h,eventdata,probe_atlas_gui)
% Set probe tip DV at brain surface, apply DV offset

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Stop manipulator read timer
stop(gui_data.connection.manipulator.timer_fcn);

% Zero manipulator
writeline(gui_data.connection.manipulator.client,'ZERO'); % Zero manipulator
readline(gui_data.connection.manipulator.client); % Read feedback

% Re-start manipulator read timer
start(gui_data.connection.manipulator.timer_fcn);

end

%% Recording interfacing

function connect_openephys(h,eventdata,probe_atlas_gui)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Flip checked status
switch h.Checked; case 'on'; new_check = 'off'; case 'off'; new_check = 'on'; end;
h.Checked = new_check;

switch new_check
    case 'on'

        % Get IP and port configuration
        % (load settings: default is same computer)
        matlab_settings = settings;
        if ~hasGroup(matlab_settings,'neuropixels_trajectory_explorer')
            addGroup(matlab_settings,'neuropixels_trajectory_explorer');
        end
        if ~hasSetting(matlab_settings.neuropixels_trajectory_explorer,'openephys_ip')
            addSetting(matlab_settings.neuropixels_trajectory_explorer,'openephys_ip');
            matlab_settings.neuropixels_trajectory_explorer.openephys_ip.PersonalValue = 'localhost';
        end

        openephys_ip = inputdlg({'IP address (''localhost'' if this computer):'}, ...
            'Open Ephys',1,{matlab_settings.neuropixels_trajectory_explorer.openephys_ip.ActiveValue});
        openephys_port = 37497; % (this is constant in Open Ephys)

        % Save current settings for future sessions
        matlab_settings.neuropixels_trajectory_explorer.openephys_ip.PersonalValue = char(openephys_ip);

        % Confirm open ephys is open on that IP (port always 37497)
        try
            openephys_status = webread(sprintf('http://%s:%d/api/status', ...
                openephys_ip{1},openephys_port));
        catch me
            errordlg(sprintf('Open Ephys not accessible on %s:%d', ...
                openephys_ip{1},openephys_port),'Open Ephys');
        end

        % Set IP/port for recording software
        gui_data.connection.recording.software = 'Open Ephys';
        gui_data.connection.recording.ip = openephys_ip{1};
        gui_data.connection.recording.port = openephys_port;

    case 'off'
        % Remove recording connection
        if isfield(gui_data.connection,'recording')
            gui_data.connection = rmfield(gui_data.connection,'recording');
        end

end

% Update gui data
guidata(probe_atlas_gui, gui_data);

% Send probe coordinates
update_probe_areas_coordinates(probe_atlas_gui);

end

function connect_spikeglx(h,eventdata,probe_atlas_gui)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Flip checked status
switch h.Checked; case 'on'; new_check = 'off'; case 'off'; new_check = 'on'; end;
h.Checked = new_check;

switch new_check
    case 'on'

        % Get IP and port configuration
        % (load settings: default is same computer)
        matlab_settings = settings;
        if ~hasGroup(matlab_settings,'neuropixels_trajectory_explorer')
            addGroup(matlab_settings,'neuropixels_trajectory_explorer');
        end
        if ~hasSetting(matlab_settings.neuropixels_trajectory_explorer,'spikeglx_ip')
            addSetting(matlab_settings.neuropixels_trajectory_explorer,'spikeglx_ip');
            addSetting(matlab_settings.neuropixels_trajectory_explorer,'spikeglx_port');

            matlab_settings.neuropixels_trajectory_explorer.spikeglx_ip.PersonalValue = '127.0.0.1';
            matlab_settings.neuropixels_trajectory_explorer.spikeglx_port.PersonalValue = '4142';
        end

        spikeglx_settings = inputdlg({'IP address:','Port:'}, ...
            'SpikeGLX',1,{matlab_settings.neuropixels_trajectory_explorer.spikeglx_ip.ActiveValue, ...
            matlab_settings.neuropixels_trajectory_explorer.spikeglx_port.ActiveValue});

        spikeglx_ip = spikeglx_settings{1};
        spikeglx_port = str2num(spikeglx_settings{2});

        % Save current settings for future sessions
        matlab_settings.neuropixels_trajectory_explorer.spikeglx_ip.PersonalValue = spikeglx_settings{1};
        matlab_settings.neuropixels_trajectory_explorer.spikeglx_port.PersonalValue = spikeglx_settings{2};

        % Connect to SpikeGLX
        try
            spikeglx_client = SpikeGL(spikeglx_ip,spikeglx_port);

            % Set IP/port for recording software
            gui_data.connection.recording.software = 'SpikeGLX';
            gui_data.connection.recording.client = spikeglx_client;

        catch me
            errordlg({sprintf('SpikeGLX not accessible on %s:%d',spikeglx_ip,spikeglx_port), ...
                'Ensure SpikeGLX server is running (SpikeGLX console: Options >  Command Server Settings > Enable)'},'SpikeGLX');
        end

    case 'off'
        % Remove recording connection
        if isfield(gui_data.connection,'recording')
            gui_data.connection = rmfield(gui_data.connection,'recording');
        end

end

% Update gui data
guidata(probe_atlas_gui, gui_data);

% Send probe coordinates
update_probe_areas_coordinates(probe_atlas_gui);

end

function send_recording_areas(gui_data,probe_depth,area_boundaries,area_labels,area_hexcolors)

switch gui_data.connection.recording.software

    case 'Open Ephys'
        % Open Ephys area conventions:
        % <probe_name>;<start_index_1>-<end_index_1>,<region_ID_1>,<hex_color_1>;<start_index_2>-<end_index_2>,...
        %
        % Example:
        % ProbeA;0-69,PT,FF909F;70-97,PVT,FF909F;98-161,-,000000;162-173,-,000000,174-185,SF,90CBED;...
        %
        % The "start_index" / "end_index" are in the indices of the electrodes in a
        % given region, ideally going all the way up the probe. The Probe Viewer
        % will then display a subset depending on which electrodes are selected.

        % Calculate the depths of each site along the trajectory
        n_sites = 1000;
        site_y_spacing = 0.02;
        probe_sites = reshape(repmat(((1:n_sites/2)-1)*site_y_spacing,2,1),[],1);
        probe_sites_depth = sort(probe_depth(2) - probe_sites);
        probe_sites_depth_bins = [probe_sites_depth - site_y_spacing/2; ...
            probe_sites_depth(end) + site_y_spacing/2];

        % Get the area boundaries as site numbers (flip top/tip)
        area_boundaries_sites = discretize(area_boundaries,probe_sites_depth_bins,(n_sites:-1:1)-1);

        % Convert selected probe number to letter
        alphabet = 'A':'Z';
        probe_letter = alphabet(gui_data.probe(gui_data.selected_probe).recording_slot);

        send_areas = find(~isnan(area_boundaries_sites));
        [~,send_area_sort] = sort(area_boundaries_sites(send_areas));
        areas_send_txt = [sprintf('Probe%s;',probe_letter), ...
            cell2mat(arrayfun(@(x) sprintf('%d-%d,%s,%s;', ...
            area_boundaries_sites(x+1),area_boundaries_sites(x), ...
            area_labels{x}, ...
            area_hexcolors{x}),send_areas(send_area_sort),'uni',false)')];

        % Get probe viewer processor number
        openephys_processors = webread(sprintf('http://%s:%d/api/processors', ...
            gui_data.connection.recording.ip,gui_data.connection.recording.port));
        probe_viewer_idx = strcmp({openephys_processors.processors.name},'Probe Viewer');

        % Send areas to Open Ephys
        if any(probe_viewer_idx)
            openephys_url = sprintf('http://%s:%d/api/processors/%d/config', ...
                gui_data.connection.recording.ip, ...
                gui_data.connection.recording.port, ...
                openephys_processors.processors(probe_viewer_idx).id);
            openephys_send_status = webwrite(openephys_url, struct('text',areas_send_txt), ...
                weboptions('RequestMethod','put','MediaType','application/json'));
        end

    case 'SpikeGLX'
        % SpikeGLX area conventions:
        %     Set anatomy data string with Pinpoint format:
        %     [probe-id,shank-id](startpos,endpos,R,G,B,rgnname)(startpos,endpos,R,G,B,rgnname)…()
        %        - probe-id: SpikeGLX logical probe id.
        %        - shank-id: [0..n-shanks].
        %        - startpos: region start in microns from tip.
        %        - endpos:   region end in microns from tip.
        %        - R,G,B:    region color as RGB, each [0..255].
        %        - rgnname:  region name text.

        % Get SpikeGLX probes (unused at the moment)
        orig_warning = warning;
        warning('off','all')
        spikeglx_probelist = GetProbeList(gui_data.connection.recording.client);
        spike_glx_probelist_parsed = regexp(spikeglx_probelist, ...
            '(\d*),(\d*),PRB_(\d*)_(\d*)_(\d*)_(\d*)','tokens');
        warning(orig_warning);

        % If selected probe index is more than number of SpikeGLX: do nothing
        if gui_data.selected_probe > length(spike_glx_probelist_parsed)
            return
        end

        % Get area depths relative to probe tip
        % (SpikeGLX is microns from tip, so add in tip length)
        tip_length = 175;
        area_boundaries_um = -(area_boundaries-probe_depth(2))*1000 + tip_length;

        % Colors: hex to RGB
        area_rgbcolors = cell2mat(cellfun(@(x) ...
            hex2dec({x(1:2),x(3:4),x(5:6)})', ...
            area_hexcolors,'uni',false));

        % (note: SpikeGLX zero indexes probe/shank)
        areas_send_txt = [sprintf('[%d,%d]', ...
            gui_data.probe(gui_data.selected_probe).recording_slot-1,0), ...
            cell2mat(arrayfun(@(x) sprintf('(%d,%d,%g,%g,%g,%s)', ...
            area_boundaries_um(x+1),area_boundaries_um(x)-1, ...
            area_rgbcolors(x,:), area_labels{x}), ...
            (1:length(area_boundaries_um)-1)','uni',false)')];

        % Send areas to SpikeGLX
        % (sends warning about connection: turn warnings off/on to avoid)
        orig_warning = warning;
        warning('off','all')
        SetAnatomy_Pinpoint(gui_data.connection.recording.client,areas_send_txt);
        warning(orig_warning);

        % SpikeGLX TO DO:
        % Get geometry of recorded sites by:
        % x = GetGeomMap(gui_data.connection.recording.client,ip)
        % (ip = probe index, zero-indexed)
        % (commands often take js = jth stream (0=NI, 1=Onebox,2=imec probe)
        % (ip is the ith object of the stream, the ith probe)
        % (need to execute this one level back where it's pulling the areas)

end

end



%% General functions

function draw_brain(probe_atlas_gui)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Draw brain outline
slice_spacing = 5;
if ~isdeployed
    % (being run in matlab: can use bwmorph3)
    brain_volume = ...
        bwmorph3(bwmorph3(gui_data.av(1:slice_spacing:end, ...
        1:slice_spacing:end,1:slice_spacing:end)>1,'majority'),'majority');
elseif isdeployed
    % (standalone mode: can't use bwmorph3, slightly messier volume)
    brain_volume = ...
        gui_data.av(1:slice_spacing:end, ...
        1:slice_spacing:end,1:slice_spacing:end)>1;
end

[ap_grid_ccf,dv_grid_ccf,ml_grid_ccf] = ...
    ndgrid(1:slice_spacing:size(gui_data.av,1), ...
    1:slice_spacing:size(gui_data.av,2), ...
    1:slice_spacing:size(gui_data.av,3));

[ml_grid_bregma,ap_grid_bregma,dv_grid_bregma] = ...
    transformPointsForward(gui_data.ccf_bregma_tform,ml_grid_ccf,ap_grid_ccf,dv_grid_ccf);

brain_outline_patchdata = isosurface(ml_grid_bregma,ap_grid_bregma, ...
    dv_grid_bregma,brain_volume,0.5);

if ~isfield(gui_data.handles,'brain_outline')
    % If a brain outline doesn't exist yet, draw it
    brain_outline = patch( ...
        gui_data.handles.axes_atlas, ...
        'Vertices',brain_outline_patchdata.vertices, ...
        'Faces',brain_outline_patchdata.faces, ...
        'FaceColor',[0.5,0.5,0.5],'EdgeColor','none','FaceAlpha',0.1, ...
        'PickableParts','none'); % make unclickable, since probes are inside and clickable

    gui_data.handles.brain_outline = brain_outline;
else
    % If a brain outline exists, set new faces/vertices
    set(gui_data.handles.brain_outline, ...
        'Vertices',brain_outline_patchdata.vertices, ...
        'Faces',brain_outline_patchdata.faces);
end

% Set the axes bounds to contain the whole brain
xlim(gui_data.handles.axes_atlas,[min(ml_grid_bregma(:)),max(ml_grid_bregma(:))]);
ylim(gui_data.handles.axes_atlas,[min(ap_grid_bregma(:)),max(ap_grid_bregma(:))]);
zlim(gui_data.handles.axes_atlas,[min(dv_grid_bregma(:)),max(dv_grid_bregma(:))]);

% Update gui data
guidata(probe_atlas_gui, gui_data);

end

function select_probe(h,eventdata,probe_atlas_gui)
% Select active/controllable probe

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Get index of clicked probe
selected_probe_idx = cellfun(@(x) any(h == x),{gui_data.probe.line});

% Color probe/axes by selected/unselected
selected_color = [0,0,1];
unselected_color = [0,0,0];
set(vertcat(gui_data.probe.line),'color',unselected_color);
set(gui_data.probe(selected_probe_idx).line,'color',selected_color);

% Set selected probe
gui_data.selected_probe = find(selected_probe_idx);

% Update gui data
guidata(probe_atlas_gui, gui_data);

% Update the slice and probe coordinates
update_probe_areas_coordinates(probe_atlas_gui);
update_slice(probe_atlas_gui);

end

function flag = rotate_clickable(obj,event_obj)
% If the object tag is 'rotate_clickable', then enable clicking even during
% rotate3d
if strcmpi(obj.Tag,'rotate_clickable')
    flag = true;
else
    flag = false;
end
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









