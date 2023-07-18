% myobj = SetParamsImecCommon( myobj, params_struct )
%
%     The inverse of GetParamsImecCommon.m, this sets parameters
%     common to all enabled probes. Parameters are a struct of
%     name/value pairs. The call will error if a run is currently
%     in progress.
%
%     Note: You can set any subset of [DAQ_Imec_All].
%
function [s] = SetParamsImecCommon( s, params )

    if( ~isstruct( params ) )
        error( 'SetParamsImecCommon: Argument must be a struct.' );
    end

    ChkConn( s );

    ok = CalinsNetMex( 'sendstring', s.handle, sprintf( 'SETPARAMSIMALL\n' ) );
    ReceiveREADY( s, 'SETPARAMSIMALL' );

    names = fieldnames( params );

    for i = 1:length( names )

        f = params.(names{i});

        if( isnumeric( f ) && isscalar( f ) )
            line = sprintf( '%s=%g\n', names{i}, f );
        elseif( ischar( f ) )
            line = sprintf( '%s=%s\n', names{i}, f );
        else
            error( 'SetParamsImecCommon: Field %s must be numeric scalar or a string.', names{i} );
        end

        ok = CalinsNetMex( 'sendstring', s.handle, line );
    end

    % end with blank line
    ok = CalinsNetMex( 'sendstring', s.handle, sprintf( '\n' ) );

    ReceiveOK( s, 'SETPARAMSIMALL' );
end
