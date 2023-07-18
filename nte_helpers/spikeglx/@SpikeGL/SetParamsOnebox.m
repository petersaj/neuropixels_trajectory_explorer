% myobj = SetParamsOneBox( myobj, params_struct, ip )
%
%     The inverse of GetParamsOneBox.m, this sets parameters
%     for a given logical OneBox. Parameters are a struct of
%     name/value pairs. The call will error if a run is currently
%     in progress.
%
%     Note: You can set any subset of fields under [SerialNumberToOneBox]/SNjjj.
%
function [s] = SetParamsOneBox( s, params, ip )

    if( ~isstruct( params ) )
        error( 'SetParamsOneBox: Argument must be a struct.' );
    end

    ChkConn( s );

    ok = CalinsNetMex( 'sendstring', s.handle, sprintf( 'SETPARAMSOBX %d\n',ip ) );
    ReceiveREADY( s, 'SETPARAMSOBX' );

    names = fieldnames( params );

    for i = 1:length( names )

        f = params.(names{i});

        if( isnumeric( f ) && isscalar( f ) )
            line = sprintf( '%s=%g\n', names{i}, f );
        elseif( ischar( f ) )
            line = sprintf( '%s=%s\n', names{i}, f );
        else
            error( 'SetParamsOneBox: Field %s must be numeric scalar or a string.', names{i} );
        end

        ok = CalinsNetMex( 'sendstring', s.handle, line );
    end

    % end with blank line
    ok = CalinsNetMex( 'sendstring', s.handle, sprintf( '\n' ) );

    ReceiveOK( s, 'SETPARAMSOBX' );
end
