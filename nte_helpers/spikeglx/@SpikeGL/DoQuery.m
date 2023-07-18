% THIS FUNCTION IS PRIVATE AND SHOULD NOT BE CALLED BY OUTSIDE CODE!
%
% Fetch one line, excluding {OK, ERROR} lines.
% Return as single string.
%
% To include OK, m-files should directly call:
% line = CalinsNetMex( 'readline', s.handle );
%
function [res] = DoQuery( sm, cmd )

    ChkConn( sm );

    ok = CalinsNetMex( 'sendstring', sm.handle, sprintf( '%s\n', cmd ) );

    if( isempty( ok ) )
        error( '[%s] error: Cannot send string.', cmd );
    end

    res = CalinsNetMex( 'querystring', sm.handle );
end
