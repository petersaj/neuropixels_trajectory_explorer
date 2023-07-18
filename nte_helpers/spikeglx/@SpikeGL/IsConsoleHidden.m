% boolval = IsConsoleHidden( myobj )
%
%     Returns 1 if console window is hidden, false otherwise.
%     The console window may be hidden/shown using ConsoleHide()
%     and ConsoleShow().
%
function [ret] = IsConsoleHidden( s )

    ret = sscanf( DoQuery( s, 'ISCONSOLEHIDDEN' ), '%d' );
end
