% sampleCount = GetStreamSampleCount( myobj, js, ip )
%
%     Returns number of samples since current run started,
%     or zero if not running.
%
function [ret] = GetStreamSampleCount( s, js, ip )

    ret = str2double( DoQuery( s, sprintf( 'GETSTREAMSAMPLECOUNT %d %d', js, ip ) ) );
end
