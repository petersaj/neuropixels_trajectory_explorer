% myobj = SetRecordingEnable( myobj, bool_flag )
%
%     Set gate (file writing) on/off during run.
%
%     When auto-naming is in effect, opening the gate advances
%     the g-index and resets the t-index to zero. Auto-naming is
%     on unless SetNextFileName has been used to override it.
%
function [s] = SetRecordingEnable( s, b )

    if( ~isnumeric( b ) )
        error( 'SetRecordingEnable: Arg 2 must be a Boolean value {0,1}.' );
    end

    DoSimpleCmd( s, sprintf( 'SETRECORDENAB %d', b ) );
end
