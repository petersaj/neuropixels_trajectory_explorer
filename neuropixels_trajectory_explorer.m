%% Neuropixels Trajector Explorer
% neuropixels_trajectory_explorer
% Andy Peters (peters.andrew.j@gmail.com)
%
% GUI for planning Neuropixels trajectories with the Allen CCF atlas
%
% Instructions for use: 
% https://github.com/petersaj/neuropixels_trajectory_explorer

%% GUI setup
function neuropixels_trajectory_explorer

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

% ~~~~ Load atlas and associated data

% Load in atlas
% (directory with CCF must be in matlab path to find it)
% Find path with CCF
allen_atlas_path = fileparts(which('template_volume_10um.npy'));
if isempty(allen_atlas_path)
    error('CCF atlas not in MATLAB path (click ''Set path'', add folder with CCF)');
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

% ~~~~ Make transform matrix from CCF to bregma/mm coordinates

% (translation values from our bregma estimate: AP/ML from Paxinos, DV from
% rough MRI estimate)
bregma_ccf = [570.5,580,44]; % [ML,AP,DV]
ccf_translation_tform = eye(4)+[zeros(3,4);-bregma_ccf,0];

% (scaling "Toronto MRI transform", reflect AP/ML, convert 10um to 1mm)
scale = [-0.952,-1.031,0.885]./100; % [ML,AP,DV]
ccf_scale_tform = eye(4).*[scale,1]';

% (rotation values from IBL estimate)
ap_rotation = -5; % 5 degrees nose-down
ccf_rotation_tform = ...
    [1 0 0 0; ...
    0 cosd(ap_rotation) -sind(ap_rotation) 0; ...
    0 sind(ap_rotation) cosd(ap_rotation) 0; ...
    0 0 0 1];

ccf_bregma_tform_matrix = ccf_translation_tform*ccf_scale_tform*ccf_rotation_tform;
ccf_bregma_tform = affine3d(ccf_bregma_tform_matrix);

% ~~~~ Make GUI axes and objects

% Set up the gui
probe_atlas_gui = figure('Toolbar','none','Menubar','none','color','w', ...
    'Name','Neuropixels Trajectory Explorer','Units','normalized','Position',[0.21,0.2,0.7,0.7]);

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
        'FaceColor',[0.5,0.5,0.5],'EdgeColor','none','FaceAlpha',0.1, ...
        'PickableParts','none'); % make unclickable, since probes behind

view([30,150]);
caxis([0 300]);
xlim([-5,5]);ylim([-8,6]);zlim([-1,6.5]);
grid_spacing = 0.5;
set(gca,'XTick',floor(min(xlim)):grid_spacing:ceil(max(xlim)));
set(gca,'YTick',floor(min(ylim)):grid_spacing:ceil(max(ylim)));
set(gca,'ZTick',floor(min(zlim)):grid_spacing:ceil(max(zlim)));
grid on;

% Set up the text to display coordinates
probe_coordinates_text = uicontrol('Style','text','String','', ...
    'Units','normalized','Position',[0,0.9,0.5,0.1], ...
    'BackgroundColor','w','HorizontalAlignment','left','FontSize',12, ...
    'FontName','Consolas');

% Set up the probe area axes
axes_probe_areas = axes('Position',[0.7,0.1,0.03,0.8],'TickDir','in');
axes_probe_areas.ActivePositionProperty = 'position';
set(axes_probe_areas,'FontSize',11);
yyaxis(axes_probe_areas,'left');
probe_areas_plot = image(0);
set(axes_probe_areas,'XTick','','YColor','k','YDir','reverse');
ylabel(axes_probe_areas,'Depth (mm)');
yyaxis(axes_probe_areas,'right');
set(axes_probe_areas,'XTick','','YColor','k','YDir','reverse');
title(axes_probe_areas,'Probe areas');
colormap(axes_probe_areas,ccf_cmap);
caxis([1,size(ccf_cmap,1)]);

% Store data
gui_data.tv = tv; % Intensity atlas
gui_data.av = av; % Annotated atlas
gui_data.st = st; % Labels table
gui_data.cmap = ccf_cmap; % Atlas colormap
gui_data.ccf_bregma_tform = ccf_bregma_tform;
gui_data.structure_plot_idx = []; % Plotted structures

