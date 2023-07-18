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
function [s] = SetNextFileName( s, name )

    if( ~ischar( name ) )
        error( 'SetNextFileName: Argument must be a string.' );
    end

    DoSimpleCmd( s, sprintf( 'SETNEXTFILENAME %s', name ) );
end
