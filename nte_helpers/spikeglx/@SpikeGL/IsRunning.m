% boolval = IsRunning( myobj )
%
%     Returns 1 if SpikeGLX is currently acquiring data.
%
function [ret] = IsRunning( s )

    ret = sscanf( DoQuery( s, 'ISRUNNING' ), '%d' );
end
