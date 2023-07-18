% myobj = SetParams( myobj, params_struct )
%
%     The inverse of GetParams.m, this sets run parameters.
%     Alternatively, you can pass the parameters to StartRun()
%     which calls this in turn. Run parameters are a struct of
%     name/value pairs. The call will error if a run is currently
%     in progress.
%
%     Note: You can set any subset of [DAQSettings].
%
function [s] = SetParams( s, params )

    if( ~isstruct( params ) )
        error( 'SetParams: Argument must be a struct.' );
    end

    ChkConn( s );

    ok = CalinsNetMex( 'sendstring', s.handle, sprintf( 'SETPARAMS\n' ) );
    ReceiveREADY( s, 'SETPARAMS' );

    names = fieldnames( params );

    for i = 1:length( names )

        f = params.(names{i});

        if( isnumeric( f ) && isscalar( f ) )
            line = sprintf( '%s=%g\n', names{i}, f );
        elseif( ischar( f ) )
            line = sprintf( '%s=%s\n', names{i}, f );
        else
            error( 'SetParams: Field %s must be numeric scalar or a string.', names{i} );
        end

        ok = CalinsNetMex( 'sendstring', s.handle, line );
    end

    % end with blank line
    ok = CalinsNetMex( 'sendstring', s.handle, sprintf( '\n' ) );

    ReceiveOK( s, 'SETPARAMS' );
end
