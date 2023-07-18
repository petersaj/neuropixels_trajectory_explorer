% startingSample = GetStreamFileStart( myobj, js, ip )
%
%     Returns index of first sample in selected file,
%     or zero if unavailable.
%
function [ret] = GetStreamFileStart( s, js, ip )

    ret = str2double( DoQuery( s, sprintf( 'GETSTREAMFILESTART %d %d', js, ip ) ) );
end
