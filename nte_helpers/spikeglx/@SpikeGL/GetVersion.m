% version = GetVersion( myobj )
%
%     Get SpikeGLX version string.
%
function [ret] = GetVersion( s )

    ret = DoQuery( s, 'GETVERSION' );
end
