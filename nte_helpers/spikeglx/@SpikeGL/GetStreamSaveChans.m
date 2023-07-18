% channelSubset = GetStreamSaveChans( myobj, js, ip )
%
%     Returns a vector containing the indices of
%     the acquired channels that are being saved.
%
function [ret] = GetStreamSaveChans( s, js, ip )

    ret = str2num( DoQuery( s, sprintf( 'GETSTREAMSAVECHANS %d %d', js, ip ) ) );
end
