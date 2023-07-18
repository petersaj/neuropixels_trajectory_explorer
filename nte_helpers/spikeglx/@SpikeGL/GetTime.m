% time = GetTime( myobj )
%
%     Returns (double) number of seconds since SpikeGLX application
%     was launched.
%
function [ret] = GetTime( s )

    ret = sscanf( DoQuery( s, 'GETTIME' ), '%f' );
end
