% myobj = SetParamsImecProbe( myobj, params_struct, ip )
%
%     The inverse of GetParamsImecProbe.m, this sets parameters
%     for a given logical probe. Parameters are a struct of
%     name/value pairs. The call will error if file writing
%     is currently in progress.
%
%     Note: You can set any subset of fields under [SerialNumberToProbe]/SNjjj.
%
function [s] = SetParamsImecProbe( s, params, ip )

    if( ~isstruct( params ) )
        error( 'SetParamsImecProbe: Argument must be a struct.' );
    end

    ChkConn( s );

    ok = CalinsNetMex( 'sendstring', s.handle, sprintf( 'SETPARAMSIMPRB %d\n',ip ) );
    ReceiveREADY( s, 'SETPARAMSIMPRB' );

    names = fieldnames( params );

    for i = 1:length( names )

        f = params.(names{i});

        if( isnumeric( f ) && isscalar( f ) )
            line = sprintf( '%s=%g\n', names{i}, f );
        elseif( ischar( f ) )
            line = sprintf( '%s=%s\n', names{i}, f );
        else
            error( 'SetParamsImecProbe: Field %s must be numeric scalar or a string.', names{i} );
        end

        ok = CalinsNetMex( 'sendstring', s.handle, line );
    end

    % end with blank line
    ok = CalinsNetMex( 'sendstring', s.handle, sprintf( '\n' ) );

    ReceiveOK( s, 'SETPARAMSIMPRB' );
end
