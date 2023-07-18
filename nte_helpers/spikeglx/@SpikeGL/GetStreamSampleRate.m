% sampleRate = GetStreamSampleRate( myobj, js, ip )
%
%     Returns sample rate of selected stream in Hz.
%
function [ret] = GetStreamSampleRate( s, js, ip )

    ret = str2double( DoQuery( s, sprintf( 'GETSTREAMSAMPLERATE %d %d', js, ip ) ) );
end
