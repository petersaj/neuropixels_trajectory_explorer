% myobj = SetDataDir( myobj, idir, dir )
%
%     Set ith global data directory.
%     Set required parameter idir to zero for main data directory.
%
function [s] = SetDataDir( s, idir, dir )

    if( ~ischar( dir ) )
        error( 'SetDataDir: ''dir'' argument must be a string.' );
    end

    DoSimpleCmd( s, sprintf( 'SETDATADIR %d %s', idir, dir ) );
end
