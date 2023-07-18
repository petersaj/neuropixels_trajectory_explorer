% myobj = SetTriggerOnBeep( myobj, hertz, millisec )
%
%     During a run set frequency and duration of Windows
%     beep signaling file creation. hertz=0 disables the beep.
%
function [s] = SetTriggerOnBeep( s, hertz, millisec )

    DoSimpleCmd( s, sprintf( 'SETTRIGGERONBEEP %d %d', hertz, millisec ) );
end
