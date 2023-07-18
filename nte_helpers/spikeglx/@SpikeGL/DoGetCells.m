% THIS FUNCTION IS PRIVATE AND SHOULD NOT BE CALLED BY OUTSIDE CODE!
%
% Fetch one or more lines, excluding {OK, ERROR} lines.
% Return as cell-array of strings.
%
function [res] = DoGetCells( sm, cmd )

    ChkConn( sm );

    ok = CalinsNetMex( 'sendstring', sm.handle, sprintf( '%s\n', cmd ) );

    if( isempty( ok ) )
        error( '[%s] error: Cannot send string.', cmd );
    end

    res = CalinsNetMex( 'getcells', sm.handle );
end
