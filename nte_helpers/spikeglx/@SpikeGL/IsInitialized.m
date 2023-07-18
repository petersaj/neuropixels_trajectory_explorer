% boolval = IsInitialized( myobj )
%
%     Return 1 if SpikeGLX has completed its startup
%     initialization and is ready to run.
%
function ret = IsInitialized( s )

    ret = sscanf( DoQuery( s, 'ISINITIALIZED' ), '%d' );
end
