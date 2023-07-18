% myobj = SetRunName( myobj, 'name' )
%
%     Set the run name for the next time files are created
%     (either by trigger, SetRecordingEnable() or by StartRun()).
%
function [s] = SetRunName( s, name )

    if( ~ischar( name ) )
        error( 'SetRunName: Argument must be a string.' );
    end

    DoSimpleCmd( s, sprintf( 'SETRUNNAME %s', name ) );
end
