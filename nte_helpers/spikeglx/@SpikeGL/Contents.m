% SYNOPSIS
% --------
%
% The @SpikeGL class is a MATLAB object with methods to access the
% SpikeGLX program via TCP/IP. SpikeGLX and MATLAB can run on the
% same machine (via loopback socket address 127.0.0.1 and port 4142)
% or across a network.
%
% This class provides extensive control over a running SpikeGLX process:
% starting and stopping a run, setting parameters, calling the Par2 and
% SHA1 tools, and so on.
%
% Users of this class merely need to construct an instance of a @SpikeGL
% object and all network communication with the SpikeGLX process is handled
% automatically.
%
% The network socket handle is used with the 'CalinsNetMex' mexFunction,
% which is a helper mexFunction that does all the actual socket
% communications for this class (since MATLAB lacks native network
% support).
%
% Instances of @SpikeGL are weakly stateful: merely keeping a handle to a
% network socket. It is ok to create and destroy several of these objects.
% Each network connection cleans up after itself after 10 seconds of
% inactivity. By the way, if your script has pauses longer than 10 seconds,
% and you reuse a handle that has timed out, the handle will automatically
% reestablish a connection and the script will likely continue without
% problems, but a warning will appear in the Command Window reflecting
% the timeout. Such warnings have a warningid, so you can suppress them
% by typing >> warning( 'off', 'CalinsNetMex:connectionClosed' ).
%
% EXAMPLES
% --------
%
% my_s = SpikeGL;   % connect to SpikeGLX running on local machine
%
% prms = GetParams( my_s ); % retrieve run params
%
% SetParams( my_s, struct('niMNChans1','0:5','niDualDevMode','false',...) );
%
% StartRun( my_s ); % starts data acquisition run using last-set params
%
% StopRun( my_s );  % stop run and clean up
%
% (js, ip)
% --------
%
% The two integer values (js, ip) select a data stream.
% js: stream type: {0=nidq, 1=obx, 2=imec-probe}.
% ip: substream:   {0=nidq (if js=0), 0+=which OneBox or imec probe}.
% Examples (js, ip):
% (0, 0) = nidq.	// for nidq, ip is arbitrary but zero by convention
% (1, 4) = obx4.
% (2, 7) = imec7.
% Note: ip has range [0..np-1], where, np is queried using GetStreamNP().
%
% FUNCTION REFERENCE
% ------------------
%
% myobj = SpikeGL()
% myobj = SpikeGL( host )
% myobj = SpikeGL( host, port )
%
%     Construct a new @SpikeGL instance and immediately attempt
%     a network connection. If omitted, the defaults for host and
%     port are {'localhost, 4142}.
%
% myobj = Close( myobj )
%
%     Close the network connection to SpikeGLX and release
%     associated MATLAB resources.
%
% myobj = ConsoleHide( myobj )
%
%     Hide SpikeGLX console window to reduce screen clutter.
%
% myobj = ConsoleShow( myobj )
%
%     Show the SpikeGLX console window.
%
% params = EnumDataDir( myobj, i )
%
%     Retrieve a listing of files in the ith data directory.
%     Get main data directory by setting i=0 or omitting it.
%
% [daqData,headCt] = Fetch( myObj, js, ip, start_samp, max_samps, channel_subset, downsample_ratio )
%
%     Get MxN matrix of stream data.
%     M = samp_count, MIN(max_samps,available).
%     N = channel count...
%     Data are int16 type.
%     Fetching starts at index start_samp.
%     channel_subset is an optional vector of specific channels to fetch [a,b,c...], or,
%         [-1] = all acquired channels, or,
%         [-2] = all saved channels.
%     downsample_ratio is an integer; return every Nth sample (default = 1).
%     Also returns headCt = index of first sample in matrix.
%
% [daqData,headCt] = FetchLatest( myObj, js, ip, max_samps, channel_subset, downsample_ratio )
%
%     Get MxN matrix of the most recent stream data.
%     M = samp_count, MIN(max_samps,available).
%     N = channel count...
%     Data are int16 type.
%     channel_subset is an optional vector of specific channels to fetch [a,b,c...], or,
%         [-1] = all acquired channels, or,
%         [-2] = all saved channels.
%     downsample_ratio is an integer; return every Nth sample (default = 1).
%     Also returns headCt = index of first sample in matrix.
%
% dir = GetDataDir( myobj, i )
%
%     Get ith global data directory.
%     Get main data directory by setting i=0 or omitting it.
%
% params = GetGeomMap( myobj, ip )
%
%     Get geomMap for given logical imec probe.
%     Returned as a struct of name/value pairs.
%     Header fields:
%         head_partNumber   ; string
%         head_numShanks
%         head_shankPitch   ; microns
%         head_shankWidth   ; microns
%     Channel 5, e.g.:
%         ch5_s   ; shank index
%         ch5_x   ; microns from left edge of shank
%         ch5_z   ; microns from center of tip-most electrode row
%         ch5_u   ; used-flag (in CAR operations)
%
% [APgain,LFgain] = GetImecChanGains( myobj, ip, chan )
%
%     Returns the AP and LF gains for given probe and channel.
%
% params = GetParams( myobj )
%
%     Get the most recently used run parameters.
%     These are a struct of name/value pairs.
%
% params = GetParamsImecCommon( myobj )
%
%     Get imec parameters common to all enabled probes.
%     Returned as a struct of name/value pairs.
%
% params = GetParamsImecProbe( myobj, ip )
%
%     Get imec parameters for given logical probe.
%     Returned as a struct of name/value pairs.
%
% params = GetParamsOneBox( myobj, ip )
%
%     Get parameters for given logical OneBox.
%     Returned as a struct of name/value pairs.
%
% list = GetProbeList( myobj )
%
%     Get string with format:
%     (probeID,nShanks,partNumber)()...
%     - A parenthesized entry for each selected probe.
%     - probeID: zero-based integer.
%     - nShanks: integer {1,4}.
%     - partNumber: string, e.g., NP1000.
%     - If no probes, return '()'.
%
% name = GetRunName( myobj )
%
%     Get run base name.
%
% chanCounts = GetStreamAcqChans( myobj, js, ip )
%
%     For the selected substream, returns a vector of the
%     number of channels of each type that stream is acquiring.
%
%     js = 0: NI channels: {MN,MA,XA,DW}.
%     js = 1: OB channels: {XA,DW,SY}.
%     js = 2: IM channels: {AP,LF,SY}.
%
% startingSample = GetStreamFileStart( myobj, js, ip )
%
%     Returns index of first sample in selected file,
%     or zero if unavailable.
%
% mult = GetStreamI16ToVolts( myobj, js, ip, chan )
%
%     Returns multiplier converting 16-bit binary channel to volts.
%
% maxInt = GetStreamMaxInt( myobj, js, ip )
%
%     Returns largest positive integer value for selected stream.
%
% n_substreams = GetStreamNP( myobj, js )
%
%     Returns number (np) of js-type substreams.
%     For the given js, ip has range [0..np-1].
%
% sampleCount = GetStreamSampleCount( myobj, js, ip )
%
%     Returns number of samples since current run started,
%     or zero if not running.
%
% sampleRate = GetStreamSampleRate( myobj, js, ip )
%
%     Returns sample rate of selected stream in Hz.
%
% channelSubset = GetStreamSaveChans( myobj, js, ip )
%
%     Returns a vector containing the indices of
%     the acquired channels that are being saved.
%
% [nS,nC,nR,mat] = GetStreamShankMap( myObj, js, ip )
%
%     Get shank map for NI stream (js = 0):
%     {nS,nC,nR} = max {shanks, cols, rows} on this probe;
%     mat = Mx4 matrix of shank map entries, where,
%     M   = channel count.
%     4   = given channel's zero-based {shank, col, row} indices,
%         plus a 'used' flag which is 1 if the channel should be
%         included in displays and spatial averaging operations.
%     Data are int16 type.
%
% [SN,type] = GetStreamSN( myobj, js, ip )
%
%     js = 1: Return OneBox SN and slot.
%     js = 2: Return probe  SN and type.
%     SN = serial number string.
%
% [Vmin,Vmax] = GetStreamVoltageRange( myobj, js, ip )
%
%     Returns voltage range of selected data stream.
%
% time = GetTime( myobj )
%
%     Returns (double) number of seconds since SpikeGLX application
%     was launched.
%
% version = GetVersion( myobj )
%
%     Get SpikeGLX version string.
%
% boolval = IsConsoleHidden( myobj )
%
%     Returns 1 if console window is hidden, false otherwise.
%     The console window may be hidden/shown using ConsoleHide()
%     and ConsoleShow().
%
% boolval = IsInitialized( myobj )
%
%     Return 1 if SpikeGLX has completed its startup
%     initialization and is ready to run.
%
% boolval = IsRunning( myobj )
%
%     Returns 1 if SpikeGLX is currently acquiring data.
%
% boolval = IsSaving( myobj )
%
%     Returns 1 if the software is currently running
%     AND saving data.
%
% boolval = IsUserOrder( myobj, js, ip )
%
%     Returns 1 if graphs currently sorted in user order.
%     This query is sent only to the main Graphs window.
%
% dstSample = MapSample( myobj, dstjs, dstip, srcSample, srcjs, srcip )
%
%     Returns sample in dst stream corresponding to
%     given sample in src stream.
%
% myobj = Opto_emit( myobj, ip, color, site )
%
%     Direct emission to specified site (-1=dark).
%     ip:    imec probe index.
%     color: {0=blue, 1=red}.
%     site:  [0..13], or, -1=dark.
%
% [site_atten_factors] = Opto_getAttenuations( myobj, ip, color )
%
%     Returns vector of 14 (double) site power attenuation factors.
%     ip:    imec probe index.
%     color: {0=blue, 1=red}.
%
% res = Par2( myobj, op, filename )
%
%     Create, Verify, or Repair Par2 redundancy files for
%     'filename'. Arguments:
%
%     op: a string that is either 'c', 'v', or 'r' for create,
%     verify or repair respectively.
%
%     filename: the .par2 or .bin file to which 'op' is applied.
%
%     Progress is reported to the command window.
%
% myobj = SetAnatomy_Pinpoint( myobj, 'shankdat' )
%
%     Set anatomy data string with Pinpoint format:
%     [probe-id,shank-id](startpos,endpos,R,G,B,rgnname)(startpos,endpos,R,G,B,rgnname)…()
%        - probe-id: SpikeGLX logical probe id.
%        - shank-id: [0..n-shanks].
%        - startpos: region start in microns from tip.
%        - endpos:   region end in microns from tip.
%        - R,G,B:    region color as RGB, each [0..255].
%        - rgnname:  region name text.
%
% myobj = SetAudioEnable( myobj, bool_flag )
%
%     Set audio output on/off. Note that this command has
%     no effect if not currently running.
%
% myobj = SetAudioParams( myobj, group_string, params_struct )
%
%     Set subgroup of parameters for audio-out operation. Parameters
%     are a struct of name/value pairs. This call stops current output.
%     Call SetAudioEnable( myobj, 1 ) to restart it.
%
% myobj = SetDataDir( myobj, idir, dir )
%
%     Set ith global data directory.
%     Set required parameter idir to zero for main data directory.
%
% myobj = SetDigOut( myobj, bool_flag, channels )
%
%     Set digital output on/off. Channel strings have form:
%     'Dev6/port0/line2,Dev6/port0/line5'.
%
% myobj = SetMetadata( myobj, metadata_struct )
%
%     If a run is in progress, set metadata to be added to the
%     next output file-set. Metadata must be in the form of a
%     struct of name/value pairs.
%
% myobj = SetMultiDriveEnable( myobj, bool_flag )
%
%     Set multi-drive run-splitting on/off.
%
% myobj = SetNextFileName( myobj, 'name' )
%
%     For only the next trigger (file writing event) this overrides
%     all auto-naming, giving you complete control of where to save
%     the files, the file name, and what g- and t-indices you want
%     (if any). For example, regardless of the run's current data dir,
%     run name and indices, if you set: 'otherdir/yyy_g5/yyy_g5_t7',
%     SpikeGLX will save the next files in flat directory yyy_g5/:
%        - otherdir/yyy_g5/yyy.g5_t7.nidq.bin,meta
%        - otherdir/yyy_g5/yyy.g5_t7.imec0.ap.bin,meta
%        - otherdir/yyy_g5/yyy.g5_t7.imec0.lf.bin,meta
%        - otherdir/yyy_g5/yyy.g5_t7.imec1.ap.bin,meta
%        - otherdir/yyy_g5/yyy.g5_t7.imec1.lf.bin,meta
%        - etc.
%
%     - The destination directory must already exist...No parent directories
%     or probe subfolders are created in this naming mode.
%     - The run must already be in progress.
%     - Neither the custom name nor its indices are displayed in the Graphs
%     window toolbars. Rather, the toolbars reflect standard auto-names.
%     - After writing this file set, the override is cleared and auto-naming
%     will resume as if you never called setNextFileName. You have to call
%     setNextFileName before each trigger event to create custom trial series.
%     For example, you can build a software-triggered t-series using sequence:
%        + setNextFileName( 'otherdir/yyy_g0/yyy_g0_t0' )
%        + setRecordingEnable( 1 )
%        + setRecordingEnable( 0 )
%        + setNextFileName( 'otherdir/yyy_g0/yyy_g0_t1' )
%        + setRecordingEnable( 1 )
%        + setRecordingEnable( 0 )
%        + etc.
%
% myobj = SetParams( myobj, params_struct )
%
%     The inverse of GetParams.m, this sets run parameters.
%     Alternatively, you can pass the parameters to StartRun()
%     which calls this in turn. Run parameters are a struct of
%     name/value pairs. The call will error if a run is currently
%     in progress.
%
%     Note: You can set any subset of [DAQSettings].
%
% myobj = SetParamsImecCommon( myobj, params_struct )
%
%     The inverse of GetParamsImecCommon.m, this sets parameters
%     common to all enabled probes. Parameters are a struct of
%     name/value pairs. The call will error if a run is currently
%     in progress.
%
%     Note: You can set any subset of [DAQ_Imec_All].
%
% myobj = SetParamsImecProbe( myobj, params_struct, ip )
%
%     The inverse of GetParamsImecProbe.m, this sets parameters
%     for a given logical probe. Parameters are a struct of
%     name/value pairs. The call will error if file writing
%     is currently in progress.
%
%     Note: You can set any subset of fields under [SerialNumberToProbe]/SNjjj.
%
% myobj = SetParamsOneBox( myobj, params_struct, ip )
%
%     The inverse of GetParamsOneBox.m, this sets parameters
%     for a given logical OneBox. Parameters are a struct of
%     name/value pairs. The call will error if a run is currently
%     in progress.
%
%     Note: You can set any subset of fields under [SerialNumberToOneBox]/SNjjj.
%
% myobj = SetRecordingEnable( myobj, bool_flag )
%
%     Set gate (file writing) on/off during run.
%
%     When auto-naming is in effect, opening the gate advances
%     the g-index and resets the t-index to zero. Auto-naming is
%     on unless SetNextFileName has been used to override it.
%
% myobj = SetRunName( myobj, 'name' )
%
%     Set the run name for the next time files are created
%     (either by trigger, SetRecordingEnable() or by StartRun()).
%
% myobj = SetTriggerOffBeep( myobj, hertz, millisec )
%
%     During a run, set frequency and duration of Windows
%     beep signaling file closure. hertz=0 disables the beep.
%
% myobj = SetTriggerOnBeep( myobj, hertz, millisec )
%
%     During a run set frequency and duration of Windows
%     beep signaling file creation. hertz=0 disables the beep.
%
% myobj = StartRun( myobj )
% myobj = StartRun( myobj, params )
% myobj = StartRun( myobj, runName )
%
%     Start data acquisition run. Optional second argument (params)
%     is a struct of name/value pairs as returned from GetParams.m.
%     Alternatively, the second argument can be a string (runName).
%     Last-used parameters remain in effect if not specified here.
%     An error is flagged if already running or a parameter is bad.
%
% myobj = StopRun( myobj )
%
%     Unconditionally stop current run, close data files
%     and return to idle state.
%
% myobj = TriggerGT( myobj, g, t )
%
%     Using standard auto-naming, set both the gate (g) and
%     trigger (t) levels that control file writing.
%       -1 = no change.
%        0 = set low.
%        1 = increment and set high.
%     E.g., triggerGT( -1, 1 ) = same g, increment t, start writing.
%
%     - TriggerGT only affects the 'Remote controlled' gate type and/or
%     the 'Remote controlled' trigger type.
%     - The 'Enable Recording' button, when shown, is a master override
%     switch. TriggerGT is blocked until you click the button or call
%     SetRecordingEnable.
%
% res = VerifySha1( myobj, filename )
%
%     Verifies the SHA1 sum of the file specified by filename.
%     If filename is relative, it is appended to the run dir.
%     Absolute path/filenames are also supported. Since this is
%     a potentially long operation, it uses the 'disp' command
%     to print progress information to the MATLAB console. The
%     returned value is 1 if verified, 0 otherwise.