% Store handles
gui_data.handles.cortex_outline = brain_outline;
gui_data.handles.structure_patch = []; % Plotted structures
gui_data.handles.axes_atlas = axes_atlas; % Axes with 3D atlas
gui_data.handles.axes_probe_areas = axes_probe_areas; % Axes with probe areas
gui_data.handles.probe_areas_plot = probe_areas_plot; % Color-coded probe regions
gui_data.handles.slice_plot = surface(axes_atlas,'EdgeColor','none'); % Slice on 3D atlas
gui_data.handles.slice_volume = 'tv'; % The volume shown in the slice
gui_data.probe_coordinates_text = probe_coordinates_text; % Probe coordinates text

% Make 3D rotation the default state
h = rotate3d(axes_atlas);
h.Enable = 'on';
h.ButtonDownFilter = @rotate_clickable;
% Update the slice whenever a rotation is completed
h.ActionPostCallback = @update_slice;

% Set functions for key presses
hManager = uigetmodemanager(probe_atlas_gui);
[hManager.WindowListenerHandles.Enabled] = deal(false);
set(probe_atlas_gui,'KeyPressFcn',@key_press);
set(probe_atlas_gui,'KeyReleaseFcn',@key_release);

% Upload gui_data
guidata(probe_atlas_gui, gui_data);

% Add a probe, draw slice
probe_add([],[],probe_atlas_gui);
update_slice(probe_atlas_gui);


%% Buttons

button_fontsize = 12;

%%% View angle buttons
view_button_position = [0,0,0.1,0.05];
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
probe_controls_string = {'Whole probe: arrow','Depth: alt+arrow','Tip (angle): shift+arrow','Click probe to select'};
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','text','FontSize',button_fontsize, ...
    'Units','normalized','Position',header_text_position.*[1,1,1,length(probe_controls_string)], ...
    'String',probe_controls_string,'BackgroundColor','w','HorizontalAlignment','left');
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Set entry','Callback',{@set_probe_entry,probe_atlas_gui});
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Set endpoint','Callback',{@set_probe_endpoint,probe_atlas_gui});
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Add probe','Callback',{@probe_add,probe_atlas_gui});
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Remove probe','Callback',{@probe_remove,probe_atlas_gui});

% (area selector)
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','text','FontSize',button_fontsize, ...
    'Units','normalized','Position',header_text_position,'String','3D areas:', ...
    'BackgroundColor','w','FontWeight','bold');
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','List areas','Callback',{@add_area_list,probe_atlas_gui});
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Search areas','Callback',{@add_area_search,probe_atlas_gui});
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','pushbutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','Hierarchy areas','Callback',{@add_area_hierarchy,probe_atlas_gui});
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

% (Manipulator sync:)
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','text','FontSize',button_fontsize, ...
    'Units','normalized','Position',header_text_position,'String','Manipulator interface:', ...
    'BackgroundColor','w','FontWeight','bold');

