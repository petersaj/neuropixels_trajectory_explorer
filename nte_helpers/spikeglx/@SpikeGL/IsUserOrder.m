% boolval = IsUserOrder( myobj, js, ip )
%
%     Returns 1 if graphs currently sorted in user order.
%     This query is sent only to the main Graphs window.
%
function [ret] = IsUserOrder( s, js, ip )

    ret = sscanf( DoQuery( s, sprintf( 'ISUSRORDER %d %d', js, ip ) ), '%d' );
end
