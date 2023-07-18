% res = Par2( myobj, op, filename )
%
%     Create, Verify, or Repair Par2 redundancy files for
%     'filename'. Arguments:
%
%     op: a string that is either 'c', 'v', or 'r' for create,
%     verify or repair respectively.
%
%     filename: the .par2 or .bin file to which 'op' is applied.
%
%     Progress is reported to the command window.
%
function [res] = Par2( s, op, file )

    res = 0;

    if( ~strcmp( op, 'v' ) && ~strcmp( op, 'r' ) && ~strcmp( op, 'c' ) )
        error( 'Par2: Op must be one of ''v'', ''r'' or ''c''.' );
    end

    ChkConn( s );

    if( IsRunning( s ) )
        error( 'Par2: Cannot use while running.' );
    end

    ok = CalinsNetMex( 'sendstring', s.handle, sprintf( 'PAR2 %s %s\n', op, file ) );

    while( 1 )

        line = CalinsNetMex( 'readline', s.handle );

        if( strcmp( line, 'OK' ) )
            res = 1;
            break;
        end

        if( ~isempty( line ) )
            fprintf( '%s\n', line );
        end
    end
end