% (New Scale sync mode)
controls_h(end+1) = uicontrol('Parent',control_panel,'Style','togglebutton','FontSize',button_fontsize, ...
    'Units','normalized','Position',button_position,'String','New Scale','Callback',{@newscale_mode,probe_atlas_gui}); 

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
    set(gui_data.handles.probe_ref_line(gui_data.selected_probe),'XData', ...
        get(gui_data.handles.probe_ref_line(gui_data.selected_probe),'XData') + ml_offset);
    set(gui_data.handles.probe_line(gui_data.selected_probe),'XData', ...
        get(gui_data.handles.probe_line(gui_data.selected_probe),'XData') + ml_offset);
    set(gui_data.handles.probe_ref_line(gui_data.selected_probe),'YData', ...
        get(gui_data.handles.probe_ref_line(gui_data.selected_probe),'YData') + ap_offset);
    set(gui_data.handles.probe_line(gui_data.selected_probe),'YData', ...
        get(gui_data.handles.probe_line(gui_data.selected_probe),'YData') + ap_offset);
    % (probe axis)
    old_probe_vector = cell2mat(get(gui_data.handles.probe_line(gui_data.selected_probe), ...
        {'XData','YData','ZData'})');
    move_probe_vector = diff(old_probe_vector,[],2)./ ...
        norm(diff(old_probe_vector,[],2))*probe_offset;
    new_probe_vector = bsxfun(@plus,old_probe_vector,move_probe_vector);
    set(gui_data.handles.probe_line(gui_data.selected_probe),'XData',new_probe_vector(1,:), ...
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
    probe_ref_top = [gui_data.handles.probe_ref_line(gui_data.selected_probe).XData(1), ...
        gui_data.handles.probe_ref_line(gui_data.selected_probe).YData(1), ...
        gui_data.handles.probe_ref_line(gui_data.selected_probe).ZData(1)];
    probe_ref_bottom = [gui_data.handles.probe_ref_line(gui_data.selected_probe).XData(2), ...
        gui_data.handles.probe_ref_line(gui_data.selected_probe).YData(2), ...
        gui_data.handles.probe_ref_line(gui_data.selected_probe).ZData(2)];
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
        
            colormap(gui_data.handles.axes_atlas,gui_data.cmap);
            caxis(gui_data.handles.axes_atlas,[1,size(gui_data.cmap,1)]);
    end
   
    % Update the slice display
    set(gui_data.handles.slice_plot, ...
        'XData',plane_ml_bregma,'YData',plane_ap_bregma,'ZData',plane_dv_bregma,'CData',curr_slice);
    drawnow;

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
[y,x,z] = sph2cart(pi+probe_angle_rad(1),pi-probe_angle_rad(2),max_ref_length);

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
probe_ref_vector = cell2mat(get(gui_data.handles.probe_ref_line(gui_data.selected_probe),{'XData','YData','ZData'})');
probe_vector = cell2mat(get(gui_data.handles.probe_line(gui_data.selected_probe),{'XData','YData','ZData'})');

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
    diff(fliplr(-new_probe_ref_vector(1,:))), ...
    diff(fliplr(-new_probe_ref_vector(3,:))));
gui_data.probe_angle{gui_data.selected_probe} = [probe_azimuth,probe_elevation]*(360/(2*pi));

set(gui_data.handles.probe_ref_line(gui_data.selected_probe), ...
    'XData',new_probe_ref_vector(1,:), ...
    'YData',new_probe_ref_vector(2,:), ...
    'ZData',new_probe_ref_vector(3,:));

% Update probe (retain depth)
new_probe_vector = [new_probe_ref_vector(:,1),diff(new_probe_ref_vector,[],2)./ ...
    norm(diff(new_probe_ref_vector,[],2))*gui_data.probe_length(gui_data.selected_probe) ...
    + new_probe_ref_vector(:,1)];

probe_depth = sqrt(sum((probe_ref_vector(:,1) - probe_vector(:,1)).^2));
new_probe_vector_depth = (diff(new_probe_vector,[],2)./ ...
    norm(diff(new_probe_vector,[],2))*probe_depth) + new_probe_vector;

set(gui_data.handles.probe_line(gui_data.selected_probe), ...
    'XData',new_probe_vector_depth(1,:), ...
    'YData',new_probe_vector_depth(2,:), ...
    'ZData',new_probe_vector_depth(3,:));

% Upload gui_data
guidata(probe_atlas_gui, gui_data);

end


function update_probe_coordinates(probe_atlas_gui,varargin)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Get the positions of the probe and trajectory reference
probe_ref_vector = cell2mat(get(gui_data.handles.probe_ref_line(gui_data.selected_probe),{'XData','YData','ZData'})');
probe_vector = cell2mat(get(gui_data.handles.probe_line(gui_data.selected_probe),{'XData','YData','ZData'})');

trajectory_n_coords = round(max(abs(diff(probe_ref_vector,[],2)))*100); % 10um resolution
[trajectory_ml_coords_bregma,trajectory_ap_coords_bregma,trajectory_dv_coords_bregma] = deal( ...
    linspace(probe_ref_vector(1,1),probe_ref_vector(1,2),trajectory_n_coords), ...
    linspace(probe_ref_vector(2,1),probe_ref_vector(2,2),trajectory_n_coords), ...
    linspace(probe_ref_vector(3,1),probe_ref_vector(3,2),trajectory_n_coords));

probe_n_coords = round(sqrt(sum(diff(probe_vector,[],2).^2))*100); % 10um resolution along active sites
probe_coords_depth = linspace(0,gui_data.probe_length(gui_data.selected_probe),probe_n_coords);
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
trajectory_coords_ccf = ...
    round([trajectory_ap_coords_ccf;trajectory_dv_coords_ccf;trajectory_ml_coords_ccf]);
trajectory_coords_ccf_inbounds = all(trajectory_coords_ccf > 0 & ...
    trajectory_coords_ccf <= size(gui_data.av)',1);

trajectory_idx = ...
    sub2ind(size(gui_data.av), ...
    round(trajectory_ap_coords_ccf(trajectory_coords_ccf_inbounds)), ...
    round(trajectory_dv_coords_ccf(trajectory_coords_ccf_inbounds)), ...
    round(trajectory_ml_coords_ccf(trajectory_coords_ccf_inbounds)));
trajectory_areas = ones(trajectory_n_coords,1); % (out of CCF = 1: non-brain)
trajectory_areas(trajectory_coords_ccf_inbounds) = gui_data.av(trajectory_idx);

trajectory_brain_idx = find(trajectory_areas > 1,1);
trajectory_brain_intersect = ...
    [trajectory_ml_coords_bregma(trajectory_brain_idx), ...
    trajectory_ap_coords_bregma(trajectory_brain_idx), ...
    trajectory_dv_coords_bregma(trajectory_brain_idx)]';

% (if the probe doesn't intersect the brain, don't update)
if isempty(trajectory_brain_intersect)
    return
end

probe_coords_ccf = ...
    round([probe_ap_coords_ccf;probe_dv_coords_ccf;probe_ml_coords_ccf]);
probe_coords_ccf_inbounds = all(probe_coords_ccf > 0 & ...
    probe_coords_ccf <= size(gui_data.av)',1);

probe_idx = ...
    sub2ind(size(gui_data.av), ...
    round(probe_ap_coords_ccf(probe_coords_ccf_inbounds)), ...
    round(probe_dv_coords_ccf(probe_coords_ccf_inbounds)), ...
    round(probe_ml_coords_ccf(probe_coords_ccf_inbounds)));
probe_areas = ones(probe_n_coords,1); % (out of CCF = 1: non-brain)
probe_areas(probe_coords_ccf_inbounds) = gui_data.av(probe_idx);

probe_area_boundaries = intersect(unique([find(~isnan(probe_areas),1,'first'); ...
    find(diff(probe_areas) ~= 0);find(~isnan(probe_areas),1,'last')]),find(~isnan(probe_areas)));
probe_area_centers_idx = round(probe_area_boundaries(1:end-1) + diff(probe_area_boundaries)/2);
probe_area_centers = probe_coords_depth(probe_area_centers_idx);
probe_area_labels = gui_data.st.safe_name(probe_areas(probe_area_centers_idx));

% Get coordinate from bregma and probe-axis depth from surface
% (round to nearest 10 microns)
probe_bregma_coordinate = trajectory_brain_intersect;
probe_depth = norm(trajectory_brain_intersect - probe_vector(:,2));

% Update the text
% (manipulator angles)
probe_angle_text = sprintf('Probe angle:     % .0f%c azimuth, % .0f%c elevation', ...
    gui_data.probe_angle{gui_data.selected_probe}(1),char(176), ...
    gui_data.probe_angle{gui_data.selected_probe}(2),char(176));
% (probe insertion point and depth)
probe_insertion_text = sprintf('Probe insertion: % .2f AP, % .2f ML, % .2f depth', ...
    probe_bregma_coordinate(2),probe_bregma_coordinate(1),probe_depth);
% (probe start/endpoints)
recording_startpoint_text = sprintf('Recording start: % .2f AP, % .2f ML, % .2f DV', ...
    probe_vector([2,1,3],1));
recording_endpoint_text = sprintf('Recording end:   % .2f AP, % .2f ML, % .2f DV', ...
    probe_vector([2,1,3],2));

% (combine and update)
probe_text = {probe_angle_text,probe_insertion_text, ...
    recording_startpoint_text,recording_endpoint_text};
set(gui_data.probe_coordinates_text,'String',probe_text);

% Update the probe areas
yyaxis(gui_data.handles.axes_probe_areas,'left');
set(gui_data.handles.axes_probe_areas, ...
    'YTick',[0:0.5:gui_data.probe_length(gui_data.selected_probe)], ...
    'YLim',[0,gui_data.probe_length(gui_data.selected_probe)]);

yyaxis(gui_data.handles.axes_probe_areas,'right');
set(gui_data.handles.probe_areas_plot,'YData',probe_coords_depth,'CData',probe_areas); 
set(gui_data.handles.axes_probe_areas,'YTick',probe_area_centers, ...
    'YTickLabels',probe_area_labels, ...
    'YLim',[0,gui_data.probe_length(gui_data.selected_probe)]);

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

function probe_add(~,~,probe_atlas_gui)
% Add probe

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Get index of new probe
if ~isfield(gui_data.handles,'probe_line')
    % (first probe)
    new_probe_idx = 1;
else
    % (additional probes)
    new_probe_idx = length(gui_data.handles.probe_line) + 1;
end

% Draw probe trajectory
probe_ref_top = [0,0,-0.1];
probe_ref_bottom = [0,0,6];
probe_ref_vector = [probe_ref_top',probe_ref_bottom'];
probe_ref_line = line(gui_data.handles.axes_atlas, ...
    probe_ref_vector(1,:),probe_ref_vector(2,:),probe_ref_vector(3,:), ...
    'linewidth',1.5,'color','r','linestyle','--');

% Draw probe recording length
probe_length = 3.840; % IMEC phase 3 (in mm)
probe_vector = [probe_ref_vector(:,1),diff(probe_ref_vector,[],2)./ ...
    norm(diff(probe_ref_vector,[],2))*probe_length + probe_ref_vector(:,1)];
probe_line = line(gui_data.handles.axes_atlas, ...
    probe_vector(1,:),probe_vector(2,:),probe_vector(3,:), ...
    'linewidth',5,'color','b','linestyle','-');

% Set up click-to-select (probe line or area axes)
set(probe_line,'ButtonDownFcn',{@select_probe,probe_atlas_gui});
set(probe_line,'Tag','rotate_clickable'); % (even during rotate3d)

% Store probe data and axes
gui_data.handles.probe_ref_line(new_probe_idx) = probe_ref_line; % Probe reference line on 3D atlas
gui_data.handles.probe_line(new_probe_idx) = probe_line; % Probe reference line on 3D atlas
gui_data.probe_length(new_probe_idx) = probe_length; % Length of probe
gui_data.probe_angle{new_probe_idx} = [0;90]; % Probe angles in ML/DV

% Update guidata
guidata(probe_atlas_gui,gui_data);

% Select probe
select_probe(gui_data.handles.probe_line(new_probe_idx),[],probe_atlas_gui)

% Update probe coordinates
update_probe_coordinates(probe_atlas_gui);

% Update slice for newly selected probe
update_slice(probe_atlas_gui);

% Make GUI the current figure (not the toolbar)
figure(probe_atlas_gui);

end

function probe_remove(~,~,probe_atlas_gui)
% Remove probe

% Get guidata
gui_data = guidata(probe_atlas_gui);

% If there's only one probe, don't do anything
if length(gui_data.handles.probe_line) == 1
    return
end

% Delete selected probe graphics
delete(gui_data.handles.probe_ref_line(gui_data.selected_probe));
delete(gui_data.handles.probe_line(gui_data.selected_probe));

% Delete selected probe data and handles
gui_data.handles.probe_ref_line(gui_data.selected_probe) = [];
gui_data.handles.probe_line(gui_data.selected_probe) = [];
gui_data.probe_length(gui_data.selected_probe) = [];
gui_data.probe_angle(gui_data.selected_probe) = []; 

% Update guidata
guidata(probe_atlas_gui,gui_data);

% Select first probe
select_probe(gui_data.handles.probe_line(1),[],probe_atlas_gui);

% Update probe coordinates
update_probe_coordinates(probe_atlas_gui);

% Update slice
update_slice(probe_atlas_gui);

end

function add_area_list(h,eventdata,probe_atlas_gui)
% List all CCF areas, draw selected

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Prompt for which structures to show (only structures which are
% labelled in the slice-spacing downsampled annotated volume)
slice_spacing = 10;
parsed_structures = unique(reshape(gui_data.av(1:slice_spacing:end, ...
    1:slice_spacing:end,1:slice_spacing:end),[],1));

% plot_structure_parsed = listdlg('PromptString','Select a structure to plot:', ...
%     'ListString',gui_data.st.safe_name(parsed_structures),'ListSize',[520,500], ...
%     'SelectionMode','single');
% plot_structure = parsed_structures(plot_structure_parsed);

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

function newscale_mode(h,eventdata,probe_atlas_gui)

% Get guidata
gui_data = guidata(probe_atlas_gui);

if eventdata.Source.Value

    % Initialize MPM client
    % (if MPM client not in path, find it and add to the path)
    mpm_client_file = 'NstMpmClientAccess.dll';
    if ~exist(mpm_client_file,'file')
        [~,mpm_client_path] = uigetfile(mpm_client_file,sprintf('Choose MPM client file (%s)',mpm_client_file));
        mpm_client_filename = fullfile(mpm_client_path,mpm_client_file);
        
        if ~exist(mpm_client_filename,'file')
            % error out if file doesn't exist
            error('Please supply MPM client file (%s) - ',mpm_client_file)     
        else
            % if file exists, add folder to path and save
            addpath(mpm_client_path)
            savepath
        end        
    end

    mpm_client_filename = which(mpm_client_file);
    NET.addAssembly(mpm_client_filename);
    import NstMpmClientAccess.*
    mpm_client = NstMpmClientAccess.NstMpmClient;

    % Get IP and port configuration (default is same computer, port 8080)
    mpm_client_settings = inputdlg({'MPM IP address (Computer running VCS):', ...
        'MPM Port (Coordinate Sys > ... > Http server) :'},'MPM',1,{'127.0.0.1','8080'});
    mpm_client.IP_Address = mpm_client_settings{1};
    mpm_client.Port = str2num(mpm_client_settings{2});

    % Initial MPM query
    mpm_client.QueryMpmApplication;

    % (if there was a query problem, error out)
    if any(mpm_client.LastError ~= '')
        error('Error querying MPM: %s',mpm_client.LastError);
    end

    % Get number of probes connected in the MPM
    mpm_n_probes = mpm_client.AppData.Probes;

    % Set number of probes equal to MPM-connected probe number
    user_n_probes = length(gui_data.handles.probe_line);
    if user_n_probes > mpm_n_probes
        for i = 1:(user_n_probes - mpm_n_probes)
            probe_remove([],[],probe_atlas_gui);
            gui_data = guidata(probe_atlas_gui);
        end
    elseif user_n_probes < mpm_n_probes
        for i = 1:(mpm_n_probes - user_n_probes)
            probe_add([],[],probe_atlas_gui);
            gui_data = guidata(probe_atlas_gui);
        end
    end

    % Save mpm_client in guidata
    gui_data.mpm_client = mpm_client;
    guidata(probe_atlas_gui, gui_data);

    % Set up timer function for updating probe position
    mpm_query_rate = 10; % MPM queries per second (hard-coding, can't update faster than 5Hz)
    gui_data.mpm_timer_fcn = timer('TimerFcn', @(~,~)get_mpm_position(probe_atlas_gui), 'Period', 1/mpm_query_rate, 'ExecutionMode','fixedDelay', 'TasksToExecute', inf);
    % store timer function and start (necessary for the standalone, which
    % deletes function on 'start')
    guidata(probe_atlas_gui, gui_data);
    start(gui_data.mpm_timer_fcn)

    % turn button green 
    h.BackgroundColor = [0.39,0.83,0.07];
else
    try
        stop(gui_data.mpm_timer_fcn)
    catch
    end
    delete(gui_data.mpm_timer_fcn)

    % turn button back to normal
    h.BackgroundColor = [0.94,0.94,0.94];
end

% Update gui data
guidata(probe_atlas_gui, gui_data);

end

function get_mpm_position(probe_atlas_gui)

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Query MPM app for probe information
gui_data.mpm_client.QueryMpmApplication;

% Loop through all MPM probes, update data
for curr_mpm_probe = 1:gui_data.mpm_client.AppData.Probes

    % Get given MPM probe data (0-indexed)
    mpm_probe_info = gui_data.mpm_client.AppData.GetProbe(curr_mpm_probe-1);

    % Calculate position of probe
    probe_tip = [mpm_probe_info.Tip_X_ML; mpm_probe_info.Tip_Y_AP; -mpm_probe_info.Tip_Z_DV];

    % (mpm 0 = straight down --> rotate to move from tip to top)
    % (using length of recording sites not full length of the probe from VCS)
    [x, y, z] = sph2cart(deg2rad(360-mpm_probe_info.Polar), deg2rad(270-mpm_probe_info.Pitch), gui_data.probe_length(curr_mpm_probe));
    probe_top = probe_tip + [x; y; z];

    probe_vector = [probe_top, probe_tip];

    % Update angles
    gui_data.probe_angle{curr_mpm_probe} = [360-mpm_probe_info.Polar, 90-mpm_probe_info.Pitch];

    % Change probe location
    set(gui_data.handles.probe_line(curr_mpm_probe), ...
        'XData',probe_vector(1,:), ...
        'YData',probe_vector(2,:), ...
        'ZData',probe_vector(3,:));

    % Update the probe and trajectory reference
    ml_lim = xlim(gui_data.handles.axes_atlas);
    ap_lim = ylim(gui_data.handles.axes_atlas);
    dv_lim = zlim(gui_data.handles.axes_atlas);
    max_ref_length = norm([range(ap_lim);range(dv_lim);range(ml_lim)]);
    [x, y, z] = sph2cart(deg2rad(gui_data.probe_angle{curr_mpm_probe}(1)), ...
        deg2rad(gui_data.probe_angle{curr_mpm_probe}(2)), max_ref_length);

    % Move probe reference (draw line through point and DV 0 with max length)
    probe_ref_top_ap = interp1(probe_tip(3)+[0,z],probe_tip(2)+[0,y],0,'linear','extrap');
    probe_ref_top_ml = interp1(probe_tip(3)+[0,z],probe_tip(1)+[0,x],0,'linear','extrap');

    probe_ref_top = [probe_ref_top_ml,probe_ref_top_ap,0];
    probe_ref_bottom = probe_ref_top + [x,y,z];
    probe_ref_vector = [probe_ref_top;probe_ref_bottom]';

    set(gui_data.handles.probe_ref_line(curr_mpm_probe), ...
        'XData',probe_ref_vector(1,:), ...
        'YData',probe_ref_vector(2,:), ...
        'ZData',probe_ref_vector(3,:));

    % Update gui data
    guidata(probe_atlas_gui, gui_data);

    % Update the slice and probe coordinates
    update_probe_coordinates(probe_atlas_gui);
end

% Select MPM-selected probe (0-indexed)
mpm_selected_probe = gui_data.mpm_client.AppData.SelectedProbe+1;
select_probe(gui_data.handles.probe_line(mpm_selected_probe),[],probe_atlas_gui)

% Update slice
update_slice(probe_atlas_gui);

end

%% General functions

function select_probe(h,eventdata,probe_atlas_gui)
% Select active/controllable probe

% Get guidata
gui_data = guidata(probe_atlas_gui);

% Get index of clicked probe
selected_probe_idx = h == gui_data.handles.probe_line;

% Color probe/axes by selected/unselected
selected_color = [0,0,1];
unselected_color = [0,0,0];
set(gui_data.handles.probe_line(selected_probe_idx),'color',selected_color);
set(gui_data.handles.probe_line(~selected_probe_idx),'color',unselected_color);

% Set selected probe
gui_data.selected_probe = find(selected_probe_idx);

% Update gui data
guidata(probe_atlas_gui, gui_data);

% Update the slice and probe coordinates
update_probe_coordinates(probe_atlas_gui);
update_slice(probe_atlas_gui);

end

function flag = rotate_clickable(obj,event_obj)
% If the object tag is 'rotate_clickable', then enable clicking even during
% rotate3d
objTag = obj.Tag;

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









