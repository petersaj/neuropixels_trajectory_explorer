% name = GetRunName( myobj )
%
%     Get run base name.
%
function [name] = GetRunName( s )

    name = DoQuery( s, 'GETRUNNAME' );
end
