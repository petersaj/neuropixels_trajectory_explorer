% myobj = SetTriggerOffBeep( myobj, hertz, millisec )
%
%     During a run, set frequency and duration of Windows
%     beep signaling file closure. hertz=0 disables the beep.
%
function [s] = SetTriggerOffBeep( s, hertz, millisec )

    DoSimpleCmd( s, sprintf( 'SETTRIGGEROFFBEEP %d %d', hertz, millisec ) );
end
