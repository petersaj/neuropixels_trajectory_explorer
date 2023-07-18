% boolval = IsSaving( myobj )
%
%     Returns 1 if the software is currently running
%     AND saving data.
%
function [ret] = IsSaving( s )

    ret = sscanf( DoQuery( s, 'ISSAVING' ), '%d' );
end
